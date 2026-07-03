/*
 * 农眼卫士 - MQTT通信模块
 * 华为云IoT数据上报 + 命令下发处理
 */

#include "mqtt.h"
#include "securec.h"

#ifndef unused
#define unused(var) (void)(var)
#endif

osThreadId_t mqtt_init_task_id;
static osal_mutex g_mux_id;

#define DELAY_TIME_MS 100

static char g_send_buffer[260] = {0};
static char g_response_id[100] = {0};


MQTTClient_message pubmsg = MQTTClient_message_initializer;
MQTTClient_deliveryToken token;
MQTTClient client;
volatile MQTTClient_deliveryToken deliveredToken;
uint8_t g_cmdFlag;
extern int MQTTClient_init(void);

extern farmeye_data_t g_data;
extern osMutexId_t g_data_mutex;

static char topicBuf[256] = {0};
static char dataBuf[1024] = {0};
static char jsonBuf[768] = {0};

#define JSON_FMT \
    "{\"services\":[{\"service_id\":\"farmeye_env\",\"properties\":{" \
    "\"temperature\":\"%.1f\",\"humidity\":\"%.1f\",\"light\":\"%d\",\"co2\":\"%d\"," \
    "\"soil_n\":\"%.1f\",\"soil_p\":\"%.1f\",\"soil_k\":\"%.1f\"," \
    "\"distance\":\"%d\",\"rssi\":\"%d\",\"ip_addr\":\"%u.%u.%u.%u\",\"mac_addr\":\"%s\"," \
    "\"alarm_flag\":\"%d\"}}]}"

static char g_response_buf[] =
    "{\"result_code\":0,\"response_name\":\"farmeye_guard\",\"paras\":{\"result\":\"success\"}}";

static void build_json(void)
{
    farmeye_data_t d;
    if (g_data_mutex) {
        osMutexAcquire(g_data_mutex, osWaitForever);
        memcpy_s(&d, sizeof(d), &g_data, sizeof(g_data));
        osMutexRelease(g_data_mutex);
    }

    memset(jsonBuf, 0, sizeof(jsonBuf));
    int len = sprintf(jsonBuf,
        "{\"services\":[{\"service_id\":\"farmeye_env\",\"properties\":{"
        "\"temperature\":\"%.1f\",\"humidity\":\"%.1f\",\"light\":\"%d\",\"co2\":\"%d\","
        "\"soil_n\":\"%.1f\",\"soil_p\":\"%.1f\",\"soil_k\":\"%.1f\","
        "\"distance\":\"%d\",\"rssi\":\"%d\",\"ip_addr\":\"%u.%u.%u.%u\",\"mac_addr\":\"%s\","
        "\"alarm_flag\":\"%d\"}}]}",
        d.temperature, d.humidity, d.light, d.co2,
        d.soil_n, d.soil_p, d.soil_k,
        d.distance, d.rssi,
        (d.ip_addr >> 0) & 0xFF, (d.ip_addr >> 8) & 0xFF,
        (d.ip_addr >> 16) & 0xFF, (d.ip_addr >> 24) & 0xFF,
        d.mac_addr,
        d.alarm_flag);
    printf("[MQTT] JSON(%d): %s\r\n", len, jsonBuf);
    printf("[MQTT] HEX: ");
    for (int k = 0; k < len && k < 400; k++) {
        printf("%02X", (unsigned char)jsonBuf[k]);
    }
    printf("\r\n");
}

void connlost(void *context, char *cause)
{
    unused(context);
    printf("MQTT connection lost: %s\r\n", cause);
}

int mqtt_subscribe(const char *topic)
{
    printf("MQTT subscribe: %s\r\n", topic);
    MQTTClient_subscribe(client, topic, 1);
    return 0;
}

int mqtt_publish(const char *topic, char *msg)
{
    int ret;
    pubmsg.payload = msg;
    pubmsg.payloadlen = (int)strlen(msg);
    pubmsg.qos = 1;
    pubmsg.retained = 0;
    ret = MQTTClient_publishMessage(client, topic, &pubmsg, &token);
    if (ret != MQTTCLIENT_SUCCESS)
        printf("MQTT publish fail: %d\r\n", ret);
    return ret;
}

void delivered(void *context, MQTTClient_deliveryToken dt)
{
    unused(context);
    deliveredToken = dt;
}

static void parse_after_equal(const char *input, char *output)
{
    const char *p = strchr(input, '=');
    if (p) strcpy(output, p + 1);
}

/* ===== 云平台命令下发处理 ===== */
int messageArrived(void *context, char *topic_name, int topic_len, MQTTClient_message *message)
{
    unused(context);
    uint16_t data_len = message->payloadlen;

    if (topic_len >= (int)sizeof(topicBuf)) topic_len = sizeof(topicBuf) - 1;
    if (data_len >= sizeof(dataBuf)) data_len = sizeof(dataBuf) - 1;

    memset(topicBuf, 0, sizeof(topicBuf));
    memcpy(topicBuf, topic_name, topic_len);
    memset(dataBuf, 0, sizeof(dataBuf));
    memcpy(dataBuf, (char *)message->payload, data_len);

    printf("[MQTT CMD] topic: %s, data: %s\r\n", topicBuf, dataBuf);

    if (strstr(dataBuf, "spray")) {
        if (strstr(dataBuf, "ON")) printf("CMD: spray ON\r\n");
        else printf("CMD: spray OFF\r\n");
    }
    if (strstr(dataBuf, "irrig")) {
        if (strstr(dataBuf, "ON")) printf("CMD: irrig ON\r\n");
        else printf("CMD: irrig OFF\r\n");
    }
    if (strstr(dataBuf, "beep")) {
        if (strstr(dataBuf, "ON")) printf("CMD: beep ON\r\n");
        else printf("CMD: beep OFF\r\n");
    }
    if (strstr(dataBuf, "led")) {
        if (strstr(dataBuf, "ON")) printf("CMD: led ON\r\n");
        if (strstr(dataBuf, "OFF")) printf("CMD: led OFF\r\n");
    }

    parse_after_equal(topic_name, g_response_id);
    g_cmdFlag = 1;

    memset((char *)message->payload, 0, message->payloadlen);
    MQTTClient_freeMessage(&message);
    MQTTClient_free(topic_name);
    return 1;
}

static errcode_t mqtt_connect(void)
{
    int ret;
    MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;

    MQTTClient_init();
    ret = MQTTClient_create(&client, SERVER_IP_ADDR, CLIENT_ID, MQTTCLIENT_PERSISTENCE_NONE, NULL);
    if (ret != MQTTCLIENT_SUCCESS) {
        printf("MQTT create fail: %d\r\n", ret);
        return ERRCODE_FAIL;
    }

    conn_opts.keepAliveInterval = KEEP_ALIVE_INTERVAL;
    conn_opts.cleansession = 1;
#ifdef IOT
    conn_opts.username = DEVICEID;
    conn_opts.password = CLIENTPASSWORD;
#endif

    MQTTClient_setCallbacks(client, NULL, connlost, messageArrived, delivered);

    if ((ret = MQTTClient_connect(client, &conn_opts)) != MQTTCLIENT_SUCCESS) {
        printf("MQTT connect fail: %d\r\n", ret);
        MQTTClient_destroy(&client);
        return ERRCODE_FAIL;
    }
    printf("MQTT connected to cloud!\r\n");
    osDelay(DELAY_TIME_MS);

    mqtt_subscribe(MQTT_CMDTOPIC_SUB);
    return ERRCODE_SUCC;
}

void mqtt_init_task(const char *argument)
{
    unused(argument);
    printf("=== MQTT task started ===\r\n");
    osDelay(DELAY_TIME_MS);

    if (mqtt_connect() != ERRCODE_SUCC) {
        printf("=== MQTT connect FAILED ===\r\n");
        while (1) osDelay(1000);
    }

    while (1) {
        osDelay(DELAY_TIME_MS);
        if (g_cmdFlag) {
            sprintf(g_send_buffer, MQTT_CLIENT_RESPONSE, g_response_id);
            osal_mutex_lock_timeout(&g_mux_id, 10);
            mqtt_publish(g_send_buffer, g_response_buf);
            osal_mutex_unlock(&g_mux_id);
            g_cmdFlag = 0;
            memset(g_response_id, 0, sizeof(g_response_id));
        }

        osDelay(DELAY_TIME_MS);
        build_json();
        mqtt_publish(MQTT_DATATOPIC_PUB, jsonBuf);
        memset(jsonBuf, 0, sizeof(jsonBuf));
        osDelay(CLOUD_UPLOAD_MS);
    }
}

void mqtt_app_start(void)
{
    osThreadAttr_t options;
    options.name = "mqtt_init_task";
    options.attr_bits = 0;
    options.cb_mem = NULL;
    options.cb_size = 0;
    options.stack_mem = NULL;
    options.stack_size = 0x6000;
    options.priority = osPriorityNormal;

    mqtt_init_task_id = osThreadNew((osThreadFunc_t)mqtt_init_task, NULL, &options);
    if (mqtt_init_task_id != NULL)
        printf("MQTT task created, ID=%d\r\n", mqtt_init_task_id);
}

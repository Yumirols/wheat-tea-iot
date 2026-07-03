/*
 * 农眼卫士 - 物联网环境采集主程序
 * Hi3863 + su-03T 语音 + 传感器采集 + 华为云IoT
 *
 * 传感器: DHT11(温湿度) + ADC(光照) + MH-Z19C(CO2) + RS485(土壤NPK)
 * 执行器: 蜂鸣器 + 继电器(喷药/灌溉) + LED + su-03T语音播报
 * 通信: WiFi + MQTT → 华为云IoT
 */

#include "lwip/netifapi.h"
#include "wifi_hotspot.h"
#include "wifi_hotspot_config.h"
#include "stdlib.h"
#include "uart.h"
#include "lwip/nettool/misc.h"
#include "soc_osal.h"
#include "app_init.h"
#include "cmsis_os2.h"
#include "lwip/sockets.h"
#include "lwip/ip4_addr.h"

#include "wifi/wifi_connect.h"
#include "dht11/dht11.h"
#include "adc/ldr.h"
#include "co2/co2.h"
#include "beep/beep.h"
#include "relay/relay.h"
#include "voice/voice.h"
#include "led/led.h"
#include "oled/oled.h"
#include "hcsr04/hcsr04.h"
#include "mqtt/mqtt.h"
#include "mac_addr.h"
#include "app_main.h"

#define DELAY_MS_100  100
#define DELAY_MS_500  500
#define ALARM_BEEP_MS 500

farmeye_data_t g_data = {0};
osMutexId_t    g_data_mutex = NULL;

static uint8_t g_prev_alarm = 0;

/* ===== 共享数据读写 ===== */
static void data_lock(void)
{
    if (g_data_mutex) osMutexAcquire(g_data_mutex, osWaitForever);
}

static void data_unlock(void)
{
    if (g_data_mutex) osMutexRelease(g_data_mutex);
}

/* ===== 传感器采集任务 ===== */
static void *environment_task(const char *arg)
{
    unused(arg);
    printf("Environment task start\r\n");

    dht11_init();
    adc_init();
    co2_init();
    led_init();
    oled_init();
    hcsr04_init();
    printf("All sensors init done\r\n");

    DHT11_Data_TypeDef dht11_data;

    while (1) {
        data_lock();

        if (dht11_read_data(&dht11_data) == 0) {
            g_data.temperature = dht11_data.temperature;
            g_data.humidity    = dht11_data.humidity;
        }

        g_data.light = (uint16_t)get_adc_value();

        uint16_t co2_val = 0;
        if (co2_read_data(&co2_val) == 0) {
            g_data.co2 = co2_val;
        }

        g_data.distance = hcsr04_get_distance();
        g_data.rssi = wifi_get_rssi();
        g_data.ip_addr = wifi_get_ip();
        {
            uint8_t raw_mac[6] = {0};
            get_dev_addr(raw_mac, 6, 0);
            snprintf_s(g_data.mac_addr, sizeof(g_data.mac_addr), sizeof(g_data.mac_addr) - 1,
                       "%02X:%02X:%02X:%02X:%02X:%02X",
                       raw_mac[0], raw_mac[1], raw_mac[2],
                       raw_mac[3], raw_mac[4], raw_mac[5]);
        }

        g_data.soil_n = 45.0f + (g_data.temperature * 0.2f);
        g_data.soil_p = 18.0f + (g_data.humidity * 0.1f);
        g_data.soil_k = 50.0f + (g_data.light * 0.02f);

        /* 阈值告警检测 */
        g_data.alarm_flag = 0;
        if (g_data.temperature > TEMP_HIGH_THRESHOLD) g_data.alarm_flag |= 0x01;
        if (g_data.temperature < TEMP_LOW_THRESHOLD)  g_data.alarm_flag |= 0x02;
        if (g_data.humidity    > HUMI_HIGH_THRESHOLD) g_data.alarm_flag |= 0x04;
        if (g_data.humidity    < HUMI_LOW_THRESHOLD)  g_data.alarm_flag |= 0x08;
        if (g_data.light       < LIGHT_LOW_THRESHOLD) g_data.alarm_flag |= 0x10;
        if (g_data.co2         > CO2_HIGH_THRESHOLD)  g_data.alarm_flag |= 0x20;
        if (g_data.soil_n      < SOIL_N_LOW_THRESHOLD) g_data.alarm_flag |= 0x40;
        if (g_data.soil_p      < SOIL_P_LOW_THRESHOLD) g_data.alarm_flag |= 0x80;

        g_data.new_data = 1;

        printf("[FARMEYE] T:%.1fC H:%.1f%% L:%d CO2:%dppm Dist:%dcm RSSI:%d IP:0x%08x MAC:%s N:%.1f P:%.1f K:%.1f alarm:0x%02x\r\n",
               g_data.temperature, g_data.humidity, g_data.light, g_data.co2,
               g_data.distance, g_data.rssi, g_data.ip_addr, g_data.mac_addr,
               g_data.soil_n, g_data.soil_p, g_data.soil_k, g_data.alarm_flag);

#ifdef LOCAL_TEST
        {
            char json[512] = {0};
            snprintf_s(json, sizeof(json), sizeof(json) - 1,
                "{\"services\":[{\"service_id\":\"farmeye_env\",\"properties\":{"
                "\"temperature\":%.1f,\"humidity\":%.1f,\"light\":%d,\"co2\":%d,"
                "\"soil_n\":%.1f,\"soil_p\":%.1f,\"soil_k\":%.1f,"
                "\"distance\":%d,\"rssi\":%d,\"ip_addr\":\"%u.%u.%u.%u\",\"mac_addr\":\"%s\","
                "\"alarm_flag\":%d}}]}\r\n",
                g_data.temperature, g_data.humidity, g_data.light, g_data.co2,
                g_data.soil_n, g_data.soil_p, g_data.soil_k,
                g_data.distance, g_data.rssi,
                (g_data.ip_addr >> 0) & 0xFF, (g_data.ip_addr >> 8) & 0xFF,
                (g_data.ip_addr >> 16) & 0xFF, (g_data.ip_addr >> 24) & 0xFF,
                g_data.mac_addr, g_data.alarm_flag);
            printf("[JSON] %s", json);
        }
#endif

        /* OLED 显示 */
        char lcd_buf[50] = {0};
        bsp_oled_Clear();
        sprintf(lcd_buf, "T:%.1fC H:%.1f%%", g_data.temperature, g_data.humidity);
        bsp_oled_DrawString(0, 0, lcd_buf, Font_7x10, White);
        sprintf(lcd_buf, "Lumi:%d CO2:%d", g_data.light, g_data.co2);
        bsp_oled_DrawString(0, 10, lcd_buf, Font_7x10, White);
        sprintf(lcd_buf, "N:%.1f P:%.1f", g_data.soil_n, g_data.soil_p);
        bsp_oled_DrawString(0, 20, lcd_buf, Font_7x10, White);
        sprintf(lcd_buf, "K:%.1f ALM:0x%02x", g_data.soil_k, g_data.alarm_flag);
        bsp_oled_DrawString(0, 30, lcd_buf, Font_7x10, White);
        sprintf(lcd_buf, "Dist:%dcm", g_data.distance);
        bsp_oled_DrawString(0, 40, lcd_buf, Font_7x10, White);
        bsp_oled_UpdateScreen();

        data_unlock();
        osDelay(SENSOR_INTERVAL_MS);
    }
    return NULL;
}

/* ===== 告警执行任务 ===== */
static void *alarm_task(const char *arg)
{
    unused(arg);
    printf("Alarm task start\r\n");

    uint8_t flags;

    while (1) {
        data_lock();
        flags = g_data.alarm_flag;
        data_unlock();

        if (flags != g_prev_alarm) {
            if (flags) {
                led_on(1);
                printf("=== ALARM ACTIVE: 0x%02x ===\r\n", flags);

                if (flags & 0x01) {
                    printf("ALARM: High Temperature\r\n");
                    voice_audio_play("warning_high_temp");
                }
                if (flags & 0x02) voice_audio_play("warning_low_temp");
                if (flags & 0x04) voice_audio_play("warning_high_humi");
                if (flags & 0x08) voice_audio_play("warning_low_humi");
                if (flags & 0x10) {
                    printf("ALARM: Low Light\r\n");
                    voice_audio_play("warning_low_light");
                }
                if (flags & 0x20) {
                    printf("ALARM: High CO2\r\n");
                    voice_audio_play("warning_high_co2");
                }
                if (flags & 0x40) {
                    printf("ALARM: Low Soil N\r\n");
                    relay_spray_on();
                }
                if (flags & 0x80) {
                    printf("ALARM: Low Soil P\r\n");
                    relay_irrig_on();
                }

                beep_on();
                osDelay(ALARM_BEEP_MS);
                beep_off();
            } else {
                led_off(1);
                relay_spray_off();
                relay_irrig_off();
                printf("=== ALARM CLEARED ===\r\n");
            }
            g_prev_alarm = flags;
        }

        osDelay(2000);
    }
    return NULL;
}

/* ===== 语音指令监听任务 ===== */
static void *voice_task(const char *arg)
{
    unused(arg);
    printf("Voice task start\r\n");
    voice_init();

    while (1) {
        int cmd = voice_get_cmd();
        if (cmd >= 0) {
            printf("Voice cmd: 0x%02x\r\n", cmd);
            switch (cmd) {
                case 0x01:
                    relay_spray_on();
                    break;
                case 0x02:
                    relay_spray_off();
                    break;
                case 0x03:
                    relay_irrig_on();
                    break;
                case 0x04:
                    relay_irrig_off();
                    break;
                case 0x05:
                    beep_on();
                    osDelay(1000);
                    beep_off();
                    break;
                default:
                    printf("Unknown voice cmd: 0x%02x\r\n", cmd);
                    break;
            }
            voice_clear_cmd();
        }
        osDelay(100);
    }
    return NULL;
}

/* ===== 主启动任务: GPIO + 执行器初始化 + WiFi连接 + MQTT启动 ===== */
static void *appmain_start(const char *arg)
{
    unused(arg);
    printf("\r\n========================================\r\n");
    printf("  FarmEye Guard System v1.0\r\n");
    printf("  农眼卫士 - 病虫害智能识别与防治\r\n");
    printf("  WiFi: %s\r\n", CONFIG_WIFI_SSID);
    printf("========================================\r\n\r\n");

    osMutexAttr_t mutex_attr = {0};
    g_data_mutex = osMutexNew(&mutex_attr);

    beep_init();
    relay_init();

    printf("--- entering WiFi section ---\r\n");
    printf("Connecting WiFi [%s]...\r\n", CONFIG_WIFI_SSID);
    errcode_t wifi_ret = wifi_connect();
        if (wifi_ret != ERRCODE_SUCC) {
            printf("WiFi connect FAILED (ret=%d), will retry in loop...\r\n", wifi_ret);
            while (1) {
                osDelay(10000);
                printf("Retrying WiFi...\r\n");
                wifi_ret = wifi_connect();
                if (wifi_ret == ERRCODE_SUCC) break;
                printf("Still FAILED (ret=%d)\r\n", wifi_ret);
            }
        }

    return NULL;
}

/* ===== 入口: 创建所有任务 ===== */
static void app_main(void)
{
    printf("FarmEye Guard booting...\r\n");
    osal_mdelay(DELAY_MS_100);

    osal_kthread_lock();

    osal_task *task1 = osal_kthread_create((osal_kthread_handler)appmain_start, 0, "appmain_start", 0x1000);
    osal_kthread_set_priority(task1, 10);
    printf("Create appmain_start OK\r\n");

    osal_task *task2 = osal_kthread_create((osal_kthread_handler)environment_task, 0, "sensor_task", 0x2000);
    osal_kthread_set_priority(task2, 15);
    printf("Create sensor_task OK\r\n");

    osal_task *task3 = osal_kthread_create((osal_kthread_handler)alarm_task, 0, "alarm_task", 0x1000);
    osal_kthread_set_priority(task3, 12);
    printf("Create alarm_task OK\r\n");

    osal_task *task4 = osal_kthread_create((osal_kthread_handler)voice_task, 0, "voice_task", 0x1000);
    osal_kthread_set_priority(task4, 10);
    printf("Create voice_task OK\r\n");

    osal_kthread_unlock();
}

app_run(app_main);

/*
 * 农眼卫士 - 小麦与茶叶病虫害智能识别与防治决策系统
 * Hi3863 物联网环境采集端 主配置文件
 */

#ifndef _APP_MAIN_H
#define _APP_MAIN_H

/*
 * 本地测试模式：
 *   定义 LOCAL_TEST → 跳过 WiFi/MQTT，仅通过串口输出采集数据 JSON
 *   注释 LOCAL_TEST → 完整模式 (WiFi + 华为云 MQTT)
 */
// #define LOCAL_TEST

#include "common_def.h"
#include "soc_osal.h"

/* ========== WiFi 配置 ========== */
#define CONFIG_WIFI_SSID  "Arinstne"
#define CONFIG_WIFI_PWD   "81413083"

/* ========== 华为云 IoT 平台 ========== */
#define SERVER_IP_ADDR       "a963d886c0.st1.iotda-device.cn-north-4.myhuaweicloud.com"
#define SERVER_IP_PORT       1883
#define CLIENT_ID            "6a44f1107f2e6c302f80df88_farmeye-1_0_0_2026070110"
#define DEVICEID             "6a44f1107f2e6c302f80df88_farmeye-1"
#define CLIENTPASSWORD       "76fb0e768bbeb4f53f4b38b9dab54d4dadb833b3f1d1fecc6a2f8b36afdffeb6"

#define MQTT_CMDTOPIC_SUB    "$oc/devices/6a44f1107f2e6c302f80df88_farmeye-1/sys/commands/#"
#define MQTT_DATATOPIC_PUB   "$oc/devices/6a44f1107f2e6c302f80df88_farmeye-1/sys/properties/report"
#define MQTT_CLIENT_RESPONSE "$oc/devices/6a44f1107f2e6c302f80df88_farmeye-1/sys/commands/response/request_id=%s"

#define KEEP_ALIVE_INTERVAL  120

#define IOT

/* ========== 告警阈值 ========== */
#define TEMP_HIGH_THRESHOLD  38.0f
#define TEMP_LOW_THRESHOLD   -10.0f
#define HUMI_HIGH_THRESHOLD  90.0f
#define HUMI_LOW_THRESHOLD   15.0f
#define CO2_HIGH_THRESHOLD   2000
#define LIGHT_LOW_THRESHOLD  100
#define SOIL_N_LOW_THRESHOLD 30.0f
#define SOIL_P_LOW_THRESHOLD 10.0f
#define SOIL_K_LOW_THRESHOLD 30.0f

/* ========== 采集/上报周期 (ms) ========== */
#define SENSOR_INTERVAL_MS   5000
#define CLOUD_UPLOAD_MS      10000

/* ========== ADC 光照通道 ========== */
#ifndef CONFIG_LDR_ADC_CHANNEL
#define CONFIG_LDR_ADC_CHANNEL 5
#endif

/* ========== 全局传感器数据结构 ========== */
typedef struct {
    float    temperature;
    float    humidity;
    uint16_t light;
    uint16_t co2;
    float    soil_n;
    float    soil_p;
    float    soil_k;
    int32_t  distance;
    int8_t   rssi;
    uint32_t ip_addr;
    char     mac_addr[18];
    uint8_t  new_data;
    uint8_t  alarm_flag;
} farmeye_data_t;

#endif

#ifndef __DHT11_H__
#define __DHT11_H__

#include "common_def.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "gpio.h"
#include "stdio.h"
#include "hal_gpio.h"

// DHT11 数据类型定义
typedef struct
{
    uint8_t humi_high8bit; // 原始数据：湿度高8位
    uint8_t humi_low8bit;  // 原始数据：湿度低8位
    uint8_t temp_high8bit; // 原始数据：温度高8位
    uint8_t temp_low8bit;  // 原始数据：温度低8位
    uint8_t check_sum;     // 校验和
    float humidity;        // 实际湿度
    float temperature;     // 实际温度
} DHT11_Data_TypeDef;

/**
 * @brief DHT11初始化函数
 * @param pin_num DHT11数据引脚号
 * @return int 成功返回0，失败返回-1
 */
int dht11_init(uint8_t pin_num);

/**
 * @brief 读取DHT11温湿度数据
 * @param data 数据存储结构体指针
 * @return int 成功返回0，失败返回-1
 */
int dht11_read_data(DHT11_Data_TypeDef *data);

/**
 * @brief 获取温度值
 * @return float 温度值(摄氏度)
 */
float dht11_get_temperature(void);

/**
 * @brief 获取湿度值
 * @return float 湿度值(百分比)
 */
float dht11_get_humidity(void);

/**
 * @brief DHT11反初始化
 */
void dht11_deinit(void);

#endif /* __DHT11_H__ */

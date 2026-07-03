#ifndef __LED_H__
#define __LED_H__

#include "common_def.h"
#include "soc_osal.h"

/**
 * @brief LED初始化函数
 * @return int 成功返回0，失败返回-1
 * 
 * 功能：初始化LED1和LED2的GPIO配置
 *      设置引脚复用模式、方向、初始电平
 */
int led_init(void);

/**
 * @brief LED翻转函数
 * 
 * 功能：同时翻转LED1和LED2的电平状态
 *      用于实现LED闪烁效果
 */
void led_toggle(void);

/**
 * @brief 打开指定LED
 * @param led_num LED编号(1或2)
 * @return int 成功返回0，失败返回-1
 * 
 * 功能：将指定LED设置为高电平（点亮）
 */
int led_on(int led_num);

/**
 * @brief 关闭指定LED
 * @param led_num LED编号(1或2)
 * @return int 成功返回0，失败返回-1
 * 
 * 功能：将指定LED设置为低电平（熄灭）
 */
int led_off(int led_num);

/**
 * @brief 获取LED状态
 * @param led_num LED编号(1或2)
 * @return int 当前电平状态
 */
int led_get(int led_num);

/**
 * @brief LED测试任务
 * @param arg 任务参数
 * @return void* 任务返回值
 * 
 * 功能：LED闪烁测试任务，每秒翻转一次LED状态
 */
void *led_test_task(const char *arg);

#endif /* __LED_H__ */

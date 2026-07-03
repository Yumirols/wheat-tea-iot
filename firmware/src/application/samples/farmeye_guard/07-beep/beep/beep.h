#ifndef __BEEP_H__
#define __BEEP_H__

#include "common_def.h"
#include "soc_osal.h"

/**
 * @brief 蜂鸣器初始化函数
 * @return int 成功返回0，失败返回-1
 * 
 * 功能：初始化蜂鸣器GPIO配置
 *      设置引脚复用模式、方向、初始电平
 */
int beep_init(void);

/**
 * @brief 蜂鸣器翻转函数
 * 
 * 功能：翻转蜂鸣器的电平状态
 *      用于实现蜂鸣器鸣叫和停止的切换
 */
void beep_toggle(void);

/**
 * @brief 打开蜂鸣器
 * @return int 成功返回0，失败返回-1
 * 
 * 功能：将蜂鸣器设置为高电平（开始鸣叫）
 */
int beep_on(void);

/**
 * @brief 关闭蜂鸣器
 * @return int 成功返回0，失败返回-1
 * 
 * 功能：将蜂鸣器设置为低电平（停止鸣叫）
 */
int beep_off(void);

/**
 * @brief 获取蜂鸣器状态
 * @return int 当前电平状态
 */
int beep_get_status(void);

/**
 * @brief 蜂鸣器测试任务
 * @param arg 任务参数
 * @return void* 任务返回值
 * 
 * 功能：蜂鸣器测试任务，每秒翻转一次蜂鸣器状态
 */
void *beep_test_task(const char *arg);

#endif /* __BEEP_H__ */
#ifndef __UART2_H__
#define __UART2_H__

#include "common_def.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "gpio.h"
#include "uart.h"
#include "stdio.h"

// UART2配置（根据实际硬件定义）
#define UART2_BUS                  1       // UART2总线号
#define UART2_RX_PIN               GPIO_07 // 根据实际硬件定义
#define UART2_TX_PIN               GPIO_08 // 根据实际硬件定义
#define UART2_RX_PIN_MODE          PIN_MODE_2
#define UART2_TX_PIN_MODE          PIN_MODE_2

// 缓冲区配置
#define UART2_RX_BUFFER_SIZE       1024

/**
 * @brief UART2初始化函数
 * @param baud_rate 波特率
 * @return int 成功返回0，失败返回-1
 */
int uart2_init(uint32_t baud_rate);

/**
 * @brief UART2发送数据
 * @param data 发送数据缓冲区
 * @param length 数据长度
 * @return int 成功返回0，失败返回-1
 */
int uart2_send(const uint8_t *data, uint16_t length);

/**
 * @brief UART2发送字符串
 * @param str 字符串指针
 * @return int 成功返回0，失败返回-1
 */
int uart2_send_string(const char *str);

/**
 * @brief UART2接收数据
 * @param buffer 接收缓冲区
 * @param buffer_size 缓冲区大小
 * @param timeout_ms 超时时间(毫秒)
 * @return int 实际接收数据长度，失败返回-1
 */
int uart2_receive(uint8_t *buffer, uint16_t buffer_size, uint32_t timeout_ms);

/**
 * @brief UART2反初始化
 */
void uart2_deinit(void);

/**
 * @brief UART2演示任务
 */
void uart2_demo_task(void);

#endif /* __UART2_H__ */

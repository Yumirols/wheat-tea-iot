#ifndef __UART1_H__
#define __UART1_H__

#include "common_def.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "gpio.h"
#include "uart.h"
#include "stdio.h"

// UART1配置
#define UART1_BUS                  CONFIG_UART_BUS
#define UART1_RX_PIN               GPIO_16
#define UART1_TX_PIN               GPIO_15
#define UART1_RX_PIN_MODE          PIN_MODE_2
#define UART1_TX_PIN_MODE          PIN_MODE_2

// 缓冲区配置
#define UART1_RX_BUFFER_SIZE       1024

/**
 * @brief UART1初始化函数
 * @param baud_rate 波特率
 * @return int 成功返回0，失败返回-1
 */
int uart1_init(uint32_t baud_rate);

/**
 * @brief UART1发送数据
 * @param data 发送数据缓冲区
 * @param length 数据长度
 * @return int 成功返回0，失败返回-1
 */
int uart1_send(const uint8_t *data, uint16_t length);

/**
 * @brief UART1发送字符串
 * @param str 字符串指针
 * @return int 成功返回0，失败返回-1
 */
int uart1_send_string(const char *str);

/**
 * @brief UART1接收数据
 * @param buffer 接收缓冲区
 * @param buffer_size 缓冲区大小
 * @param timeout_ms 超时时间(毫秒)
 * @return int 实际接收数据长度，失败返回-1
 */
int uart1_receive(uint8_t *buffer, uint16_t buffer_size, uint32_t timeout_ms);

/**
 * @brief UART1反初始化
 */
void uart1_deinit(void);

/**
 * @brief UART1演示任务
 */
void uart1_demo_task(void);

#endif /* __UART1_H__ */

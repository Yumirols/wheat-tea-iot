/*
 * 农眼卫士 - CO2传感器驱动头文件
 * 适配 MH-Z19C / MH-Z14A 等串口二氧化碳传感器
 * UART 9600bps 8N1
 */

#ifndef __CO2_H__
#define __CO2_H__

#include "common_def.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "gpio.h"
#include "stdio.h"
#include "uart.h"

#define CO2_UART_BUS         1
#define CO2_UART_BAUDRATE    9600
#define CO2_UART_TX_PIN      17
#define CO2_UART_RX_PIN      18

#define CO2_CMD_LEN          9
#define CO2_RESP_LEN         9
#define CO2_RECV_BUF_SIZE    32

int co2_init(void);
int co2_read_data(uint16_t *co2_ppm);
uint16_t co2_get_value(void);
void co2_deinit(void);

#endif /* __CO2_H__ */

/*
 * 农眼卫士 - CO2传感器驱动
 * 适配 MH-Z19C (UART 9600bps 8N1)
 */

#ifndef __CO2_H__
#define __CO2_H__

#include "common_def.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "gpio.h"
#include "uart.h"

#define CO2_UART_BUS      2
#define CO2_UART_BAUDRATE 9600
#define CO2_UART_TX_PIN   8
#define CO2_UART_RX_PIN   7

int co2_init(void);
int co2_read_data(uint16_t *co2_ppm);
uint16_t co2_get_value(void);

#endif

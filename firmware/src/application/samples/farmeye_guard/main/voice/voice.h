/*
 * 农眼卫士 - su-03T 语音模块驱动 (UART)
 * 波特率: 9600bps 8N1
 * 通过UART接收语音指令码, 或发送播报指令
 */

#ifndef __VOICE_H__
#define __VOICE_H__

#include "common_def.h"
#include "pinctrl.h"
#include "uart.h"
#include "gpio.h"

#define VOICE_UART_BUS      0
#define VOICE_UART_BAUDRATE 9600
#define VOICE_UART_TX_PIN   17
#define VOICE_UART_RX_PIN   18

int  voice_init(void);
void voice_audio_play(const char *text);
int  voice_get_cmd(void);
void voice_clear_cmd(void);

#endif

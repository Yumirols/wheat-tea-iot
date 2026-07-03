/*
 * 农眼卫士 - 蜂鸣器驱动
 */

#ifndef __BEEP_H__
#define __BEEP_H__

#include "common_def.h"
#include "pinctrl.h"
#include "gpio.h"

#define BEEP_PIN GPIO_11

int  beep_init(void);
void beep_on(void);
void beep_off(void);
void beep_toggle(void);

#endif

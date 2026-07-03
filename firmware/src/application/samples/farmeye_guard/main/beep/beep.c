/*
 * 农眼卫士 - 蜂鸣器驱动
 */

#include "beep.h"

int beep_init(void)
{
    uapi_pin_set_mode(BEEP_PIN, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(BEEP_PIN, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(BEEP_PIN, GPIO_LEVEL_LOW);
    printf("Beep init OK (GPIO_%d)\r\n", BEEP_PIN);
    return 0;
}

void beep_on(void)  { uapi_gpio_set_val(BEEP_PIN, GPIO_LEVEL_HIGH); }
void beep_off(void) { uapi_gpio_set_val(BEEP_PIN, GPIO_LEVEL_LOW); }
void beep_toggle(void) { uapi_gpio_toggle(BEEP_PIN); }

/*
 * 农眼卫士 - 继电器控制驱动
 */

#include "relay.h"

int relay_init(void)
{
    uapi_pin_set_mode(RELAY_SPRAY_PIN, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(RELAY_SPRAY_PIN, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(RELAY_SPRAY_PIN, GPIO_LEVEL_LOW);

    uapi_pin_set_mode(RELAY_IRRIG_PIN, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(RELAY_IRRIG_PIN, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(RELAY_IRRIG_PIN, GPIO_LEVEL_LOW);

    printf("Relay init OK (Spray:GPIO_%d, Irrig:GPIO_%d)\r\n", RELAY_SPRAY_PIN, RELAY_IRRIG_PIN);
    return 0;
}

void relay_spray_on(void)  { uapi_gpio_set_val(RELAY_SPRAY_PIN, GPIO_LEVEL_HIGH); printf("Spray ON\r\n"); }
void relay_spray_off(void) { uapi_gpio_set_val(RELAY_SPRAY_PIN, GPIO_LEVEL_LOW);  printf("Spray OFF\r\n"); }
void relay_irrig_on(void)  { uapi_gpio_set_val(RELAY_IRRIG_PIN, GPIO_LEVEL_HIGH); printf("Irrig ON\r\n"); }
void relay_irrig_off(void) { uapi_gpio_set_val(RELAY_IRRIG_PIN, GPIO_LEVEL_LOW);  printf("Irrig OFF\r\n"); }

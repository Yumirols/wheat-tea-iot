#include "led.h"
#include "pinctrl.h"
#include "gpio.h"
#include "stdio.h"

/* 定义LED引脚变量 */
static pin_t g_led1 = CONFIG_LED1_PIN;
static pin_t g_led2 = CONFIG_LED2_PIN;
static pin_t g_led3 = GPIO_01;

/**
 * @brief LED初始化函数
 */
int led_init(void)
{
    // 设置IO复用关系，使用普通IO功能
    uapi_pin_set_mode(g_led1, PIN_MODE_0);
    uapi_pin_set_mode(g_led2, PIN_MODE_0);
    uapi_pin_set_mode(g_led3, PIN_MODE_0);

    // 设置IO引脚的方向为输出
    uapi_gpio_set_dir(g_led1, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_dir(g_led2, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_dir(g_led3, GPIO_DIRECTION_OUTPUT);

    // 设置IO引脚的初始电平为低电平（熄灭状态）
    uapi_gpio_set_val(g_led1, GPIO_LEVEL_LOW);
    uapi_gpio_set_val(g_led2, GPIO_LEVEL_LOW);
    uapi_gpio_set_val(g_led3, GPIO_LEVEL_LOW);

    printf("LED初始化完成: LED1-PIN%d, LED2-PIN%d\n", g_led1, g_led2);
    
    return 0;
}

/**
 * @brief LED翻转函数
 */
void led_toggle(void)
{
    uapi_gpio_toggle(g_led1);
    uapi_gpio_toggle(g_led2);
    uapi_gpio_toggle(g_led3);
    printf("LED State Toggle\n");
}

/**
 * @brief 打开指定LED（点亮）
 */
int led_on(int led_num)
{
    switch(led_num) {
        case 1:
            uapi_gpio_set_val(g_led1, GPIO_LEVEL_HIGH);
            printf("LED1 ON\n");
            break;
        case 2:
            uapi_gpio_set_val(g_led2, GPIO_LEVEL_HIGH);
            printf("LED2 ON\n");
            break;
        default:
            printf("LED Number: %d\n", led_num);
            return -1;
    }
    return 0;
}

/**
 * @brief 关闭指定LED（熄灭）
 */
int led_off(int led_num)
{
    switch(led_num) {
        case 1:
            uapi_gpio_set_val(g_led1, GPIO_LEVEL_LOW);
            printf("LED1 OFF\n");
            break;
        case 2:
            uapi_gpio_set_val(g_led2, GPIO_LEVEL_LOW);
            printf("LED2 OFF\n");
            break;
        default:
            printf("Wrong LED NUMBER: %d\n", led_num);
            return -1;
    }
    return 0;
}

/**
 * @brief 获取LED状态
 */
int led_get(int led_num)
{
    int level;
    
    switch(led_num) {
        case 1:
            level = uapi_gpio_get_val(g_led1);
            break;
        case 2:
            level = uapi_gpio_get_val(g_led2);
            break;
        default:
            printf("WRONG LED NUMBER: %d\n", led_num);
            return -1;
    }
    
    printf("LED%d STATE: %s\n", led_num, level ? "ON" : "OFF");
    return level;
}

/**
 * @brief LED测试任务
 */
void *led_test_task(const char *arg)
{
    unused(arg);

    // 初始化LED
    if (led_init() != 0) {
        printf("LED INIT FAIL!\n");
        return NULL;
    }

    printf("LED TEST TASK START RUNNING...\n");

    // 测试单独控制LED
    printf("=== Singe Test === \n");
    led_on(1);      // 点亮LED1
    osal_msleep(1000);
    led_on(2);      // 点亮LED2
    osal_msleep(1000);
    led_off(1);     // 熄灭LED1
    osal_msleep(1000);
    led_off(2);     // 熄灭LED2
    osal_msleep(1000);

    printf("=== Blink Test ===\n");
    while (1) {
        // 使用toggle函数实现双LED同步闪烁
        led_toggle();
        osal_msleep(1000);
    }

    return NULL;
}

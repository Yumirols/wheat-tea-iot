#include "beep.h"
#include "pinctrl.h"
#include "gpio.h"
#include "stdio.h"

// /* 定义蜂鸣器引脚和配置 */
// #define CONFIG_BEEP_PIN 0

/* 定义蜂鸣器引脚变量 */
static pin_t g_beep_pin = CONFIG_BEEP_PIN;

/**
 * @brief 蜂鸣器初始化函数
 */
int beep_init(void)
{
    // 设置IO复用关系，使用普通IO功能
    uapi_pin_set_mode(g_beep_pin, PIN_MODE_0);

    // 设置IO引脚的方向为输出
    uapi_gpio_set_dir(g_beep_pin, GPIO_DIRECTION_OUTPUT);

    // 设置IO引脚的初始电平为低电平（静音状态）
    uapi_gpio_set_val(g_beep_pin, GPIO_LEVEL_LOW);

    printf("蜂鸣器初始化完成: BEEP-PIN%d\n", g_beep_pin);
    
    return 0;
}

/**
 * @brief 蜂鸣器翻转函数
 */
void beep_toggle(void)
{
    uapi_gpio_toggle(g_beep_pin);
    printf("蜂鸣器状态翻转\n");
}

/**
 * @brief 打开蜂鸣器（开始鸣叫）
 */
int beep_on(void)
{
    uapi_gpio_set_val(g_beep_pin, GPIO_LEVEL_HIGH);
    printf("蜂鸣器开始鸣叫\n");
    return 0;
}

/**
 * @brief 关闭蜂鸣器（停止鸣叫）
 */
int beep_off(void)
{
    uapi_gpio_set_val(g_beep_pin, GPIO_LEVEL_LOW);
    printf("蜂鸣器停止鸣叫\n");
    return 0;
}

/**
 * @brief 获取蜂鸣器状态
 */
int beep_get_status(void)
{
    int level = uapi_gpio_get_val(g_beep_pin);
    printf("蜂鸣器状态: %s\n", level ? "鸣叫" : "静音");
    return level;
}

/**
 * @brief 蜂鸣器测试任务
 */
void *beep_test_task(const char *arg)
{
    unused(arg);

    // 初始化蜂鸣器
    if (beep_init() != 0) {
        printf("蜂鸣器初始化失败!\n");
        return NULL;
    }

    printf("蜂鸣器测试任务开始运行...\n");

    // 测试蜂鸣器控制
    printf("=== 蜂鸣器控制测试 ===\n");
    beep_on();      // 打开蜂鸣器
    osal_msleep(500);
    beep_off();     // 关闭蜂鸣器
    osal_msleep(500);
    
    beep_on();      // 再次打开蜂鸣器
    osal_msleep(500);
    beep_off();     // 再次关闭蜂鸣器
    osal_msleep(500);

    printf("=== 蜂鸣器闪烁测试 ===\n");
    while (1) {
        // 使用toggle函数实现蜂鸣器交替鸣叫
        beep_toggle();
        osal_msleep(1000);
    }

    return NULL;
}
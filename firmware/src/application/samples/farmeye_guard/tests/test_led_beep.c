/*
 * 单元测试: LED 闪烁 + 蜂鸣器
 */
#include "test_main.h"
#include "../main/led/led.h"
#include "../main/beep/beep.h"

static int test_led_init(void)
{
    if (led_init() != 0) return TEST_FAIL;
    printf("LED init done\r\n");
    return TEST_PASS;
}

static int test_led_blink(void)
{
    for (int i = 0; i < 3; i++) {
        led_on(1);
        osal_msleep(300);
        led_off(1);
        osal_msleep(300);
    }
    printf("LED1 blink 3x done\r\n");
    return TEST_PASS;
}

static int test_beep_init(void)
{
    beep_init();
    printf("Beep init done\r\n");
    return TEST_PASS;
}

static int test_beep_sound(void)
{
    beep_on();
    osal_msleep(200);
    beep_off();
    printf("Beep test done\r\n");
    return TEST_PASS;
}

test_case_t g_led_beep_tests[] = {
    {"led_init", test_led_init},
    {"led_blink", test_led_blink},
    {"beep_init", test_beep_init},
    {"beep_sound", test_beep_sound},
};

int g_led_beep_test_count = sizeof(g_led_beep_tests) / sizeof(g_led_beep_tests[0]);

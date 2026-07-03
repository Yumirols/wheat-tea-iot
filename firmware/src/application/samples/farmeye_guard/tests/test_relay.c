/*
 * 单元测试: 继电器控制
 */
#include "test_main.h"
#include "../main/relay/relay.h"

static int test_relay_init(void)
{
    if (relay_init() != 0) return TEST_FAIL;
    printf("Relay init done\r\n");
    return TEST_PASS;
}

static int test_relay_spray(void)
{
    printf("Spray ON...\r\n");
    relay_spray_on();
    osal_msleep(1000);
    printf("Spray OFF...\r\n");
    relay_spray_off();
    return TEST_PASS;
}

static int test_relay_irrig(void)
{
    printf("Irrig ON...\r\n");
    relay_irrig_on();
    osal_msleep(1000);
    printf("Irrig OFF...\r\n");
    relay_irrig_off();
    return TEST_PASS;
}

test_case_t g_relay_tests[] = {
    {"relay_init", test_relay_init},
    {"relay_spray", test_relay_spray},
    {"relay_irrig", test_relay_irrig},
};

int g_relay_test_count = sizeof(g_relay_tests) / sizeof(g_relay_tests[0]);

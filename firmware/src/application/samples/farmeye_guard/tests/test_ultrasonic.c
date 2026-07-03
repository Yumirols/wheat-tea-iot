/*
 * 单元测试: HC-SR04 超声波测距
 */
#include "test_main.h"
#include "../main/hcsr04/hcsr04.h"

static int test_ultrasonic_init(void)
{
    hcsr04_init();
    printf("HC-SR04 init done\r\n");
    return TEST_PASS;
}

static int test_ultrasonic_read(void)
{
    osal_msleep(100);
    int32_t dist = hcsr04_get_distance();
    printf("Distance: %d cm\r\n", dist);
    if (dist == HCSR04_ERR_TIMEOUT) {
        printf("No echo - sensor may be unconnected\r\n");
        return TEST_FAIL;
    }
    if (dist < 0 || dist > 800) return TEST_FAIL;
    return TEST_PASS;
}

static int test_ultrasonic_multiple(void)
{
    int valid = 0;
    for (int i = 0; i < 5; i++) {
        osal_msleep(200);
        int32_t dist = hcsr04_get_distance();
        printf("Dist[%d]: %d cm\r\n", i, dist);
        if (dist >= 0 && dist <= 800) valid++;
    }
    return (valid >= 3) ? TEST_PASS : TEST_FAIL;
}

test_case_t g_ultrasonic_tests[] = {
    {"hcsr04_init", test_ultrasonic_init},
    {"hcsr04_read", test_ultrasonic_read},
    {"hcsr04_read(5x)", test_ultrasonic_multiple},
};

int g_ultrasonic_test_count = sizeof(g_ultrasonic_tests) / sizeof(g_ultrasonic_tests[0]);

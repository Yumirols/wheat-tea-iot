/*
 * 单元测试: MH-Z19C CO2 传感器
 */
#include "test_main.h"
#include "../main/co2/co2.h"

static int test_co2_init(void)
{
    if (co2_init() != 0) return TEST_FAIL;
    printf("CO2 init done\r\n");
    return TEST_PASS;
}

static int test_co2_read(void)
{
    uint16_t val = 0;
    osal_msleep(2000);
    int ret = co2_read_data(&val);
    if (ret != 0) {
        printf("CO2 read timeout\r\n");
        return TEST_FAIL;
    }
    printf("CO2: %d ppm\r\n", val);
    if (val < 350 || val > 5000) {
        printf("CO2 value out of range\r\n");
        return TEST_FAIL;
    }
    return TEST_PASS;
}

static int test_co2_multiple(void)
{
    int pass = 0;
    for (int i = 0; i < 3; i++) {
        uint16_t val = 0;
        osal_msleep(3000);
        if (co2_read_data(&val) == 0 && val >= 350 && val <= 5000) {
            printf("CO2[%d]: %d ppm\r\n", i, val);
            pass++;
        }
    }
    return (pass >= 2) ? TEST_PASS : TEST_FAIL;
}

test_case_t g_co2_tests[] = {
    {"co2_init", test_co2_init},
    {"co2_read", test_co2_read},
    {"co2_read(3x)", test_co2_multiple},
};

int g_co2_test_count = sizeof(g_co2_tests) / sizeof(g_co2_tests[0]);

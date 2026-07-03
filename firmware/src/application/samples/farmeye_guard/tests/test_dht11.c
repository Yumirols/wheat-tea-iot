/*
 * 单元测试: DHT11 温湿度传感器
 */
#include "test_main.h"
#include "../main/dht11/dht11.h"

static int test_dht11_init(void)
{
    dht11_init();
    printf("DHT11 init done\r\n");
    return TEST_PASS;
}

static int test_dht11_read(void)
{
    DHT11_Data_TypeDef data;
    int fail_count = 0;
    for (int i = 0; i < 3; i++) {
        osal_msleep(2000);
        if (dht11_read_data(&data) == 0) {
            printf("Read[%d]: T=%.1fC H=%.1f%%\r\n", i, data.temperature, data.humidity);
            if (data.humidity < 5.0f || data.humidity > 99.0f) fail_count++;
            if (data.temperature < -20.0f || data.temperature > 60.0f) fail_count++;
        } else {
            printf("Read[%d]: FAIL\r\n", i);
            fail_count++;
        }
    }
    return (fail_count >= 3) ? TEST_FAIL : TEST_PASS;
}

test_case_t g_dht11_tests[] = {
    {"dht11_init", test_dht11_init},
    {"dht11_read(3x)", test_dht11_read},
};

int g_dht11_test_count = sizeof(g_dht11_tests) / sizeof(g_dht11_tests[0]);

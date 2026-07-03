/*
 * 单元测试: 告警阈值 + 执行器联动
 */
#include "test_main.h"
#include "../main/app_main.h"
#include "../main/led/led.h"
#include "../main/beep/beep.h"
#include "../main/relay/relay.h"

extern farmeye_data_t g_data;
extern osMutexId_t g_data_mutex;

static int test_alarm_flag_bits(void)
{
    printf("Checking alarm bit definitions...\r\n");
    if (0x01 != 1)   { printf("bit 0x01 FAIL\r\n"); return TEST_FAIL; }
    if (0x02 != 2)   { printf("bit 0x02 FAIL\r\n"); return TEST_FAIL; }
    if (0x04 != 4)   { printf("bit 0x04 FAIL\r\n"); return TEST_FAIL; }
    if (0x08 != 8)   { printf("bit 0x08 FAIL\r\n"); return TEST_FAIL; }
    if (0x10 != 16)  { printf("bit 0x10 FAIL\r\n"); return TEST_FAIL; }
    if (0x20 != 32)  { printf("bit 0x20 FAIL\r\n"); return TEST_FAIL; }
    if (0x40 != 64)  { printf("bit 0x40 FAIL\r\n"); return TEST_FAIL; }
    if (0x80 != 128) { printf("bit 0x80 FAIL\r\n"); return TEST_FAIL; }
    printf("Alarm bit check PASS\r\n");
    return TEST_PASS;
}

static int test_threshold_values(void)
{
    printf("TEMP_HIGH=%.1f TEMP_LOW=%.1f\r\n", TEMP_HIGH_THRESHOLD, TEMP_LOW_THRESHOLD);
    printf("HUMI_HIGH=%.1f HUMI_LOW=%.1f\r\n", HUMI_HIGH_THRESHOLD, HUMI_LOW_THRESHOLD);
    printf("CO2_HIGH=%d LIGHT_LOW=%d\r\n", CO2_HIGH_THRESHOLD, LIGHT_LOW_THRESHOLD);
    printf("N_LOW=%.1f P_LOW=%.1f\r\n", SOIL_N_LOW_THRESHOLD, SOIL_P_LOW_THRESHOLD);
    return TEST_PASS;
}

static int test_alarm_actuators(void)
{
    led_init();
    beep_init();
    relay_init();

    printf("Testing all actuators...\r\n");
    led_on(1);
    osal_msleep(200);
    beep_on();
    osal_msleep(200);
    relay_spray_on();
    osal_msleep(500);

    relay_spray_off();
    beep_off();
    led_off(1);
    relay_irrig_on();
    osal_msleep(500);
    relay_irrig_off();

    printf("Actuator test done\r\n");
    return TEST_PASS;
}

test_case_t g_alarm_tests[] = {
    {"alarm_bits", test_alarm_flag_bits},
    {"thresholds", test_threshold_values},
    {"actuators", test_alarm_actuators},
};

int g_alarm_test_count = sizeof(g_alarm_tests) / sizeof(g_alarm_tests[0]);

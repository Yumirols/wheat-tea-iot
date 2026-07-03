#include "test_main.h"
#include "soc_osal.h"
#include "app_init.h"
#include "cmsis_os2.h"
#include "securec.h"

static int total_pass = 0;
static int total_fail = 0;

void test_runner(const test_case_t *cases, int count)
{
    printf("\r\n========== UNIT TEST START ==========\r\n");
    for (int i = 0; i < count; i++) {
        printf("[%d/%d] %s ... ", i + 1, count, cases[i].name);
        int ret = cases[i].func();
        if (ret == TEST_PASS) {
            printf("PASS\r\n");
            total_pass++;
        } else {
            printf("FAIL (ret=%d)\r\n", ret);
            total_fail++;
        }
        osal_msleep(500);
    }
    printf("========== UNIT TEST END ==========\r\n");
    printf("Result: %d PASS, %d FAIL, %d TOTAL\r\n\r\n",
           total_pass, total_fail, count);
}

static void test_entry(void)
{
    printf("FarmEye Guard Unit Test Suite\r\n");
    osal_msleep(500);

#ifdef CONFIG_TEST_DHT11
    extern test_case_t g_dht11_tests[];
    extern int g_dht11_test_count;
    test_runner(g_dht11_tests, g_dht11_test_count);
#endif

#ifdef CONFIG_TEST_CO2
    extern test_case_t g_co2_tests[];
    extern int g_co2_test_count;
    test_runner(g_co2_tests, g_co2_test_count);
#endif

#ifdef CONFIG_TEST_ULTRASONIC
    extern test_case_t g_ultrasonic_tests[];
    extern int g_ultrasonic_test_count;
    test_runner(g_ultrasonic_tests, g_ultrasonic_test_count);
#endif

#ifdef CONFIG_TEST_LED_BEEP
    extern test_case_t g_led_beep_tests[];
    extern int g_led_beep_test_count;
    test_runner(g_led_beep_tests, g_led_beep_test_count);
#endif

#ifdef CONFIG_TEST_RELAY
    extern test_case_t g_relay_tests[];
    extern int g_relay_test_count;
    test_runner(g_relay_tests, g_relay_test_count);
#endif

#ifdef CONFIG_TEST_OLED
    extern test_case_t g_oled_tests[];
    extern int g_oled_test_count;
    test_runner(g_oled_tests, g_oled_test_count);
#endif

#ifdef CONFIG_TEST_ALARM
    extern test_case_t g_alarm_tests[];
    extern int g_alarm_test_count;
    test_runner(g_alarm_tests, g_alarm_test_count);
#endif

    printf("All tests completed. Halting.\r\n");
    while (1) { osal_msleep(1000); }
}

app_run(test_entry);

/*
 * 单元测试: SSD1306 OLED 显示屏
 */
#include "test_main.h"
#include "../main/oled/oled.h"
#include "../main/oled/bsp_oled.h"

static int test_oled_init(void)
{
    errcode_t ret = oled_init();
    if (ret != ERRCODE_SUCC) {
        printf("OLED init FAIL: %d\r\n", ret);
        return TEST_FAIL;
    }
    printf("OLED init done\r\n");
    return TEST_PASS;
}

static int test_oled_display(void)
{
    bsp_oled_Clear();
    bsp_oled_DrawString(0, 0, "FarmEye Guard", Font_7x10, White);
    bsp_oled_DrawString(0, 20, "Unit Test OK!", Font_7x10, White);
    bsp_oled_UpdateScreen();
    printf("OLED display test done\r\n");
    osal_msleep(2000);
    return TEST_PASS;
}

static int test_oled_clear(void)
{
    bsp_oled_Clear();
    bsp_oled_UpdateScreen();
    printf("OLED clear done\r\n");
    return TEST_PASS;
}

test_case_t g_oled_tests[] = {
    {"oled_init", test_oled_init},
    {"oled_display", test_oled_display},
    {"oled_clear", test_oled_clear},
};

int g_oled_test_count = sizeof(g_oled_tests) / sizeof(g_oled_tests[0]);

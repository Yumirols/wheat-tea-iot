/*
 * 农眼卫士 - su-03T 语音模块驱动
 * 中断接收语音指令码, 支持文本播报
 */

#include "voice.h"
#include "securec.h"

static uint8_t g_voice_init = 0;
static uint8_t g_voice_rx_buf[64] = {0};
static uint8_t g_voice_rx_flag = 0;
static uint8_t g_voice_cmd = 0;

static uart_buffer_config_t g_voice_cfg = {
    .rx_buffer = g_voice_rx_buf, .rx_buffer_size = sizeof(g_voice_rx_buf)
};

static void voice_rx_cb(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    if (buffer && length > 0) {
        memcpy_s(g_voice_rx_buf, sizeof(g_voice_rx_buf), buffer, length);
        g_voice_cmd = g_voice_rx_buf[0];
        g_voice_rx_flag = 1;
    }
}

int voice_init(void)
{
    if (g_voice_init) return 0;
    uapi_pin_set_mode(VOICE_UART_TX_PIN, PIN_MODE_1);
    uapi_pin_set_mode(VOICE_UART_RX_PIN, PIN_MODE_1);

    uart_attr_t attr = {.baud_rate = VOICE_UART_BAUDRATE, .data_bits = UART_DATA_BIT_8, .stop_bits = UART_STOP_BIT_1, .parity = UART_PARITY_NONE};
    uart_pin_config_t pin = {.tx_pin = S_MGPIO0, .rx_pin = S_MGPIO1, .cts_pin = PIN_NONE, .rts_pin = PIN_NONE};

    uapi_uart_deinit(VOICE_UART_BUS);
    if (uapi_uart_init(VOICE_UART_BUS, &pin, &attr, NULL, &g_voice_cfg) != 0) { printf("Voice UART init fail\r\n"); return -1; }
    uapi_uart_register_rx_callback(VOICE_UART_BUS, UART_RX_CONDITION_MASK_IDLE, 1, voice_rx_cb);
    g_voice_init = 1;
    printf("Voice init OK (UART%d)\r\n", VOICE_UART_BUS);
    return 0;
}

void voice_audio_play(const char *text)
{
    if (text) uapi_uart_write(VOICE_UART_BUS, (uint8_t *)text, strlen(text), 0);
}

int voice_get_cmd(void)
{
    if (g_voice_rx_flag) return g_voice_cmd;
    return -1;
}

void voice_clear_cmd(void)
{
    g_voice_rx_flag = 0;
    g_voice_cmd = 0;
}

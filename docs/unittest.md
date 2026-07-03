# 农眼卫士 — 单元测试指南

## 一、测试概览

| 测试方式 | 适用场景 | 说明 |
|---|---|---|
| **独立示例测试** | 单个传感器/驱动调试 | 编译独立示例项目，烧录后通过串口验证 |
| **HiSpark 测试套件** | 平台级功能验证 | 启用 `TEST_SUITE` 宏，通过命令行交互测试 |
| **本地模式测试** | 主应用功能验证（离线） | 启用 `LOCAL_TEST`，跳过 WiFi/MQTT 仅输出 JSON |
| **云端集成测试** | 端到端数据链路验证 | 关闭 `LOCAL_TEST`，通过华为云 IoTDA 日志验证上报 |

## 二、独立示例测试

### 2.1 编译独立示例

在 Kconfig（`farmeye_guard/main/Kconfig`）中启用对应模块后编译：

```bash
python build.py -c ws63-liteos-app
```

### 2.2 各模块测试清单

| # | 模块 | Kconfig 宏 | 验证点 | 预期输出 |
|---|------|----------|--------|---------|
| 1 | DHT11 | `ENABLE_DHT11` | 温湿度读取 | `T:25.5C H:60.2%` |
| 2 | LDR 光照 | `ENABLE_ADC` | ADC 通道 5 | `ADC:xxx` |
| 3 | MH-Z19C CO2 | `ENABLE_CO2` | UART2 读取 | `CO2=450 ppm` |
| 4 | HC-SR04 | `ENABLE_HUAWEIIOT` → `ENABLE_FARMEYE_GUARD` | 超声波测距 | `Dist:150cm` |
| 5 | LED | `ENABLE_LED` | GPIO 翻转 | LED1/LED2 闪烁 |
| 6 | 蜂鸣器 | `ENABLE_BEEP` | PWM 输出 | 蜂鸣器鸣响 |
| 7 | 继电器 | 集成在 `ENABLE_FARMEYE_GUARD` | GPIO 高低电平 | 继电器吸合/释放 |
| 8 | OLED 显示 | 集成在 `ENABLE_FARMEYE_GUARD` | I2C 通信 | 屏幕显示传感器数据 |
| 9 | su-03T 语音 | `ENABLE_VOICE` | UART0 通信 | 语音播报成功 |
| 10 | WiFi 连接 | 集成在 `ENABLE_FARMEYE_GUARD` | 连接热点 | `STA connect success.` |
| 11 | MQTT 上报 | 集成在 `ENABLE_FARMEYE_GUARD` | 云端数据 | IoTDA 消息跟踪显示成功 |
| 12 | HelloWorld | `ENABLE_HELLOWORLD` | 串口打印 | `Hello World` |

### 2.3 测试流程

```
1. 打开 HiSpark Studio → KConfig
2. 勾选 Application → Enable FarmEye Guard System → Enable FarmEye Guard System
3. (可选) 勾选单个传感器示例进行独立测试
4. Save → Rebuild → 烧录
5. HiSpark Studio 监视器观察串口输出
```

## 三、本地模式（LOCAL_TEST）

### 3.1 启用方式

在 `farmeye_guard/main/app_main.h` 中定义 `LOCAL_TEST` 宏：

```c
#define LOCAL_TEST
```

### 3.2 测试行为

- 跳过 WiFi 连接和 MQTT 云端上报
- 传感器正常初始化并采集
- 每 5 秒打印 JSON 数据到串口

### 3.3 验证点

```
[JSON] {"services":[{"service_id":"farmeye_env","properties":{
  "temperature":"25.5","humidity":"60.2","light":"85","co2":"450",
  "soil_n":"50.1","soil_p":"24.0","soil_k":"51.7",
  "distance":"150","rssi":"-45",
  "ip_addr":"0.0.0.0","mac_addr":"XX:XX:XX:XX:XX:XX",
  "alarm_flag":"0"}}]}
```

检查所有字段是否有值（非 0、非空字符串）。

## 四、HiSpark 测试套件

### 4.1 启用方式

在 `main.c` 中启用 `TEST_SUITE` 宏，编译后通过串口 AT 命令行执行测试函数。

### 4.2 内置测试命令

| 命令 | 功能 |
|------|------|
| `AT+VER` | 查询固件版本 |
| `AT+RST` | 软复位 |
| `AT+WIFI?` | 查询 WiFi 状态 |
| `test_fun` | 测试异常处理（强制写入地址 0） |

## 五、MQTT 云端集成测试

### 5.1 前提

1. `LOCAL_TEST` 已注释
2. WiFi SSID/密码已配置（`app_main.h`）
3. 华为云 IoTDA 设备密钥已配置（`app_main.h`）

### 5.2 验证步骤

```
1. 编译烧录
2. 观察串口: "MQTT connected to cloud!" 表示连接成功
3. 华为云 IoTDA 控制台 → 设备 → 消息跟踪
4. 验证属性上报状态为"成功"
5. 验证设备影子刷新成功
```

### 5.3 告警联动测试

| 测试方法 | 预期 |
|---------|------|
| DHT11 用手指升温至 >38℃ | OLED 显示 `ALM:0x01`，蜂鸣+LED 亮 |
| 遮挡 LDR 光照传感器 | OLED 显示 `ALM:0x10`，蜂鸣+LED 亮 |
| 遮住 HC-SR04 传感器至近距离 | `distance` 值变小 |

## 六、驱动单元测试代码示例

### 6.1 DHT11 测试

```c
// farmeye_guard/12-dht11/app_main.c
#include "dht11/dht11.h"

static void dht11_test_task(void)
{
    DHT11_Data_TypeDef data;
    dht11_init();
    while (1) {
        if (dht11_read_data(&data) == 0) {
            printf("T:%.1fC H:%.1f%%\r\n", data.temperature, data.humidity);
        } else {
            printf("DHT11 read fail\r\n");
        }
        osal_msleep(3000);
    }
}
```

### 6.2 CO2 测试

```c
// farmeye_guard/main/co2/co2.c
int test_co2_read(void) {
    uint16_t val = 0;
    if (co2_init() != 0) return -1;
    if (co2_read_data(&val) != 0) return -1;
    printf("CO2: %d ppm\r\n", val);
    return (val > 0) ? 0 : -1;
}
```

### 6.3 超声波测试

```c
int test_ultrasonic(void) {
    hcsr04_init();
    int32_t dist = hcsr04_get_distance();
    printf("Distance: %d cm\r\n", dist);
    return (dist >= 0) ? 0 : -1;
}
```

## 七、编码规范检查

| 工具 | 配置 | 说明 |
|------|------|------|
| `.clang-format` | 项目根目录 | C 代码格式化规范 |
| `OAT.xml` | 项目根目录 | OpenHarmony 代码审查配置 |

运行格式化检查：

```bash
clang-format -style=file -i firmware/src/application/samples/farmeye_guard/main/*.c
```

## 八、测试注意事项

1. **CO2 传感器**需要预热 3 分钟才能输出稳定数据
2. **HC-SR04** 在无遮挡时可能返回 -1（超时），属正常行为
3. **DHT11** 读取间隔至少 1 秒，过快的读取会导致校验失败
4. **I2C OLED** 若初始化失败，检查 GPIO_15/16 引脚是否被其他外设占用
5. **UART 引脚复用**：CO2 使用 UART2（GPIO7/8），语音使用 UART0（GPIO17/18），WiFi 日志使用 UART 控制台

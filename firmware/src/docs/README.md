# 农眼卫士 (NongYan WeiShi) — WS63 嵌入式固件

## 项目简介

基于华为海思 **WS63** 芯片的物联网环境采集固件，运行于采用 **LiteOS** 内核的 **OpenHarmony（鸿蒙）** 轻量系统之上，是 **FBB（Family Big Box）** 统一开发框架下的 "农眼卫士" 应用。

**硬件规格：**

| 项目 | 参数 |
|---|---|
| MCU | HiSilicon WS63 |
| CPU 架构 | RISC-V 32-bit (RV32IMFC)，硬浮点 |
| 主频 | 24 MHz（TCXO 校准） |
| 内存 | ITCM + DTCM + SRAM + 外部 SPI Flash |
| I-Cache | 32 KB |
| D-Cache | 4 KB |
| 无线 | Wi-Fi 6 (2.4GHz)、BLE 5.x、星闪 SLE |
| 特色 | 雷达人体运动感知 |

## 目录结构

```
src/firmware/
├── build.py                      # 构建入口（Python）
├── CMakeLists.txt                # 顶层 CMake
├── build/                        # 构建系统（脚本、工具链、目标配置）
│   ├── config/
│   │   └── target_config/ws63/   # WS63 目标配置
│   └── toolchains/               # RISC-V GCC 工具链
├── application/                  # 应用层
│   ├── ws63/
│   │   ├── ws63_liteos_application/  # ★ 主应用（main.c + 启动向量）
│   │   └── ws63_liteos_mfg/          # 量产镜像
│   └── samples/wanglian/             # 示例代码（Hello World 等）
├── kernel/                       # 操作系统内核
│   ├── liteos/liteos_v208.5.0/   # Huawei LiteOS 内核
│   ├── osal/                     # OS 抽象层（LiteOS/FreeRTOS/Linux/裸机）
│   └── osal_adapt/               # LiteOS 的 OSAL 适配实现
├── drivers/                      # 硬件驱动
│   ├── chips/ws63/               # WS63 芯片特定代码
│   │   ├── arch/riscv/riscv31/   # RISC-V 异常向量、中断处理
│   │   ├── rom/                  # ROM 预置驱动
│   │   └── porting/              # 移植层
│   ├── drivers/
│   │   ├── hal/                  # ★ 低层 HAL（寄存器级外设访问）
│   │   └── driver/               # ★ 中层驱动（线程安全 API）
│   ├── boards/ws63/evb/          # 板级支持（链接脚本、内存映射）
│   └── adapter/ohos_3.2/        # ★ OpenHarmony 外设适配层
├── middleware/                    # 中间件
│   ├── chips/ws63/               # NV、分区、OTA、异常处理、LittleFS
│   └── services/                 # Wi-Fi 服务（hostapd/wpa_supplicant）
├── protocol/                     # 无线协议栈
│   ├── wifi/                     # Wi-Fi 驱动 + 协议栈
│   ├── bt/                       # BLE/BT 协议
│   └── radar/                    # 雷达感知
├── bootloader/                   # 引导程序
├── open_source/                  # 第三方开源库
│   ├── mbedtls/                  # TLS/加密 (v3.1.0)
│   ├── GmSSL3.0/                 # 国密算法 (SM2/SM3/SM4/ZUC)
│   ├── lwip/                     # TCP/IP 协议栈
│   ├── wpa_supplicant/           # Wi-Fi 安全认证
│   ├── littlefs/                 # 轻量级嵌入式文件系统
│   ├── libcoap/                  # CoAP 协议
│   ├── cjson/                    # JSON 解析
│   └── HiLink-SDK/               # 华为云 IoT
├── tools/                        # 构建/调试辅助工具
└── include/                      # 全局头文件
```

## 快速开始

### 环境要求

| 工具 | 说明 |
|---|---|
| Python 3.7+ | 构建脚本 |
| CMake ≥ 3.14 | 构建系统 |
| Ninja 或 Make | 构建后端 |
| RISC-V GCC 工具链 | `riscv32-musl-gcc`，见 `build/toolchains/` |

### 编译

```bash
# 进入固件根目录
cd src/firmware

# 编译主应用（默认 debug）
python build.py ws63-liteos-app

# release 模式
python build.py -release ws63-liteos-app

# 指定并行数
python build.py -j4 ws63-liteos-app

# 编译 Hello World 示例
python build.py wanglian_01_hello

# 强制 clean 后编译
python build.py -c ws63-liteos-app
```

### 构建参数速查

| 参数 | 说明 |
|---|---|
| `-c` | clean 后构建 |
| `-j<N>` | 编译并行线程数 |
| `-def=XXX,YYY` | 添加编译宏；`-def=-:XXX` 屏蔽宏 |
| `-component=XXX` | 仅编译指定组件 |
| `-ninja` | 使用 Ninja 生成器 |
| `-release/-debug` | 构建变体（默认 debug） |
| `-nhso` | 跳过 HSO 数据库更新 |
| `-out_libs=PATH` | 输出合并 `.a` 而非 `.elf` |

## 软件架构

```
┌───────────────────────────────────────────────────────┐
│                  Application Layer                     │
│  ┌─────────────┐ ┌──────────┐ ┌────────────────────┐ │
│  │ wanglian/   │ │ ws63_app │ │ 自定义业务组件      │ │
│  │ (示例)      │ │ (主入口)  │ │                     │ │
│  └─────────────┘ └──────────┘ └────────────────────┘ │
├───────────────────────────────────────────────────────┤
│                Middleware Layer                        │
│  NV │ OTA │ Partition │ LittleFS │ Exception │ HiLink │
├───────────────────────────────────────────────────────┤
│                 Protocol Layer                         │
│  Wi-Fi 6  │  BLE/BT  │  星闪 SLE  │  Radar Sensing   │
├───────────────────────────────────────────────────────┤
│                  Driver Layer                          │
│  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │ ohos_3.2 Adapter │  │ Driver (线程安全 API)       │ │
│  │ IoTGpio/IotI2c/  │  │ gpio/i2c/spi/uart/pwm/...  │ │
│  │ IotUart/IotPwm...│  │                             │ │
│  └────────┬────────┘  └──────────────┬──────────────┘ │
│           │                          │                 │
│  ┌────────┴──────────────────────────┴──────────────┐ │
│  │              HAL (寄存器级外设驱动)                │ │
│  │  hal_gpio │ hal_uart │ hal_spi │ hal_i2c │ ...   │ │
│  └──────────────────────────────────────────────────┘ │
├───────────────────────────────────────────────────────┤
│                   OSAL Layer                           │
│  线程 │ 互斥锁 │ 信号量 │ 事件 │ 消息队列 │ 定时器    │
│         LiteOS / FreeRTOS / Linux / NONOS             │
├───────────────────────────────────────────────────────┤
│                LiteOS Kernel v208.5.0                  │
│                  (CMSIS-RTOS v2 API)                   │
├───────────────────────────────────────────────────────┤
│               Hardware (WS63 RISC-V)                   │
│  ITCM │ DTCM │ SRAM │ SPI Flash │ Wi-Fi/BT/SLE Modem  │
└───────────────────────────────────────────────────────┘
```

### 启动流程

```
上电 → reset_vector.S
    → runtime_init()
        → dyn_mem_cfg()          # 动态内存配置
        → do_relocation()        # 代码段/数据段搬迁到 RAM
    → main()
        → patch_init()           # Flash Patch 初始化
        → partition_init()       # Flash 分区初始化
        → pmp_enable()           # RISC-V 物理内存保护
        → cpu_cache_init()       # I/D Cache 使能
        → sys_fault_handler()    # 注册异常处理回调
        → osKernelInitialize()   # LiteOS 内核初始化
        → hw_init()              # ★ 硬件初始化
            ├── GPIO / PinMux
            ├── Timer / SysTick
            ├── TCXO 时钟校准
            ├── Watchdog (15s 超时)
            ├── eFuse 安全存储
            ├── SFC 外部 Flash
            ├── NV 非易失存储
            ├── TSENSOR 温度传感器
            └── 安全引擎初始化
        → main_initialise()      # ★ 创建系统任务（见任务表）
        → app_tasks_init()       # 执行 APP_RUN 注册的业务初始化
        → osKernelStart()        # ★ 启动 LiteOS 调度器
```

### 系统任务表

| 任务名 | 优先级 | 栈大小 | 功能 | 编译宏 |
|---|---|---|---|---|
| `app` | 27 | 0x800 | 主业务监控（内存/日志） | 必有 |
| `cmd_loop` | 1 | 0x1000 | 测试命令处理 | `TEST_SUITE` |
| `log` | 25 | 0x800 | HSO 日志任务 | `HSO_SUPPORT` |
| `bt` | 1 | 0xE00 | BLE 基础协议 | `BGLE_TASK_EXIST` |
| `bt_sdk` | 12 | 0x800 | 蓝牙 Host 主任务 | `BTH_TASK_EXIST` |
| `bth_sdk` | 13 | 0x200 | 蓝牙 Host SDK 消息 | `BTH_TASK_EXIST` |
| `recvBthDataTask` | 10 | 0x800 | 蓝牙数据接收 | `BTH_TASK_EXIST` |
| `bt_service` | 12 | 0x1000 | 蓝牙服务 | `BTH_TASK_EXIST` |
| `at` | 1 | 0x2000 | AT 命令处理 | `AT_COMMAND` |
| `wifi` | 25 | 0x2000 | Wi-Fi Host 任务 | `WIFI_TASK_EXIST` |
| `radar_driver` | 23 | 0x800 | 雷达驱动 | `CONFIG_RADAR_SERVICE` |
| `radar_feature` | 24 | 0x2600 | 雷达算法 | `CONFIG_RADAR_SERVICE` |
| `radar_demo` | 24 | 0x400 | 雷达演示 | `CONFIG_RADAR_SERVICE` |
| `hilink` | 25 | 0x2000 | 华为云 HiLink | `CONFIG_SUPPORT_HILINK` |

### 模块初始化注册机制

业务模块通过 `app_run()` 宏将初始化函数指针注入链接器段 `.zinitcall.app_run.init`，`app_tasks_init()` 遍历执行：

```c
// 注册初始化函数（会自动排入启动序列）
app_run(my_feature_init);

// 框架按序调用，无需手动管理初始化顺序
```

### OS 抽象层 (OSAL)

提供跨 OS 的统一 API，当前编译目标 `__LITEOS__` 覆盖完整特性集：

```
调度     | osal_kthread_create / set_priority / lock / unlock / yield
同步     | osal_mutex / osal_semaphore / osal_event
通信     | osal_msg_queue_create / read_copy / write_copy
时间     | osal_timer / osal_msleep
中断     | osal_irq_lock / restore
内存     | osal_kmalloc / kfree / addr / barrier / cache
```

## 技术栈

| 层级 | 组件 |
|---|---|
| 内核 | Huawei LiteOS v208.5.0 (CMSIS-RTOS v2) |
| OS 抽象 | OSAL (`__LITEOS__` / `__FREERTOS__` / `__linux__` / `__NONOS__`) |
| 加密 | mbedTLS v3.1.0 + GmSSL 3.0 (国密 SM2/SM3/SM4/ZUC) |
| TCP/IP | lwIP |
| Wi-Fi | WPA Supplicant + HostAPD |
| 文件系统 | LittleFS v2.5.0 |
| Flash | NV 非易失存储 + 分区管理 + AB OTA |
| 云服务 | HiLink SDK (华为云 IoT) + MQTT + CoAP |
| JSON | cJSON |
| 调试 | AT 命令框架 + HSO 日志系统 |
| 构建 | Python build.py + CMake + Ninja/Make |
| 工具链 | RISC-V GCC 7.3.0 (riscv32-musl-gcc) |

## 外设接口

| 外设 | HAL 驱动 | Driver API | OpenHarmony 适配 |
|---|---|---|---|
| GPIO | `hal_gpio.h` | `gpio.h` | `iot_gpio.h` |
| UART | `hal_uart.h` | `uart.h` | `iot_uart.h` |
| I2C | `hal_i2c.h` | `i2c.h` | `iot_i2c.h` |
| SPI | `hal_spi.h` | `spi.h` | — |
| PWM | `hal_pwm.h` | `pwm.h` | `iot_pwm.h` |
| ADC | `hal_adc.h` | `adc.h` | — |
| DMA | `hal_dma.h` | `dma.h` | — |
| Timer | `hal_timer.h` | `timer.h` | — |
| Watchdog | `hal_watchdog.h` | `watchdog.h` | `iot_watchdog.h` |
| SFC (Flash) | `hal_sfc.h` | `sfc.h` | `iot_sfc.h` |
| RTC | `hal_rtc_unified.h` | — | — |
| eFuse | `hal_efuse.h` | `efuse.h` | — |
| TSENSOR | `hal_tsensor.h` | `tsensor.h` | — |

## 内存布局

```
┌─────────────────┐  高地址
│   SPI Flash     │  PROGRAM (代码) + ROM_DATA + 文件系统
├─────────────────┤
│     SRAM        │  .bss / .data / .sram_text / 堆
├─────────────────┤
│     DTCM        │  .tcm_data / .tcm_bss / 栈
├─────────────────┤
│     ITCM        │  .tcm_text (高速指令)
├─────────────────┤
│     ROM         │  预置驱动代码（只读）
└─────────────────┘  低地址
```

## 相关文档

- [技术架构设计文档](ARCHITECTURE.md)
- [tem/README.md](tem/README.md) — FBB WS63 开发指南（含示例教程）
- [drivers/adapter/ohos_3.2/](drivers/adapter/ohos_3.2/) — OpenHarmony 外设适配层
- [application/samples/wanglian/](application/samples/wanglian/) — 网联团队示例代码

## 版权

Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd.

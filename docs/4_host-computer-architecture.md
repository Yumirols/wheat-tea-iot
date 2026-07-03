# 农眼卫士 — 上位机监控系统架构文档

## 1. 项目概述

**农眼卫士上位机** 是小微农业病虫害监测系统中的 PC 桌面监控端，负责图形化展示传感器数据、管理病虫害告警、远程控制农田设备。

## 2. 技术栈

| 项目 | 说明 |
|------|------|
| **语言** | Python 3.10+（目标版本 py312） |
| **GUI 框架** | PyQt5 (≥5.15) |
| **数据可视化** | matplotlib (≥3.8) |
| **HTTP 客户端** | requests (≥2.31) |
| **代码质量** | ruff (lint+format), mypy (type check) |
| **测试** | pytest (≥8.3) + unittest + mock |

## 3. 目录结构

```
host-computer/
├── .gitkeep                 # 占位文件，保留目录结构
├── api_client.py            # API 客户端 — 对接 VPS 后端 REST API
├── config.py                # 配置管理（加载/保存 config.json）
├── main.py                  # 应用入口 — PyQt5 桌面应用启动点
├── pyproject.toml           # 项目元数据和工具配置（ruff + mypy）
├── requirements.txt         # 运行时依赖
├── requirements-test.txt    # 测试依赖
├── tests/
│   └── test_core.py         # 核心层单元测试（config + api_client）
└── widgets/
    ├── __init__.py
    ├── dashboard.py         # 实时监控 — 传感器卡片 + 趋势图 + 告警状态
    ├── alarm_widget.py      # 告警记录 — 病虫害告警列表 + 过滤
    ├── control_widget.py    # 设备控制 — 灌溉/补光/喷雾/施肥 + 设备列表 + 操作日志
    ├── history_widget.py    # 历史数据 — 时间范围查询历史传感器数据
    └── stats_widget.py      # 统计分析 — 环形图（严重程度/作物/病害类型）
```

## 4. 启动流程

```
main.py::main()
  ├── QApplication(sys.argv)          # 创建 PyQt5 应用实例
  ├── app.setStyle("Fusion")          # 设置 Fusion 主题
  ├── app.setStyleSheet(...)          # 全局 QSS 样式表
  ├── MainWindow()
  │     ├── config.load()             # 加载 config.json
  │     ├── ApiClient(cfg)            # 初始化 API 客户端
  │     ├── _setup_ui()               # 构建左侧侧边栏 + 右侧 QStackedWidget 页面
  │     │     ├── 左侧侧边栏
  │     │     │     ├── 标题 Logo
  │     │     │     ├── 5 个导航按钮（QButtonGroup 互斥）
  │     │     │     ├── 设备选择下拉框（QComboBox）
  │     │     │     └── API 状态指示（圆点 + 文本）
  │     │     ├── 右侧工作区
  │     │     │     ├── 页眉标题
  │     │     │     └── QStackedWidget
  │     │     │           ├── DashboardWidget     # 实时监控
  │     │     │           ├── AlarmWidget         # 告警记录
  │     │     │           ├── ControlWidget       # 设备控制
  │     │     │           ├── HistoryWidget       # 历史数据
  │     │     │           └── StatsWidget         # 统计分析
  │     │     └── 信号连接
  │     │           └── control.device_selected → _select_device_in_combo
  │     ├── _setup_menu()             # 文件菜单（连接设置/关于）
  │     ├── 状态栏显示 API 地址
  │     ├── device_timer              # QTimer 每 15s 刷新设备列表
  │     └── _refresh_devices_combo()  # 初始加载设备下拉列表
  ├── w.show()                        # 显示主窗口
  └── app.exec_()                     # 进入 Qt 事件循环
```

SettingsDialog（连接设置对话框）：
- 弹出窗口编辑：VPS API 地址、API Key、默认设备 ID、刷新间隔
- 保存后自动重建 `ApiClient` 并重启 UI（`_restart()`）

## 5. 功能模块

### 5.1 核心层

| 文件 | 职责 |
|------|------|
| `config.py` | 从 `config.json` 加载/保存配置（server_url、API Key、device_id、刷新间隔）；提供 `api_base()` 辅助函数拼接 `/api/v1` 基础路径 |
| `api_client.py` | 封装 REST API 调用，自动附加 `X-Api-Key` 头，统一异常处理；提供 `_get`/`_post` 基础方法及 7 个业务接口方法 |

### 5.2 界面层

所有 widget 均实现 `set_device_filter(device_id)` 方法以支持全局设备筛选联动。

| Widget | 页面名称 | 功能 |
|--------|----------|------|
| `dashboard.py` | 实时监控 | 7 个传感器卡片（温/湿/光/CO₂/N/P/K，每卡片含 `SensorCard` 类）+ 温度/湿度趋势图（`MplCanvas` 类）+ 告警状态指示，QTimer 定时轮询；支持全部设备（均值聚合）与单设备两种模式 |
| `alarm_widget.py` | 告警记录 | 病虫害告警列表（8 列表格：时间、设备 ID、作物、病害类型、置信度、严重程度、风险等级、防治处置），支持严重程度筛选，颜色高亮 Badge |
| `control_widget.py` | 设备控制 | 4 个设备控制按钮（`DeviceBtn` 类：灌溉/补光/喷雾/施肥）+ 在线设备列表（双击可快速选取设备）+ 操作执行日志；发射 `device_selected` 信号实现跨组件联动 |
| `history_widget.py` | 历史数据 | 时间范围查询历史传感器数据，10 列表格展示（采集时间、温度、湿度、光照、CO₂、N、P、K、监测距离、告警标志），需选择具体设备后才可查询 |
| `stats_widget.py` | 统计分析 | 3 个环形图（`MplCanvas` 类，严重程度/作物/病害类型）+ 统计摘要文本；单设备模式下前端聚合计算统计数据 |

## 6. 后端 API 映射

所有请求基于 `{server_url}/api/v1`：

| 端点 | 方法 | 用途 | 调用方 |
|------|------|------|--------|
| `/sensor/latest` | GET | 最新传感器数据 | DashboardWidget |
| `/sensor/history` | GET | 历史传感器数据 | HistoryWidget |
| `/disease/list` | GET | 病虫害告警列表 | AlarmWidget / StatsWidget |
| `/disease/stats` | GET | 告警统计数据 | StatsWidget |
| `/device/list` | GET | 设备列表及状态 | ControlWidget / MainWindow |
| `/command/send` | POST | 发送设备控制指令 | ControlWidget |
| `/command/logs` | GET | 指令执行日志 | ControlWidget |
| `/advisory` | GET | 防治建议数据 | 预留接口 |

## 7. 配置项

配置文件 `config.json`（通过菜单"连接设置"修改，运行后自动生成，默认值如下）：

```json
{
    "server_url": "http://152.42.170.165",
    "server_api_key": "farmeye_prod_key_001",
    "refresh_interval": 3000,
    "device_id": "farmeye_guard_ws63"
}
```

## 8. 数据流

```
用户操作/定时器
    │
    ▼
Widget (View)
    │ 调用 API 方法
    ▼
ApiClient (Model)
    │ HTTP GET/POST
    ▼
VPS 后端服务
    │ JSON 响应
    ▼
ApiClient → 返回 dict
    │
    ▼
Widget 更新 UI / matplotlib 渲染
```

## 9. 架构特点

- **轻量分层**：核心层（api_client + config）与表现层（widgets）分离
- **定时轮询**：通过 `QTimer` 按可配置间隔自动刷新实时数据和告警；独立的 device_timer 每 15s 刷新设备列表
- **侧边栏导航**：左侧固定侧边栏 + 右侧 QStackedWidget 页面容器，通过 QButtonGroup 互斥导航
- **多设备联动**：全局设备选择下拉框通过 `set_device_filter()` 广播至各 widget，控制面板双击设备行亦可反向切换全局设备
- **信号槽驱动**：按钮点击、下拉切换、定时器超时、设备行双击、跨组件通信均通过 PyQt5 信号槽机制处理
- **cleanup 生命周期**：`MainWindow._restart()` 时调用各 widget 的 `cleanup()` 停止定时器，防止内存泄漏；设置变更后重建 `ApiClient` 并重启 UI
- **无 DI 容器**：组件间手动传递依赖，无 IoC 框架

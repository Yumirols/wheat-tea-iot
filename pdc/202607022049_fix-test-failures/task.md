# 任务：修复 FarmEye Guard 测试失败问题

## 问题1：ORM DDL 生成 Bug（数据库集成测试 38 ERROR at setup）

共 **3 个模型文件、9 处字段定义** 需修改：

### sensor.py
- `server\app\models\sensor.py:8`：在 `from sqlalchemy import` 行追加 `text`
- `server\app\models\sensor.py:21`：`server_default="CURRENT_TIMESTAMP"` → `server_default=text("CURRENT_TIMESTAMP")`
- `server\app\models\sensor.py:36`：同上
- `server\app\models\sensor.py:74`：同上

### disease.py
- `server\app\models\disease.py:6`：在 `from sqlalchemy import` 行追加 `text`
- `server\app\models\disease.py:18`：`server_default="CURRENT_TIMESTAMP"` → `server_default=text("CURRENT_TIMESTAMP")`
- `server\app\models\disease.py:35`：同上

### control.py
- `server\app\models\control.py:8`：在 `from sqlalchemy import` 行追加 `text`
- `server\app\models\control.py:21`：`server_default="CURRENT_TIMESTAMP"` → `server_default=text("CURRENT_TIMESTAMP")`
- `server\app\models\control.py:29`：同上
- `server\app\models\control.py:42`：同上
- `server\app\models\control.py:46`：同上

## 问题2：设备注册业务逻辑缺陷（E2E 步骤6-7 FAIL）

修改 `server\app\services\sensor_service.py` 中的 `ensure_device_exists()` 函数：

1. `sensor_service.py:68`：更新 docstring 中 `online=False` → `online=True`
2. `sensor_service.py:78`：`online=False` → `online=True`（新建设备分支）
3. `sensor_service.py:85-88`（else 分支）：在 `device.last_seen = datetime.utcnow()` 后增加 `device.online = True`

## 验收标准

1. 模型文件修改后，SQLAlchemy 生成的 DDL 中 `DEFAULT` 子句不再带单引号
2. 设备上报数据时 `online` 状态被正确设为 `True`
3. 集成测试和 E2E 测试可通过（待后续运行验证）

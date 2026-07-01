# 计划审查报告（v7 r1）

## 审查结果
APPROVED

## 发现

### **[轻微]** Schema 定义位置存在歧义

计划要求从 `schemas/__init__.py` 导出 AdvisoryResponse、ImageUploadResponse 等 Schema，但任务描述允许在 API 文件中就地定义。若在 API 文件（如 advisory.py、image.py）中定义 Schema，再被 `schemas/__init__.py` 导入会形成 schemas→api 的依赖方向，与现有约定（`schemas/device.py`→`schemas/__init__.py` 的独立文件模式）不一致。建议明确遵循代码库既有约定：在 `schemas/` 下新建独立文件（如 `schemas/advisory.py`、`schemas/image.py`）定义新 Schema，再从 `__init__.py` 导出。该问题不影响计划可行性，但值得在实现前明确方向。

### **[轻微]** data_retention.py 范围描述可更精确

计划将 data_retention.py 描述为"APScheduler 定时任务，每日凌晨执行数据保留清理"，但任务详情明确说明"当前仅实现函数逻辑，定时注册在后续 Docker/启动脚本子任务中完成"。该描述可能使实现者误以为需要在本轮完成 APScheduler 集成。建议在计划中将 data_retention.py 的范围描述为"数据保留清理函数实现"，明确区分函数逻辑与定时注册两个阶段。

### **[轻微]** image.py 安全约束可提及

计划对 image.py 的描述为"图片上传/获取 API 端点"，未提及路径遍历安全防护（验证 image_id 不含 `../`、`..\\` 等字符）。该约束在任务详情中有明确定义，但计划层面未反映。不影响计划执行，实现者会按任务详情实施。

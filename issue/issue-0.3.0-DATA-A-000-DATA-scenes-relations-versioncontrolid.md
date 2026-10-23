# analysis/semantic: 识别场景、脚本与动态推断关系

- ID：`0.3.0-DATA-A-000`。
- 类型：`DATA`。
- 状态：进行中（原文同时包含已完成与未完成项）。
- 版本管理标识：`versioncontrolid`（含义待定义，不推断为 commit、branch 或 change）。
- 来源：`REQUIREMENTS.md` @ `31c903505959733c2a653d1297e6d4f684f303e5`；标题路径：任务清单 / Phase - v0.3.0 - 项目语义分析 / analysis/semantic: 识别场景、脚本与动态推断关系。
- 原稳定 ID：`0.3.0-DATA-A-000`, `0.3.0-DATA-A-001`, `0.3.0-DATA-A-002`, `0.3.0-DATA-A-003`, `0.3.0-DATA-A-004`, `0.3.0-DATA-A-005`, `0.3.0-DATA-A-006`, `0.3.0-DATA-A-007`；不改写或重编号这些既有 ID。

## 当前需求与范围

- [ ] \[0.3.0-DATA-A-000] 扩展项目语义图 #epic #P1
  - [ ] \[0.3.0-DATA-A-001] 解析 SceneNode 与 `contains` 关系
  - [ ] \[0.3.0-DATA-A-002] 解析场景实例化与继承关系
  - [ ] \[0.3.0-DATA-A-003] 解析 GDScript class、extends、load 与 instantiate
  - [ ] \[0.3.0-DATA-A-004] 以可选 Analyzer 解析 C# class、inheritance 与动态创建
  - [ ] \[0.3.0-DATA-A-005] 所有推断关系记录来源与可信度
  - [ ] \[0.3.0-DATA-A-006] 支持人工 Feature、System 与 Concept metadata
  - [x] \[0.3.0-DATA-A-007] 静态解析 GDScript `class_name` 与 `extends` 并输出精确继承边

## 检查与验收边界

以上勾选与结果沿用迁移前的当前需求文档；历史记录中的实现、测试、编译、视觉与用户验收彼此独立。本次只迁移文档并检查结构 / 引用，没有重新执行产品构建或用户验收，也没有凭历史日志新增完成勾选。

## Comments

### 2026-10-23 17:44:33 UTC — Agent（文档迁移）

按原有功能 / 工作目标标题拆分需求，保留原 ID、勾选、依赖、最新补充及来源。没有稳定根 ID或旧 ID 在不同上下文重用时，采用由来源路径和标题确定的迁移 Issue ID，原 ID 仍在正文保留。完整旧内容可从来源版本读取；独有未提交内容的版本化副本见迁移映射。

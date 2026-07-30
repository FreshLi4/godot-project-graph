# 任务清单

## Phase - v0.1.0 - 可安装的基础资产图谱

### agent/phase-1-addon: 扫描并浏览 Godot 静态资产关系

- [x] \[0.1.0-TOOL-A-000] 提供可直接安装的原生 GDScript addon #epic #P0
  - [x] \[0.1.0-TOOL-A-001] 提供有效的 `plugin.cfg` 与 `EditorPlugin` 入口
  - [x] \[0.1.0-TOOL-A-002] 在 Godot 主工作区注册 Project Graph 页面
  - [x] \[0.1.0-TOOL-A-003] 禁用插件时完整释放 UI 与信号连接
- [x] \[0.1.0-DATA-A-000] 建立版本化基础图数据 #epic #P0
  - [x] \[0.1.0-DATA-A-001] 扫描 `res://` 下受支持的静态资产
  - [x] \[0.1.0-DATA-A-002] 按 Scene、Script、Resource、Mesh、Texture、Audio、Shader、Data 分类
  - [x] \[0.1.0-DATA-A-003] 通过 Godot 依赖 API 建立精确的 `references` 边
  - [x] \[0.1.0-DATA-A-004] 为缺失依赖保留 missing 节点
  - [x] \[0.1.0-DATA-A-005] 定义并校验 JSON Schema v1
- [x] \[0.1.0-FE-A-000] 提供可用的基础图浏览流程 #epic #P0
  - [x] \[0.1.0-FE-A-001] 用户可以手动扫描或重新扫描项目
  - [x] \[0.1.0-FE-A-002] 用户可以在 `GraphEdit` 中查看全部基础节点与引用边
  - [x] \[0.1.0-FE-A-003] 用户可以按名称、路径或类型搜索
  - [x] \[0.1.0-FE-A-004] 用户可以双击节点打开对应场景、脚本或资源
  - [x] \[0.1.0-API-A-001] 用户可以把当前图谱导出为 JSON
- [x] \[0.1.0-QA-A-000] 验证 Phase 1 addon #epic #P0
  - [x] \[0.1.0-QA-A-001] fixture 测试覆盖节点分类、依赖边、Schema 与 JSON 往返
  - [x] \[0.1.0-QA-A-002] Godot headless editor 可以启用插件且无脚本错误
  - [x] \[0.1.0-QA-A-003] GitHub Actions 运行同等检查

### agent/phase-1-addon: 建立公开项目协作基础

- [x] \[0.1.0-DOC-A-000] 建立可维护的公开仓库基础 #epic #docs #P0
  - [x] \[0.1.0-DOC-A-001] 基于 App agent template 创建并定制根协作文档
  - [x] \[0.1.0-DOC-A-002] README 说明用途、安装、验证与已知边界
  - [x] \[0.1.0-DOC-A-003] 架构与 Schema 文档记录稳定扩展点
  - [x] \[0.1.0-DOC-A-004] 每次实现任务写入 `agent-log/`

## Phase - v0.2.0 - 大型项目图谱体验

### graph/visualization: 提供可扩展的全项目图浏览

- [ ] \[0.2.0-FE-A-000] 改进大型项目图谱体验 #epic #P1
  - [ ] \[0.2.0-FE-A-001] 增加节点类型与边类型筛选器
  - [ ] \[0.2.0-FE-A-002] 增加文件夹分组、折叠与 `located_in` 关系
  - [ ] \[0.2.0-FE-A-003] 增加全局、局部和反向依赖视图
  - [ ] \[0.2.0-FE-A-004] 增加可替换布局策略和大图性能基准
  - [ ] \[0.2.0-FE-A-005] 显示 broken references 与疑似 unused assets

## Phase - v0.3.0 - 项目语义分析

### analysis/semantic: 识别场景、脚本与动态推断关系

- [ ] \[0.3.0-DATA-A-000] 扩展项目语义图 #epic #P1
  - [ ] \[0.3.0-DATA-A-001] 解析 SceneNode 与 `contains` 关系
  - [ ] \[0.3.0-DATA-A-002] 解析场景实例化与继承关系
  - [ ] \[0.3.0-DATA-A-003] 解析 GDScript class、extends、load 与 instantiate
  - [ ] \[0.3.0-DATA-A-004] 以可选 Analyzer 解析 C# class、inheritance 与动态创建
  - [ ] \[0.3.0-DATA-A-005] 所有推断关系记录来源与可信度
  - [ ] \[0.3.0-DATA-A-006] 支持人工 Feature、System 与 Concept metadata

## Phase - v0.4.0 - AI 上下文与公开分发

### release/distribution: 输出可复用知识并发布插件

- [ ] \[0.4.0-API-A-000] 增加知识图谱消费接口 #epic #P2
  - [ ] \[0.4.0-API-A-001] 导出面向 Codex 与 ChatGPT 的 Markdown 上下文
  - [ ] \[0.4.0-API-A-002] 评估可选 Web Viewer 与双向编辑器桥接
  - [ ] \[0.4.0-API-A-003] 评估可选运行时采集并隔离隐私数据
- [ ] \[0.4.0-CI-A-000] 建立公开发布流程 #epic #P1
  - [ ] \[0.4.0-CI-A-001] 生成仅包含 addon 的版本 ZIP
  - [ ] \[0.4.0-CI-A-002] 建立版本兼容矩阵与变更日志
  - [ ] \[0.4.0-CI-A-003] 准备 Godot Asset Library 发布材料

# FreshLi4 Project Graph

> A native GDScript project knowledge graph addon for Godot 4.

FreshLi4 Project Graph scans a Godot project without instantiating scenes or executing project scripts. It turns resource dependencies into a typed graph that can be searched, opened in the editor, and exported as versioned JSON.

## 当前状态

- 阶段：公开 MVP
- 版本：`v0.1.0`
- Phase 1 已完成：可安装的编辑器 addon，支持静态资产扫描、类型化图谱浏览、搜索与 JSON 导出。

## 关键能力

- 项目级静态资产扫描：扫描 Scene、Script、Resource、Mesh、Texture、Audio、Shader、Data 八类资产。
- 原生 GraphEdit 浏览：在 Godot 编辑器内搜索、导航、双击打开资产。
- JSON Schema v1 导出：可版本化的结构化图谱数据，供外部工具消费。
- 有机力导向布局：高连接度节点靠近中心，连通节点填充圆盘，独立节点位于最外层。
- 扫描 Ignore：默认排除 addons 和 Godot 生成目录，并支持持久化项目级规则。

## 快速开始

复制到你的 Godot 项目中：

```text
addons/freshli4_project_graph/
```

在 **Project > Project Settings > Plugins** 中启用 **FreshLi4 Project Graph**，工作区会出现 **Project Graph** 按钮。

## 使用

打开 **Project Graph** 并点击 **Scan Project**。连接最多的资产会成为中心锚点，其他连通资产通过确定性的固定步数力模拟填充圆盘内部，零连接资产则放在连通团簇之外。手动拖动节点后，可以点击 **Organic Layout** 恢复布局。

点击 **Ignore…** 可以添加项目相对路径或通配模式，每行一条：

```text
res://third_party/**
res://generated/*.tres
```

扫描器始终排除 `res://addons/`、`res://.godot/` 和 `res://.import/`，也不会扫描 `res://` 之外的引擎资源。自定义规则保存在 `user://freshli4_project_graph/settings.cfg`，不会修改被扫描项目。

## 开发

把本仓库作为 Godot 项目打开：

```bash
# 启动编辑器
"${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" --editor --path .

# 运行测试
"${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" --headless --path . --script tests/test_runner.gd

# 插件 smoke
"${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" --headless --editor --path . --quit-after 120 -- --project-graph-smoke
```

## 进一步了解

- [`AGENTS.md`](AGENTS.md)：协作规范
- [`REQUIREMENTS.md`](REQUIREMENTS.md)：需求追踪
- [`DESIGN.md`](DESIGN.md)：视觉规范
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)：架构与数据边界
- [`docs/SCHEMA.md`](docs/SCHEMA.md)：图数据 Schema
- `agent-log/`：执行日志

## 边界与限制

- Phase 1 不包含 C# 或 GDScript 完整调用图。
- 静态资源关系以 Godot `ResourceLoader` 报告的信息为准。
- 扫描器不实例化用户场景，也不执行用户脚本。
- Ignore 规则在目录遍历和依赖收集前生效。
- Addon 不依赖 .NET、Node.js、Tauri、浏览器或数据库。
- 导出默认写入 `user://freshli4_project_graph/`。

## License

[MIT](LICENSE)

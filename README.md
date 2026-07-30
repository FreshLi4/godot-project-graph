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

## 快速开始

复制到你的 Godot 项目中：

```text
addons/freshli4_project_graph/
```

在 **Project > Project Settings > Plugins** 中启用 **FreshLi4 Project Graph**，工作区会出现 **Project Graph** 按钮。

开发命令：

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
- 扫描器不实例化用户场景。
- Addon 不依赖 .NET、Node.js、浏览器或数据库。
- 导出默认写入 `user://freshli4_project_graph/`。

## License

[MIT](LICENSE)

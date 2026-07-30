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
- 关系感知有机布局：直接关联和共享邻居的资产就近聚类，高连接度节点靠近中心，并显式减少可避免的连线交叉。
- 语义化有向边：静态引用为灰色实线箭头，继承为青色实线箭头，推断/动态关系为琥珀色虚线箭头。
- 节点避障连线：语义边在渲染时绕过第三方资产卡片，不会再被节点正文遮住。
- GDScript 继承：静态解析 `class_name` 与 `extends`，子类指向父类，并把更高层父类拉向圆心。
- 固定尺寸卡片：不显示冗长资源路径，完整文件名在固定宽度内自动换行。
- 原生导航交互：空白画布按住左键拖拽平移，节点按住拖拽移动，右键可在 Godot FileSystem Dock 中定位文件。
- 扫描 Ignore：默认排除 addons 和 Godot 生成目录，并支持持久化项目级规则。

## 快速开始

复制到你的 Godot 项目中：

```text
addons/freshli4_project_graph/
```

在 **Project > Project Settings > Plugins** 中启用 **FreshLi4 Project Graph**，工作区会出现 **Project Graph** 按钮。

## 使用

打开 **Project Graph** 并点击 **Scan Project**。连接最多的资产会成为中心锚点，直接关联资产使用更短的目标边长，共享邻居形成较紧的局部关系簇。固定步数力模拟结束后，布局会在相近半径内交换节点位置，减少直线边交叉，同时不破坏卡片净空和中心层级。零连接资产仍位于连通团簇之外。手动拖动节点后，可以点击 **Organic Layout** 恢复布局。

工具栏状态会显示 `优化前→优化后 crossings`。任意非平面图都不可能保证零交叉，但该数字可以直接说明本次确定性布局消除了多少可避免交叉。渲染器还会对每条边执行矩形障碍可见性路由；即使边与边仍有不可避免的交叉，边也不会穿过无关节点卡片。

点击 **Legend…** 可以随时查看颜色和线型语义。蓝色只表示 Scene 资产，不表示引用方向；方向统一由箭头表达。继承关系固定从子类指向父类，父类祖先层级越高，布局中心权重越大。卡片只显示类型和完整文件名，超长文件名按字符换行，资源路径仍保留在搜索和内部导航数据中。

在画布空白处按住鼠标左键拖拽即可平移视图；在节点上按住拖拽可手动调整位置。双击节点打开资产，右键选择 **Show in FileSystem** 可调用 Godot 原生 FileSystem Dock 定位对应文件。

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

- 当前不包含 C# 继承或 GDScript 完整调用图，只静态解析 GDScript `class_name` / `extends`。
- 静态资源关系以 Godot `ResourceLoader` 报告的信息为准。
- 当前扫描不会主动产生运行时 `creates` 边；当后续分析器输出 inferred/dynamic 边时，渲染器已固定使用琥珀色虚线。
- 节点避障是硬约束；边与边的零交叉不对任意非平面图作保证。
- 扫描器不实例化用户场景，也不执行用户脚本。
- Ignore 规则在目录遍历和依赖收集前生效。
- Addon 不依赖 .NET、Node.js、Tauri、浏览器或数据库。
- 导出默认写入 `user://freshli4_project_graph/`。

## License

[MIT](LICENSE)

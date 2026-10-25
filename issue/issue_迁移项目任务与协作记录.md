---
title: 迁移项目任务与协作记录
id: DOC-migration-20261023
type: DOC
status: 文档迁移已完成；产品验证与用户验收未在本轮重做。
版本管理: Git。
updated-time: '2026-10-24T16:22:34+00:00'
---

# Description

## 本轮范围

按功能 / 工作目标拆分 1 份需求文档为 5 个 Issue；8 份文本日志按原需求 ID 和工作目标归入历史 Comments。无法可靠归属的记录保留在本 Issue，不创建虚构业务任务。
旧路径、哈希、Git 基准与 0 份独有来源副本见 [迁移映射](migration-map.json)。旧工作文件移除后，仅 `issue/` 承担需求与执行记录；不改应用代码或执行产品验收。

## 实现与检查

- [x] 需求与有效历史迁入 Issue，并保留旧稳定 ID、勾选、依赖和当前修订。
- [x] 删除旧活动需求 / 日志文件前，确认历史或独有来源副本可追溯。
- [x] Issue 结构、来源映射、相关引用与限定 diff 检查通过。

# Comments

## 20261023-174433_Agent

原记录标题：2026-10-23 17:44:33 UTC — Agent

用户已明确授权实际迁移、处理相关冲突和本地提交。本轮不 push、不新建 branch / worktree；不把未重新执行的测试、GUI 或用户验收标成通过。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 历史记录-时间未记录

原记录标题：20260730-171412-utcp8-taobe-gpt-5.md — 历史证据迁移

来源：`agent-log/20260730-171412-utcp8-taobe-gpt-5.md` @ `31c903505959733c2a653d1297e6d4f684f303e5`。日期 / 时区沿用原记录；以下摘录不自动改变当前完成状态。

#### 完成工作

- main 现在完整包含 Phase 1 addon、Organic Layout、扫描 Ignore、自动居中与最新版测试。
- main 的 addon 与 `origin/graph/visualization` 对应 addon/test 文件比较为零差异。
- `.godot` 编辑器布局、导入缓存和 UID 缓存不再被 main 跟踪；`.gitignore` 继续排除 `.godot/`。
- `AGENTS.md` 明确 main 是唯一可分发基准，已交付功能不得只存在于 feature branch 或旁路副本。
- README 使用说明、DESIGN 有机布局规范、REQUIREMENTS 状态、ARCHITECTURE 与 CHANGELOG 已共同进入 main。

#### 更新的需求 ID

- 保留并合入 `0.2.0-FE-A-006` 至 `0.2.0-FE-A-018` 的完整历史与完成状态。
- 本次是分支与发布基准修复，没有新增或重编号需求。

#### 验证方式

- GitHub CLI 认证：`github.com` 账号 `DDonlien` 可用。
- Godot 4.7 core：`PASS: Project Graph core (4 nodes, 3 edges)`。
- Godot 4.7 main editor smoke：`PASS: Project Graph editor panel smoke (6 graph nodes)`。
- Godot 4.7 隔离安装 smoke：只复制 `addons/` 与 fixture 到全新临时项目，`PASS: Project Graph editor panel smoke (4 graph nodes)`。
- 确认 main 中存在 `organic_graph_layout.gd`、`scan_ignore_settings.gd`，面板引用 `Organic Layout` 与 `Ignore…`。
- `git diff --cached --check`：通过。

#### 备注

- 本次按用户明确要求直接修复并推送 main，不创建 feature branch 或 Draft PR。
- `.godot` 缓存的错误提交仍保留在 Git 父历史中以避免 force-push，但 main 最终文件树不包含这些缓存。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 历史记录-时间未记录

原记录标题：20260730-090303-utcp8-taobe-gpt-5.md — 历史证据迁移

来源：`agent-log/20260730-090303-utcp8-taobe-gpt-5.md` @ `31c903505959733c2a653d1297e6d4f684f303e5`。日期 / 时区沿用原记录；以下摘录不自动改变当前完成状态。

#### 研究结论

- Obsidian 核心实现没有开源；官方只公开 center、repel、link 与 link-distance 等力参数，不能把其视觉结果描述为可直接复制的开源算法。
- 用户观察到的“黏菌”形态属于力导向图的平衡状态，不是同心圆或普通 radial layout。
- D3 Force 的确定性黄金角螺旋适合建立填充圆盘的初始分布。
- ForceAtlas2 的线性连线吸引、按连接度加权的排斥、重力、防重叠与 Barnes–Hut 近似构成适合纯 GDScript 的数学基础。
- 用户明确要求独立节点在最外层，因此零连接节点采用单独的外围布局；这是一条产品约束，不照搬 ForceAtlas2 对所有分量施加重力的默认行为。

#### 完成工作

- 删除尚未提交的 `RadialGraphLayout`，新增独立 `OrganicGraphLayout`。
- 按连接度降序、资产 id 稳定排序；最高连接度节点固定在原点。
- 用黄金角螺旋建立确定性、中心优先且覆盖圆盘内部的初始位置。
- 用固定步数执行连线弹簧、按连接度加权排斥、中心重力、速度阻尼与冷却。
- 根据扩展后节点卡片总面积推导软圆盘边界，把长依赖链弯回圆盘内部。
- 180 个连通节点以内使用精确两两排斥；更大的图使用确定性 Barnes–Hut 四叉树近似。
- 最终按卡片矩形和留白执行碰撞松弛，避免节点相交。
- 零连接节点放到连通图完整卡片包围半径之外，并按稳定顺序分布在最外层。
- 编辑器按钮改为 `Organic Layout`，扫描完成后默认采用新布局并自动缩放、居中。
- 保留并继续验证同一分支上已完成的扫描 Ignore 功能。

#### 更新的需求 ID

- 将 `0.2.0-FE-A-006` 至 `0.2.0-FE-A-009` 标记为 `#cut`，保留用户否定的同心圆方案历史。
- 完成 `0.2.0-FE-A-013` 至 `0.2.0-FE-A-018`。
- `0.2.0-FE-A-004` 仍未完成；当前还没有多布局策略切换和正式跨规模性能基准。

#### 验证方式

- Godot 4.7 core：`PASS: Project Graph core (4 nodes, 3 edges)`。
- 52 节点合成图：验证最高连接度中心、至少四个径向占用带、卡片无重叠、独立节点最外置与完全确定性。
- 199 节点合成图：实际进入 Barnes–Hut 分支，验证全部节点有位置、圆盘占用、卡片无重叠和独立节点最外置。
- 将 52 节点布局临时渲染为 SVG/PNG 进行目视检查；发现并修正第一版长链形成过长触手的问题，预览脚本随后删除。
- Godot 4.7 仓库 editor smoke：`PASS: Project Graph editor panel smoke (6 graph nodes)`。
- Godot 4.7 隔离安装 smoke：`PASS: Project Graph editor panel smoke (4 graph nodes)`。

#### 备注

- 纯星形图的结构平衡仍可能自然形成“中心加外围叶节点”，这是连接关系本身的对称解；算法不通过伪造层级来强制每种拓扑拥有相同密度。
- 任意稠密图无法同时保证圆形、零边交叉与最短边；本次可自动验证的是确定性、圆盘内部占用、hub 中心性、节点防重叠和独立节点外置。
- 本地分支尚未 commit 或 push；Godot 4.4、4.5、4.6 兼容性由仓库 CI matrix 在后续发布 Draft PR 时验证。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 历史记录-时间未记录

原记录标题：20260730-012018-utcp8-taobe-gpt-5.md — 历史证据迁移

来源：`agent-log/20260730-012018-utcp8-taobe-gpt-5.md` @ `31c903505959733c2a653d1297e6d4f684f303e5`。日期 / 时区沿用原记录；以下摘录不自动改变当前完成状态。

#### 完成工作

- 新增独立 `RadialGraphLayout`：
  - 将引用边视为无向布局关系。
  - 按连通分量和连接度选择根。
  - 通过 BFS 图距离分配同心层级。
  - 通过生成树子树权重建立稳定分支顺序。
  - 按节点卡片外接圆与层内密度动态扩大半径。
  - 对 128 个同层节点验证圆环一致性与无卡片重叠。
- `ProjectGraphPanel` 默认使用同心圆布局，增加 `Radial Layout` 按钮并自动缩放、居中。
- 隐藏 Godot 内置 Arrange 按钮，避免用户再次得到纵向分层布局。
- 新增 `Ignore…` 对话框：
  - 默认排除 `res://addons/**`、`res://.godot/**` 与 `res://.import/**`。
  - 非 `res://` 的引擎资源维持原有边界，不进入扫描。
  - 支持项目相对路径、`*` / `?` 通配和 `/**` 目录前缀。
  - 自定义模式保存到 `user://freshli4_project_graph/settings.cfg`。
  - 在目录遍历与依赖解析阶段同时剪枝，避免依赖边把忽略节点重新带回图谱。

#### 更新的需求 ID

- 完成 `0.2.0-FE-A-006` 至 `0.2.0-FE-A-012`。
- `0.2.0-FE-A-004` 仍保留未完成；本次只提供默认同心圆策略，尚未完成多策略切换与正式大图性能基准。

#### 验证方式

- Godot 4.7 core：`PASS: Project Graph core (4 nodes, 3 edges)`。
- 覆盖最高连接度中心、确定性结果、128 节点圆环、卡片无重叠、精确 Ignore、目录剪枝、相对路径正规化、默认 addon 排除。
- Godot 4.7 仓库 editor smoke：`PASS: Project Graph editor panel smoke (6 graph nodes)`。
- Godot 4.7 隔离安装 smoke：`PASS: Project Graph editor panel smoke (4 graph nodes)`。
- `git diff --check`：通过。

#### 备注

- 任意稠密交叉引用不可能在二维圆形布局中保证零交叉；本次保证的是确定性圆形结构、节点卡片避碰和分支邻近顺序。
- 本地分支尚未 commit 或 push；Godot 4.4、4.5、4.6 CI 需要用户明确授权发布 Draft PR 后运行。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 历史记录-时间未记录

原记录标题：20260730-210612-utcp8-taobe-gpt-5.md — 历史证据迁移

来源：`agent-log/20260730-210612-utcp8-taobe-gpt-5.md` @ `31c903505959733c2a653d1297e6d4f684f303e5`。日期 / 时区沿用原记录；以下摘录不自动改变当前完成状态。

#### 匹配和新增需求

- `0.2.0-FE-A-019` 至 `0.2.0-FE-A-028`。
- `0.3.0-DATA-A-007`。
- `0.2.0-FE-A-019` 被用户后续明确要求的固定尺寸卡片取代，保留为 `#cut` 历史。

#### 完成工作

- 将卡片固定为 `320 × 190 px`，正文自动换行并在固定高度内纵向滚动。
- 节点碰撞净空提高到 `96 px`；editor smoke 使用真实 GraphNode 尺寸验证固定卡片和至少 `64 px` 可见净空。
- 用 `SemanticConnectionLayer` 取代没有逐边语义的 GraphEdit 默认连线：
  - 灰色实线箭头：精确静态引用，source → target。
  - 青色实线箭头：精确继承，child → parent。
  - 琥珀色虚线箭头：inferred / dynamic / runtime / creates。
- 增加 **Legend…**，逐项解释节点类型颜色、边颜色、箭头方向和实虚线含义；蓝色只表示 Scene。
- 静态读取 GDScript `class_name` 与 `extends`，不加载或执行用户脚本；输出精确 `inherits` 边并移除同一父脚本的低语义 `references` 重复边。
- 布局沿 child → parent 继承边累计祖先层级；更高父类优先于普通连接度靠近圆心。
- 标题正常状态省略，悬停或选中后切换为自动横向滚动；悬停时在鼠标旁显示完整名称 Popup。
- 增加继承 fixture、语义线型、继承方向、继承中心性、大图碰撞净空和 editor UI 结构断言。

#### 验证

- Godot 4.7 core：`PASS: Project Graph core (6 nodes, 4 edges)`。
- Godot 4.7 editor smoke：`PASS: Project Graph editor panel smoke (8 graph nodes)`。
- Godot 4.7 隔离安装 smoke：仅复制 addon 与 fixture 到临时项目，`PASS: Project Graph editor panel smoke (6 graph nodes)`。
- 隔离安装日志无 `SCRIPT ERROR`、`Parse Error` 或 `ERROR:`。
- `git diff --check`：通过。

#### 备注

- 当前扫描器不会主动推断完整运行时创建图；语义层已为后续 analyzer 输出的非 exact、runtime、dynamic 或 `creates` 关系固定虚线契约。
- arbitrary cross-reference 仍可能交叉，但固定卡片与净空保证节点不重叠且相邻节点之间可见连线。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 20261024-063010_Agent

原记录标题：2026-10-24 06:30:10 UTC — Agent（纠正迁移命名）

依据用户最新确认，保留源任务中文名称并采用 issue_任务描述[_实际版本编号].md，类型与旧 ID 留在 properties。此处关联的是本文件所述文档任务的实际提交，不作为业务代码实施提交。历史原文保持不变；本轮修正未暂存、未提交。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 20261024-162234_Codex

按用户最新手写模板迁移属性和正文结构，保留任务语义、来源、原始状态及历史内容；本次未重新执行业务验收。

原版本关联记录（照录来源，不将本次文档迁移提交当作业务实施提交）：
- 实施提交：`d3f97ec1b2023e74561f6bc802b727dfb30bb1c7`（本文件所述文档任务的实际提交；不代表业务功能实现）。

本次执行环境未提供具体模型标识，未补造 Model-Detail。

[本次文档迁移对话](codex://threads/01a157b3-610c-73b4-ae06-163c0f8490d3)

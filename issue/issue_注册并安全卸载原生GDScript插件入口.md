# 注册并安全卸载原生GDScript插件入口

- ID：`0.1.0-TOOL-A-000`。
- 类型：`TOOL`。
- 状态：已完成（仅沿用本任务原始勾选；本轮未重新执行产品验收）。
- 版本管理：Git。
- 实施提交：未核实（现有记录未提供可直接对应本任务的实际实施提交；来源快照、当前 HEAD 与文档迁移提交不代替任务实施版本）。
- 来源：`REQUIREMENTS.md` @ `883f6ed615912696634313d1fac60e9388357098`；标题路径：任务清单 / Phase - v0.1.0 - 可安装的基础资产图谱 / agent/phase-1-addon: 扫描并浏览 Godot 静态资产关系。
- 原稳定 ID：`0.1.0-TOOL-A-000`, `0.1.0-TOOL-A-001`, `0.1.0-TOOL-A-002`, `0.1.0-TOOL-A-003`, `0.1.0-DATA-A-000`, `0.1.0-DATA-A-001`, `0.1.0-DATA-A-002`, `0.1.0-DATA-A-003`, `0.1.0-DATA-A-004`, `0.1.0-DATA-A-005`, `0.1.0-FE-A-000`, `0.1.0-FE-A-001`, `0.1.0-FE-A-002`, `0.1.0-FE-A-003`, `0.1.0-FE-A-004`, `0.1.0-API-A-001`, `0.1.0-QA-A-000`, `0.1.0-QA-A-001`, `0.1.0-QA-A-002`, `0.1.0-QA-A-003`；不改写或重编号这些既有 ID。
- 来源汇总状态：已完成（沿用原需求记录；本轮未重新执行产品验收）。
- 原迁移记录 ID：`0.1.0-TOOL-A-000`。
- 本文件原任务 ID：`0.1.0-TOOL-A-000`、`0.1.0-QA-A-000`。
- 原需求标题：agent/phase-1-addon: 扫描并浏览 Godot 静态资产关系。
- 原迁移文件：`issue/issue-0.1.0-TOOL-A-000-TOOL-godot-assets-relations-versioncontrolid.md`（重命名前路径，仅用于历史追溯）。
- 同源任务：[扫描Godot静态资产依赖并输出版本化图数据](issue_%E6%89%AB%E6%8F%8FGodot%E9%9D%99%E6%80%81%E8%B5%84%E4%BA%A7%E4%BE%9D%E8%B5%96%E5%B9%B6%E8%BE%93%E5%87%BA%E7%89%88%E6%9C%AC%E5%8C%96%E5%9B%BE%E6%95%B0%E6%8D%AE.md)、[浏览搜索并打开资产关系图与导出JSON](issue_%E6%B5%8F%E8%A7%88%E6%90%9C%E7%B4%A2%E5%B9%B6%E6%89%93%E5%BC%80%E8%B5%84%E4%BA%A7%E5%85%B3%E7%B3%BB%E5%9B%BE%E4%B8%8E%E5%AF%BC%E5%87%BAJSON.md)。

## 当前需求与范围

- [x] \[0.1.0-TOOL-A-000] 提供可直接安装的原生 GDScript addon #epic #P0
  - [x] \[0.1.0-TOOL-A-001] 提供有效的 `plugin.cfg` 与 `EditorPlugin` 入口
  - [x] \[0.1.0-TOOL-A-002] 在 Godot 主工作区注册 `Project Graph` 页面
  - [x] \[0.1.0-TOOL-A-003] 禁用插件时完整释放 UI 与信号连接
- [x] \[0.1.0-QA-A-000] 验证 Phase 1 addon #epic #P0
  - [x] \[0.1.0-QA-A-001] fixture 测试覆盖节点分类、依赖边、Schema 与 JSON 往返
  - [x] \[0.1.0-QA-A-002] Godot headless editor 可以启用插件且无脚本错误
  - [x] \[0.1.0-QA-A-003] GitHub Actions 运行同等检查

## 检查与验收边界

以上勾选与结果沿用迁移前的当前需求文档；历史记录中的实现、测试、编译、视觉与用户验收彼此独立。本次只迁移文档并检查结构 / 引用，没有重新执行产品构建或用户验收，也没有凭历史日志新增完成勾选。

## Comments


### 2026-10-23 17:44:33 UTC — Agent（文档迁移）

按原有功能 / 工作目标标题拆分需求，保留原 ID、勾选、依赖、最新补充及来源。没有稳定根 ID或旧 ID 在不同上下文重用时，采用由来源路径和标题确定的迁移 Issue ID，原 ID 仍在正文保留。完整旧内容可从来源版本读取；独有未提交内容的版本化副本见迁移映射。

### 20260728-223057-utcp8-taobe-gpt-5.md — 历史证据迁移

来源：`agent-log/20260728-223057-utcp8-taobe-gpt-5.md` @ `883f6ed615912696634313d1fac60e9388357098`。日期 / 时区沿用原记录；以下摘录不自动改变当前完成状态。

#### 完成工作

- 可复制安装的 `addons/freshli4_project_graph/`。
- 不实例化场景、不执行用户脚本的静态资产扫描器。
- JSON Schema v1、确定性节点/边 ID、缺失依赖节点与 JSON 往返。
- 原生 Godot 主工作区、全局基础依赖图、搜索、重扫、导出与双击打开资产。
- 中英文公开 README、视觉规范、架构、Schema、贡献指南和变更日志。
- fixture 核心测试、隔离安装 editor smoke 和 GitHub Actions 三版本矩阵。

#### 更新的需求 ID

- 完成 `0.1.0-TOOL-A-*`。
- 完成 `0.1.0-DATA-A-*`。
- 完成 `0.1.0-FE-A-*` 与 `0.1.0-API-A-001`。
- 完成 `0.1.0-QA-A-*`。
- 完成 `0.1.0-DOC-A-*`。
- 建立 v0.2.0、v0.3.0、v0.4.0 后续 Phase。

#### 验证方式

- Godot 4.7 本地核心测试：`PASS: Project Graph Phase 1 (4 nodes, 3 edges)`。
- Godot 4.7 隔离安装 smoke：`PASS: Project Graph editor panel smoke (4 graph nodes)`。
- GitHub Actions run `30368620576`：
  - Godot 4.4.1：通过。
  - Godot 4.5.1：通过。
  - Godot 4.6.3：通过。
- `git diff --check`：通过。

#### 备注

- 当前 PR 保持 Draft，不合并 `main`。
- Phase 1 的 C# 支持限于脚本资产与 Godot 资源引用，不声明完整 Roslyn 语义分析。
- `actions/checkout@v4` 在 2026 GitHub runner 上产生 Node 20 弃用警告，但不影响检查结果；后续应在官方 action 发布兼容版本后升级。

### 2026-10-24 07:16:26 UTC — Agent（纠正迁移命名）

根据用户确认的原语言与下划线命名规则整理本记录；类型与原 ID 保留在 properties，原始勾选、取消／延后标记及验收边界照录。 本源文档按独立目标拆为 3 份，原始 Comments 完整留在本主记录。 未核实本任务实际实施提交，省略文件名版本后缀；未执行代码、构建或用户验收，未提交或推送。

---
uid: "00003"
title: Project Graph编辑器插件
id: 0.1.0-TOOL-A-000
type: TOOL
status: 已完成（仅沿用本任务原始勾选；本轮未重新执行产品验收）。
版本管理: Git。
来源: '`REQUIREMENTS.md` @ `31c903505959733c2a653d1297e6d4f684f303e5`；标题路径：任务清单 / Phase - v0.1.0 - 可安装的基础资产图谱 / agent/phase-1-addon: 扫描并浏览 Godot 静态资产关系。'
原稳定 ID: '`0.1.0-TOOL-A-000`, `0.1.0-TOOL-A-001`, `0.1.0-TOOL-A-002`, `0.1.0-TOOL-A-003`, `0.1.0-DATA-A-000`, `0.1.0-DATA-A-001`, `0.1.0-DATA-A-002`, `0.1.0-DATA-A-003`, `0.1.0-DATA-A-004`, `0.1.0-DATA-A-005`, `0.1.0-FE-A-000`, `0.1.0-FE-A-001`, `0.1.0-FE-A-002`, `0.1.0-FE-A-003`, `0.1.0-FE-A-004`, `0.1.0-API-A-001`, `0.1.0-QA-A-000`, `0.1.0-QA-A-001`, `0.1.0-QA-A-002`, `0.1.0-QA-A-003`；不改写或重编号这些既有 ID。'
来源汇总状态: 已完成（沿用原需求记录；本轮未重新执行产品验收）。
原迁移记录 ID: '`0.1.0-TOOL-A-000`。'
本文件原任务 ID: '`0.1.0-TOOL-A-000`、`0.1.0-QA-A-000`。'
原需求标题: 'agent/phase-1-addon: 扫描并浏览 Godot 静态资产关系。'
原迁移文件: '`issue/issue-0.1.0-TOOL-A-000-TOOL-godot-assets-relations-versioncontrolid.md`（重命名前路径，仅用于历史追溯）。'
同源任务: '[扫描Godot静态资产依赖并输出版本化图数据](issue_%E6%89%AB%E6%8F%8FGodot%E9%9D%99%E6%80%81%E8%B5%84%E4%BA%A7%E4%BE%9D%E8%B5%96%E5%B9%B6%E8%BE%93%E5%87%BA%E7%89%88%E6%9C%AC%E5%8C%96%E5%9B%BE%E6%95%B0%E6%8D%AE.md)、[浏览搜索并打开资产关系图与导出JSON](issue_%E6%B5%8F%E8%A7%88%E6%90%9C%E7%B4%A2%E5%B9%B6%E6%89%93%E5%BC%80%E8%B5%84%E4%BA%A7%E5%85%B3%E7%B3%BB%E5%9B%BE%E4%B8%8E%E5%AF%BC%E5%87%BAJSON.md)。'
updated-by: Codex/godot_project_graph
updated-time: '2026-10-29T20:48:51+08:00'
---

# Description

## 当前需求与范围

- [x] \[0.1.0-TOOL-A-000] 提供可直接安装的原生 C# addon #epic #P0
  - [x] \[0.1.0-TOOL-A-001] 提供有效的 `plugin.cfg` 与 `EditorPlugin` 入口
  - [x] \[0.1.0-TOOL-A-002] 在 Godot 主工作区注册 Project Graph 页面
  - [x] \[0.1.0-TOOL-A-003] 禁用插件时完整释放 UI 与信号连接
- [x] \[0.1.0-QA-A-000] 验证 Phase 1 addon #epic #P0
  - [x] \[0.1.0-QA-A-001] fixture 测试覆盖节点分类、依赖边、Schema 与 JSON 往返
  - [x] \[0.1.0-QA-A-002] Godot headless editor 可以启用插件且无脚本错误
  - [ ] \[0.1.0-QA-A-003] GitHub Actions 运行本次 .NET 检查；工作流已更新，等待实际结果

## 检查与验收边界

原功能与稳定 ID 保留。本次 C# 迁移已完成 Debug / ExportRelease 编译、51 项核心断言及主工程与独立复制安装的 headless 编辑器检查；GitHub CI 尚未取得本次结果，图形、真实编辑器操作与用户验收仍待完成。历史记录中的实现、检查与验收结果不改写。


## 本次 C# 实现

插件入口、扫描器、Ignore与JSON存储、确定性布局、面板和语义连线均迁为 C#，保留原脚本 UID。新增 .NET 8 工程，默认 Godot 4.7 .NET；AGENTS 明确除非用户特别要求，否则自有运行、编辑器、导入与测试都使用 C#。安装说明与CI相应更新，旧“纯 GDScript、不依赖 .NET”要求已移除。tests/fixtures 的3份 .gd 只是被解析而不执行的语法数据，保留以覆盖GDScript解析；所有实际测试逻辑在 C# 场景入口。原Issue ID与完整Comments保留，补充仓库唯一UID00003，并将原标题/文件改为当前交付物名称。

实现与编译、无窗口结构检查分别记录；画面、真实编辑器操作和用户验收仍待完成。用户现已授权将本次 C# 迁移、直接相关文档与规范提交并推送；提交与推送结果在实际执行后核实。本次不发版，仓库未绑定飞书任务表，不写入外部 tracker。

# Comments

## 20261023-174433_Agent

原记录标题：2026-10-23 17:44:33 UTC — Agent（文档迁移）

按原有功能 / 工作目标标题拆分需求，保留原 ID、勾选、依赖、最新补充及来源。没有稳定根 ID或旧 ID 在不同上下文重用时，采用由来源路径和标题确定的迁移 Issue ID，原 ID 仍在正文保留。完整旧内容可从来源版本读取；独有未提交内容的版本化副本见迁移映射。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 20261024-071626_Agent

原记录标题：2026-10-24 07:16:26 UTC — Agent（纠正迁移命名）

根据用户确认的原语言与下划线命名规则整理本记录；类型与原 ID 保留在 properties，原始勾选、取消／延后标记及验收边界照录。 本源文档按独立目标拆为 3 份，原始 Comments 完整留在本主记录。 未核实本任务实际实施提交，省略文件名版本后缀；未执行代码、构建或用户验收，未提交或推送。

原记录未提供完整 Agent / 模型详情及原执行会话链接，未补造。

## 20261024-162234_Codex

按用户最新手写模板迁移属性和正文结构，保留任务语义、来源、原始状态及历史内容；本次未重新执行业务验收。

原版本关联记录（照录来源，不将本次文档迁移提交当作业务实施提交）：
- 实施提交：未核实（现有记录未提供可直接对应本任务的实际实施提交；来源快照、当前 HEAD 与文档迁移提交不代替任务实施版本）。

本次执行环境未提供具体模型标识，未补造 Model-Detail。

[本次文档迁移对话](codex://threads/01a157b3-610c-73b4-ae06-163c0f8490d3)


## 20261029-201124_Codex-GodotProjectGraph_GPT-UNKNOWN-UNKNOWN-UNKNOWN-UNKNOWN

插件入口、扫描器、Ignore与JSON存储、确定性布局、面板和语义连线均迁为 C#，保留原脚本 UID。新增 .NET 8 工程，默认 Godot 4.7 .NET；AGENTS 明确除非用户特别要求，否则自有运行、编辑器、导入与测试都使用 C#。安装说明与CI相应更新，旧“纯 GDScript、不依赖 .NET”要求已移除。tests/fixtures 的3份 .gd 只是被解析而不执行的语法数据，保留以覆盖GDScript解析；所有实际测试逻辑在 C# 场景入口。原Issue ID与完整Comments保留，补充仓库唯一UID00003，并将原标题/文件改为当前交付物名称。

Debug及ExportRelease的C#编译均0警告0错误。迁移后的51项核心断言通过，覆盖7节点/4边夹具、199节点Barnes–Hut、碰撞净空、绕障连线与JSON往返。主工程headless编辑器smoke通过，11节点、5/5线路、0阻挡。独立复制安装的检查结果在最终检查后补记；CI仅更新工作流，未实际在GitHub运行。未做GUI或视觉验收。

本次执行Agent为Codex/godot_project_graph；厂牌可核实为GPT，确切版本、规模、推理级别与加速选择无法核实，逐项写UNKNOWN。未生成业务提交，不拿当前HEAD作为迁移提交。

> [本次执行会话](codex://threads/01a18788-0b4b-7843-a1ff-ba7654d6fdaa)

## 20261029-201341_Codex-GodotProjectGraph_GPT-UNKNOWN-UNKNOWN-UNKNOWN-UNKNOWN

最终复制安装检查通过：从插件目录和现有夹具创建的独立 .NET 测试宿主中，C#编译、无窗口导入均退出0且无错误；编辑器smoke显示7节点、4/4线路、0阻挡。该检查使用复制目录自己的构建工作目录，CI同步采用相同方式。smoke结束现在显式退出并报告失败退出码，避免仅打印错误却退出0；编辑器关闭的帧数上限不再作为完成依据。模板/路径检查、原UID与Comments保留、活动Markdown引用检查通过。另有3份GDScript静态语法夹具，其内容未修改、也不作为测试执行脚本。

GitHub CI尚未触发，图形与真实操作未验收；未提交、推送或发布，未修改其他工作副本。确切模型版本、规模、推理级别、加速选择不可核实，均为UNKNOWN。

> [本次执行会话](codex://threads/01a18788-0b4b-7843-a1ff-ba7654d6fdaa)

## 20261029-204851_Codex-GodotProjectGraph_GPT-UNKNOWN-UNKNOWN-UNKNOWN-UNKNOWN

用户已明确授权按仓库分别提交并推送本次 C# 迁移及直接相关目录、文档、测试、CI、Issue 与 AGENTS 规范改动。重新读取当前规则和本任务记录，确认本工作副本为 main，upstream为origin/main，HEAD仍是迁移前基准，暂存区为空；当前56条变动路径均属于本次范围，未发现新增无关改动。不会改动旁边的agent/phase-1-addon工作副本、标签或历史。

此前完成的编译、51项断言和两种安装范围的headless检查结果仍适用于当前代码；本次只复核目标差异、路径与暂存范围，不虚称新增验收或GitHub CI结果。提交尚未生成，暂不填写hash；生成后的真实hash留待下一次实际Issue更新补入，不追加自引用提交。模型确切版本、规模、推理级别和加速选择不可核实，均为UNKNOWN。

> [本次执行会话](codex://threads/01a18788-0b4b-7843-a1ff-ba7654d6fdaa)

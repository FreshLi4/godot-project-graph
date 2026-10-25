# Issue 入口

本目录是当前工作副本的任务、检查与交接入口。旧需求的状态、ID 与来源保留在对应 Issue；历史 Comments 不自动更新当前完成度。Issue 使用 Obsidian YAML frontmatter 和 Description / Comments 两个一级标题；文件名仅为 issue_原语言任务描述.md。真实 Git / P4 编号写入对应 Comment，recorded-version 仅记录可选内容发布版本。

- [Issue 模板](issue_template.md)
- [本轮迁移记录](issue_%E8%BF%81%E7%A7%BB%E9%A1%B9%E7%9B%AE%E4%BB%BB%E5%8A%A1%E4%B8%8E%E5%8D%8F%E4%BD%9C%E8%AE%B0%E5%BD%95.md)
- [旧路径与来源映射](migration-map.json)

- [注册并安全卸载原生GDScript插件入口](issue_%E6%B3%A8%E5%86%8C%E5%B9%B6%E5%AE%89%E5%85%A8%E5%8D%B8%E8%BD%BD%E5%8E%9F%E7%94%9FGDScript%E6%8F%92%E4%BB%B6%E5%85%A5%E5%8F%A3.md)、[扫描Godot静态资产依赖并输出版本化图数据](issue_%E6%89%AB%E6%8F%8FGodot%E9%9D%99%E6%80%81%E8%B5%84%E4%BA%A7%E4%BE%9D%E8%B5%96%E5%B9%B6%E8%BE%93%E5%87%BA%E7%89%88%E6%9C%AC%E5%8C%96%E5%9B%BE%E6%95%B0%E6%8D%AE.md)、[浏览搜索并打开资产关系图与导出JSON](issue_%E6%B5%8F%E8%A7%88%E6%90%9C%E7%B4%A2%E5%B9%B6%E6%89%93%E5%BC%80%E8%B5%84%E4%BA%A7%E5%85%B3%E7%B3%BB%E5%9B%BE%E4%B8%8E%E5%AF%BC%E5%87%BAJSON.md) — `0.1.0-TOOL-A-000`；已完成（沿用原需求记录；本轮未重新执行产品验收）；原路径 `REQUIREMENTS.md`。

- [agent/phase-1-addon: 建立公开项目协作基础](issue_%E5%BB%BA%E7%AB%8B%E6%8F%92%E4%BB%B6%E5%AE%89%E8%A3%85%E5%8D%8F%E4%BD%9C%E4%B8%8E%E6%9E%B6%E6%9E%84Schema%E8%AF%B4%E6%98%8E.md) — `0.1.0-DOC-A-000`；已完成（沿用原需求记录；本轮未重新执行产品验收）；原路径 `REQUIREMENTS.md`。

- [在大型项目图筛选分组并浏览局部与反向依赖](issue_%E5%9C%A8%E5%A4%A7%E5%9E%8B%E9%A1%B9%E7%9B%AE%E5%9B%BE%E7%AD%9B%E9%80%89%E5%88%86%E7%BB%84%E5%B9%B6%E6%B5%8F%E8%A7%88%E5%B1%80%E9%83%A8%E4%B8%8E%E5%8F%8D%E5%90%91%E4%BE%9D%E8%B5%96.md)、[提供可替换图布局策略与大图性能基准](issue_%E6%8F%90%E4%BE%9B%E5%8F%AF%E6%9B%BF%E6%8D%A2%E5%9B%BE%E5%B8%83%E5%B1%80%E7%AD%96%E7%95%A5%E4%B8%8E%E5%A4%A7%E5%9B%BE%E6%80%A7%E8%83%BD%E5%9F%BA%E5%87%86.md) — `0.2.0-FE-A-000`；待处理（原文未完成项保持未勾选）；原路径 `REQUIREMENTS.md`。

- [解析Godot场景与GDScript关系并记录推断可信度](issue_%E8%A7%A3%E6%9E%90Godot%E5%9C%BA%E6%99%AF%E4%B8%8EGDScript%E5%85%B3%E7%B3%BB%E5%B9%B6%E8%AE%B0%E5%BD%95%E6%8E%A8%E6%96%AD%E5%8F%AF%E4%BF%A1%E5%BA%A6.md)、[通过可选分析器识别C#继承与动态创建](issue_%E9%80%9A%E8%BF%87%E5%8F%AF%E9%80%89%E5%88%86%E6%9E%90%E5%99%A8%E8%AF%86%E5%88%ABC%23%E7%BB%A7%E6%89%BF%E4%B8%8E%E5%8A%A8%E6%80%81%E5%88%9B%E5%BB%BA.md)、[为项目图添加人工Feature-System-Concept元数据](issue_%E4%B8%BA%E9%A1%B9%E7%9B%AE%E5%9B%BE%E6%B7%BB%E5%8A%A0%E4%BA%BA%E5%B7%A5Feature-System-Concept%E5%85%83%E6%95%B0%E6%8D%AE.md) — `0.3.0-DATA-A-000`；待处理（原文未完成项保持未勾选）；原路径 `REQUIREMENTS.md`。

- [导出供Codex与ChatGPT消费的项目图Markdown上下文](issue_%E5%AF%BC%E5%87%BA%E4%BE%9BCodex%E4%B8%8EChatGPT%E6%B6%88%E8%B4%B9%E7%9A%84%E9%A1%B9%E7%9B%AE%E5%9B%BEMarkdown%E4%B8%8A%E4%B8%8B%E6%96%87.md)、[评估Web-Viewer与双向编辑器桥接](issue_%E8%AF%84%E4%BC%B0Web-Viewer%E4%B8%8E%E5%8F%8C%E5%90%91%E7%BC%96%E8%BE%91%E5%99%A8%E6%A1%A5%E6%8E%A5.md)、[评估可选运行时采集并隔离隐私数据](issue_%E8%AF%84%E4%BC%B0%E5%8F%AF%E9%80%89%E8%BF%90%E8%A1%8C%E6%97%B6%E9%87%87%E9%9B%86%E5%B9%B6%E9%9A%94%E7%A6%BB%E9%9A%90%E7%A7%81%E6%95%B0%E6%8D%AE.md)、[打包Godot插件并准备Asset-Library发布材料](issue_%E6%89%93%E5%8C%85Godot%E6%8F%92%E4%BB%B6%E5%B9%B6%E5%87%86%E5%A4%87Asset-Library%E5%8F%91%E5%B8%83%E6%9D%90%E6%96%99.md) — `0.4.0-API-A-000`；待处理（原文未完成项保持未勾选）；原路径 `REQUIREMENTS.md`。

# Contributing

Thanks for helping improve FreshLi4 Project Graph.

Before changing code, read `AGENTS.md`, [Project Graph编辑器插件](issue/issue_Project-Graph%E7%BC%96%E8%BE%91%E5%99%A8%E6%8F%92%E4%BB%B6.md)、[扫描Godot静态资产依赖并输出版本化图数据](issue/issue_%E6%89%AB%E6%8F%8FGodot%E9%9D%99%E6%80%81%E8%B5%84%E4%BA%A7%E4%BE%9D%E8%B5%96%E5%B9%B6%E8%BE%93%E5%87%BA%E7%89%88%E6%9C%AC%E5%8C%96%E5%9B%BE%E6%95%B0%E6%8D%AE.md)、[浏览搜索并打开资产关系图与导出JSON](issue/issue_%E6%B5%8F%E8%A7%88%E6%90%9C%E7%B4%A2%E5%B9%B6%E6%89%93%E5%BC%80%E8%B5%84%E4%BA%A7%E5%85%B3%E7%B3%BB%E5%9B%BE%E4%B8%8E%E5%AF%BC%E5%87%BAJSON.md), and `docs/ARCHITECTURE.md`. Keep the scanner independent from editor UI, avoid executing scanned project code, and add fixture coverage for behavior changes.

Use Godot 4.7 .NET and the .NET 8 SDK. Build C# before running both checks:

```bash
dotnet build ProjectGraph.csproj
godot --headless --path . res://tests/test_runner.tscn
godot --headless --editor --path . --quit-after 600 -- --project-graph-smoke
```

Open pull requests as focused changes with a short explanation of user impact and verification evidence.

# FreshLi4 Project Graph

> A native GDScript project knowledge graph addon for Godot 4.

FreshLi4 Project Graph scans a Godot project without instantiating scenes or executing project scripts. It turns resource dependencies into a typed graph that can be searched, opened in the editor, and exported as versioned JSON.

它面向的不只是“某个资产引用了谁”，而是可逐步扩展为场景、脚本、资源、运行时推断和架构语义共用的项目知识图谱。

## Current status

Phase 1 (`v0.1.0`) provides an installable editor addon with:

- project-wide static asset scanning;
- typed asset and `references` edges;
- a native `GraphEdit` main screen;
- search, rescan, double-click navigation, and JSON export;
- headless scanner tests and editor-plugin smoke validation.

## Install

Copy this directory into your Godot project:

```text
addons/freshli4_project_graph/
```

Then open **Project > Project Settings > Plugins** and enable **FreshLi4 Project Graph**. A **Project Graph** button appears beside Godot's 2D, 3D, and Script workspaces.

## Develop

Open this repository itself as a Godot project:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --editor --path .
```

Run the scanner tests and plugin smoke:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --path . --script tests/test_runner.gd

/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --editor --path . --quit-after 120 -- --project-graph-smoke
```

The addon has no runtime dependency on .NET, Node.js, Tauri, a browser, or a database.
CI also copies only the addon and fixture assets into a fresh temporary Godot project before running the editor smoke.

## Design boundaries

- Static resource relationships are exact when reported by Godot's resource loader.
- Phase 1 does not claim a full C# or GDScript call graph.
- The addon never instantiates scanned scenes.
- Default exports go to `user://freshli4_project_graph/`.

See [architecture](docs/ARCHITECTURE.md), [graph schema](docs/SCHEMA.md), [注册并安全卸载原生GDScript插件入口](issue/issue_%E6%B3%A8%E5%86%8C%E5%B9%B6%E5%AE%89%E5%85%A8%E5%8D%B8%E8%BD%BD%E5%8E%9F%E7%94%9FGDScript%E6%8F%92%E4%BB%B6%E5%85%A5%E5%8F%A3.md)、[扫描Godot静态资产依赖并输出版本化图数据](issue/issue_%E6%89%AB%E6%8F%8FGodot%E9%9D%99%E6%80%81%E8%B5%84%E4%BA%A7%E4%BE%9D%E8%B5%96%E5%B9%B6%E8%BE%93%E5%87%BA%E7%89%88%E6%9C%AC%E5%8C%96%E5%9B%BE%E6%95%B0%E6%8D%AE.md)、[浏览搜索并打开资产关系图与导出JSON](issue/issue_%E6%B5%8F%E8%A7%88%E6%90%9C%E7%B4%A2%E5%B9%B6%E6%89%93%E5%BC%80%E8%B5%84%E4%BA%A7%E5%85%B3%E7%B3%BB%E5%9B%BE%E4%B8%8E%E5%AF%BC%E5%87%BAJSON.md), and [visual design](DESIGN.md).

## License

[MIT](LICENSE)

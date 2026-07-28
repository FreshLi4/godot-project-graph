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

See [architecture](docs/ARCHITECTURE.md), [graph schema](docs/SCHEMA.md), [requirements](REQUIREMENTS.md), and [visual design](DESIGN.md).

## License

[MIT](LICENSE)

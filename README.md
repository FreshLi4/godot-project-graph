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

The `graph/visualization` work adds:

- a deterministic organic force-directed layout that fills the disk interior;
- one-click organic re-layout and automatic view fitting;
- scan-time Ignore patterns, with addons and Godot-generated directories excluded by default.

## Install

Copy this directory into your Godot project:

```text
addons/freshli4_project_graph/
```

Then open **Project > Project Settings > Plugins** and enable **FreshLi4 Project Graph**. A **Project Graph** button appears beside Godot's 2D, 3D, and Script workspaces.

## Use

Open **Project Graph** and click **Scan Project**. The most connected asset anchors the center while connected assets settle through a deterministic, fixed-step force simulation that fills the disk interior. Degree-zero assets are placed outside the connected cluster. **Organic Layout** restores this layout after manual dragging.

Click **Ignore…** to add project-relative paths or wildcard patterns, one per line:

```text
res://third_party/**
res://generated/*.tres
```

The scanner always excludes `res://addons/`, `res://.godot/`, and `res://.import/`. Godot engine resources outside `res://` never enter the project scan. Custom patterns are stored in `user://freshli4_project_graph/settings.cfg`, so the addon does not modify the scanned project.

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
- Ignore rules are applied before traversal and dependency collection.
- Default exports go to `user://freshli4_project_graph/`.

See [architecture](docs/ARCHITECTURE.md), [graph schema](docs/SCHEMA.md), [requirements](REQUIREMENTS.md), and [visual design](DESIGN.md).

## License

[MIT](LICENSE)

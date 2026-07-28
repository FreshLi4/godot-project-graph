# Architecture

## Goals

Phase 1 establishes a native, installable Godot addon with a stable graph-data boundary. The scanner must not instantiate user scenes or execute user scripts.

```text
EditorPlugin
    |
    +-- ProjectGraphPanel (editor UI)
    |       |
    |       +-- GraphEdit
    |       +-- search / scan / export
    |
    +-- ProjectGraphScanner
            |
            +-- file enumeration
            +-- ResourceLoader dependencies
            +-- ProjectGraphSchema
            +-- ProjectGraphStore
```

## Module boundaries

- `plugin.gd` owns editor lifecycle and asset navigation.
- `ui/project_graph_panel.gd` owns user interaction and rendering, but not scanning rules.
- `core/project_graph_scanner.gd` produces a complete in-memory snapshot and has no editor UI dependency.
- `core/graph_schema.gd` constructs and validates versioned nodes, edges, statistics, and snapshots.
- `core/graph_store.gd` owns JSON persistence.

The UI consumes only a snapshot dictionary. Future renderers can replace `GraphEdit` without changing scanners or the JSON contract.

## Safety invariants

- Never instantiate a scanned `PackedScene`.
- Never attach, evaluate, or invoke scanned scripts.
- Never write into the scanned project's `res://` tree automatically.
- Exclude this addon's own implementation from scans.
- Preserve unresolved `res://` dependencies as missing nodes.
- Report inferred relationships separately from exact engine-reported dependencies.

## Phase boundaries

- `v0.1.0`: static asset graph, native viewer, navigation, search, JSON.
- `v0.2.0`: large-graph UX, grouping, reverse view, broken and unused reports.
- `v0.3.0`: scene composition and script semantic analyzers.
- `v0.4.0`: AI context, optional external viewer/runtime capture, public packaging.

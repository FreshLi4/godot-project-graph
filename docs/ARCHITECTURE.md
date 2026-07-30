# Architecture

## Goals

Phase 1 establishes a native, installable Godot addon with a stable graph-data boundary. The scanner must not instantiate user scenes or execute user scripts.

```text
EditorPlugin
    |
    +-- ProjectGraphPanel (editor UI)
    |       |
    |       +-- GraphEdit
    |       +-- search / scan / ignore / export
    |       +-- OrganicGraphLayout
    |
    +-- ProjectGraphScanner
            |
            +-- ignored-path pruning
            +-- file enumeration
            +-- ResourceLoader dependencies
            +-- ProjectGraphSchema
            +-- ProjectGraphStore
            +-- ScanIgnoreSettings
```

## Module boundaries

- `plugin.gd` owns editor lifecycle and asset navigation.
- `ui/project_graph_panel.gd` owns user interaction and rendering, but not scanning rules.
- `core/project_graph_scanner.gd` produces a complete in-memory snapshot and has no editor UI dependency.
- `core/organic_graph_layout.gd` converts a snapshot into deterministic, disk-filling force-directed positions without depending on `GraphEdit`.
- `core/scan_ignore_settings.gd` persists project-local custom patterns under `user://`; default exclusions remain scanner invariants.
- `core/graph_schema.gd` constructs and validates versioned nodes, edges, statistics, and snapshots.
- `core/graph_store.gd` owns JSON persistence.

The UI consumes only a snapshot dictionary. Future renderers can replace `GraphEdit` without changing scanners or the JSON contract.

## Safety invariants

- Never instantiate a scanned `PackedScene`.
- Never attach, evaluate, or invoke scanned scripts.
- Never write into the scanned project's `res://` tree automatically.
- Scan only `res://`; engine resources outside the project never become graph nodes.
- Exclude all `res://addons/` content and Godot-generated directories by default.
- Apply custom Ignore rules both during directory traversal and dependency collection.
- Preserve unresolved `res://` dependencies as missing nodes.
- Report inferred relationships separately from exact engine-reported dependencies.

## Organic force-directed disk layout

The layout is a deterministic, offline force simulation:

1. Build an undirected topology and sort connected nodes by degree, then stable asset id.
2. Seed connected nodes with a golden-angle phyllotaxis spiral. The highest-degree node starts at the origin, so the seed already fills a disk instead of a ring.
3. Run a fixed number of damped relaxation steps. Reference edges act as linear springs, all connected nodes repel one another, and degree-weighted gravity pulls structural hubs toward the center. A soft boundary derived from total expanded card area bends long branches back into the target disk.
4. Use exact pairwise repulsion for small graphs and a deterministic Barnes–Hut quadtree approximation above 180 connected nodes.
5. Resolve card-sized rectangular collisions after relaxation.
6. Place degree-zero nodes on a stable perimeter outside the connected graph's complete card bounds.

The result is reproducible for the same snapshot and does not run an idle physics loop in the editor. It optimizes legibility, disk occupancy, and hub centrality rather than planar edges; arbitrary cross references can still cross.

### Research basis

- Obsidian's official Graph View documentation exposes center, repel, link, and link-distance forces; it does not publish the core implementation.
- Obsidian's official release repository explicitly states that the application is not open source, so this addon does not copy or reverse-engineer its graph code.
- D3 Force documents deterministic phyllotaxis initialization plus link, many-body, centering, and collision forces.
- The ForceAtlas2 paper defines linear attraction, degree-weighted repulsion, gravity, overlap prevention, and Barnes–Hut scaling. This implementation adapts those published principles to fixed-step GDScript rather than reproducing Gephi code.
- Graphviz `neato` and `sfdp` provide additional public references for spring-model and scalable force-directed layouts.

Primary references:

- <https://obsidian.md/help/Plugins/Graph%2Bview>
- <https://github.com/obsidianmd/obsidian-releases>
- <https://d3js.org/d3-force>
- <https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0098679>
- <https://graphviz.org/docs/layouts/neato/>
- <https://graphviz.org/docs/layouts/sfdp/>

## Phase boundaries

- `v0.1.0`: static asset graph, native viewer, navigation, search, JSON.
- `v0.2.0`: organic force layout, scan Ignore, large-graph UX, grouping, reverse view, broken and unused reports.
- `v0.3.0`: scene composition and script semantic analyzers.
- `v0.4.0`: AI context, optional external viewer/runtime capture, public packaging.

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
    |       +-- SemanticConnectionLayer
    |
    +-- ProjectGraphScanner
            |
            +-- ignored-path pruning
            +-- file enumeration
            +-- ResourceLoader dependencies
            +-- static GDScript class_name / extends
            +-- ProjectGraphSchema
            +-- ProjectGraphStore
            +-- ScanIgnoreSettings
```

## Module boundaries

- `plugin.gd` owns editor lifecycle and asset navigation.
- `ui/project_graph_panel.gd` owns user interaction and rendering, but not scanning rules.
- `ui/semantic_connection_layer.gd` renders per-edge arrows, colors, and solid/dashed confidence semantics behind fixed-size cards.
- `core/project_graph_scanner.gd` produces a complete in-memory snapshot and has no editor UI dependency. It combines exact `ResourceLoader` references with non-executing GDScript declaration parsing.
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

1. Build an undirected force topology while retaining directed inheritance pairs. Compute each class's inheritance ancestor level, then sort by hierarchy importance, degree, and stable asset id.
2. Seed connected nodes with a golden-angle phyllotaxis spiral. The highest inheritance ancestor (or otherwise highest-degree node) starts at the origin, so the seed already fills a disk instead of a ring.
3. Run a fixed number of damped relaxation steps. Direct edges use a card-aware target length and degree-adaptive spring strength. Pairs with shared neighbors receive a weaker second-order attraction, so structural proximity becomes visual proximity. All connected nodes still repel one another, while hierarchy/degree-weighted gravity pulls structural hubs toward the center.
4. Use exact pairwise repulsion for small graphs and a deterministic Barnes–Hut quadtree approximation above 180 connected nodes.
5. Resolve fixed `320 × 190` card rectangles with `96 px` collision padding after relaxation.
6. Count straight-line crossings, group nodes into radial bands, and test deterministic angular swaps suggested by neighboring positions. Accept a swap only when crossings fall with bounded mean-edge growth, or when crossings stay equal and total edge length falls. Swapping complete positions preserves the collision result and radial hierarchy.
7. Place degree-zero nodes on a stable perimeter outside the connected graph's complete card bounds.

The result is reproducible for the same snapshot and does not run an idle physics loop in the editor. Layout results expose `crossings_before`, `crossings_after`, `mean_edge_length`, and `community_pair_count`; the panel displays the crossing reduction. Arbitrary or non-planar cross references can still cross, but avoidable crossings are an explicit optimization criterion.

## Semantic edge rendering

`GraphEdit` remains responsible for pan, zoom, selection, dragging, and the minimap, but its undifferentiated default connection lines are not used. `SemanticConnectionLayer` draws each visible edge behind the cards:

- every edge is directed from `source` to `target` and ends in an arrowhead;
- exact `references` edges are solid neutral gray;
- exact `inherits` edges are solid cyan and always point child → parent;
- edges with non-`exact` confidence, runtime/dynamic origin or metadata, plus runtime `creates`, are dashed amber;
- line endpoints are clipped to the fixed card rectangles instead of disappearing under their centers.

The scanner never executes GDScript. Its inheritance pass reads declarations only, resolves `extends "res://..."`, relative script paths, `preload`/`load`, and project `class_name` declarations, and replaces the less-specific ResourceLoader reference to the same parent with one exact `inherits` edge.

### Research basis

- Obsidian's official Graph View documentation exposes center, repel, link, and link-distance forces; it does not publish the core implementation.
- Obsidian's official release repository explicitly states that the application is not open source, so this addon does not copy or reverse-engineer its graph code.
- D3 Force documents deterministic phyllotaxis initialization plus link, many-body, centering, and collision forces.
- The ForceAtlas2 paper defines linear attraction, degree-weighted repulsion, gravity, overlap prevention, and Barnes–Hut scaling. This implementation adapts those published principles to fixed-step GDScript rather than reproducing Gephi code.
- ForceAtlas2 and LinLog describe structural communities as local visual density. The shared-neighbor attraction adapts that goal without introducing a separate runtime or full modularity solver.
- Stress-Plus-X shows that stress/neighborhood preservation and edge crossings need to be optimized together. The bounded angular-swap stage is a lightweight deterministic heuristic for that multi-criterion objective; it is not a full SPX solver.
- Graphviz `neato` and `sfdp` provide additional public references for spring-model and scalable force-directed layouts.

Primary references:

- <https://obsidian.md/help/Plugins/Graph%2Bview>
- <https://github.com/obsidianmd/obsidian-releases>
- <https://d3js.org/d3-force>
- <https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0098679>
- <https://arxiv.org/abs/1908.01769>
- <https://graphviz.org/docs/layouts/neato/>
- <https://graphviz.org/docs/layouts/sfdp/>

## Phase boundaries

- `v0.1.0`: static asset graph, native viewer, navigation, search, JSON.
- `v0.2.0`: organic force layout, scan Ignore, large-graph UX, grouping, reverse view, broken and unused reports.
- `v0.3.0`: scene composition and script semantic analyzers.
- `v0.4.0`: AI context, optional external viewer/runtime capture, public packaging.

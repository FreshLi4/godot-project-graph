extends SceneTree

const GraphSchema = preload("res://addons/freshli4_project_graph/core/graph_schema.gd")
const GraphStore = preload("res://addons/freshli4_project_graph/core/graph_store.gd")
const ProjectGraphScanner = preload(
	"res://addons/freshli4_project_graph/core/project_graph_scanner.gd"
)
const OrganicGraphLayout = preload(
	"res://addons/freshli4_project_graph/core/organic_graph_layout.gd"
)

const FIXTURE_ROOT := "res://tests/fixtures"
const ROUND_TRIP_PATH := "user://freshli4_project_graph/tests/round-trip.json"
const CARD_SIZE := Vector2(270.0, 96.0)

var _failures := PackedStringArray()


func _init() -> void:
	var scanner := ProjectGraphScanner.new()
	var snapshot := scanner.scan_project(FIXTURE_ROOT)

	_expect(
		GraphSchema.validate_snapshot(snapshot).is_empty(),
		"snapshot should satisfy schema v1",
	)
	_expect(_has_node(snapshot, "%s/main.tscn" % FIXTURE_ROOT, "Scene"), "main scene")
	_expect(_has_node(snapshot, "%s/actor.tscn" % FIXTURE_ROOT, "Scene"), "actor scene")
	_expect(_has_node(snapshot, "%s/actor.gd" % FIXTURE_ROOT, "Script"), "actor script")
	_expect(
		_has_node(snapshot, "%s/shared_resource.tres" % FIXTURE_ROOT, "Resource"),
		"shared resource",
	)
	_expect(
		_has_edge(
			snapshot,
			"%s/main.tscn" % FIXTURE_ROOT,
			"%s/actor.tscn" % FIXTURE_ROOT,
		),
		"main scene should reference actor scene",
	)
	_expect(
		_has_edge(
			snapshot,
			"%s/actor.tscn" % FIXTURE_ROOT,
			"%s/actor.gd" % FIXTURE_ROOT,
		),
		"actor scene should reference actor script",
	)
	_expect(
		_has_edge(
			snapshot,
			"%s/actor.tscn" % FIXTURE_ROOT,
			"%s/shared_resource.tres" % FIXTURE_ROOT,
		),
		"actor scene should reference shared resource",
	)
	_expect(_has_unique_ids(snapshot.get("nodes", [])), "node ids should be unique")
	_expect(_has_unique_ids(snapshot.get("edges", [])), "edge ids should be unique")

	var layout := OrganicGraphLayout.new()
	var layout_result := layout.calculate(snapshot, CARD_SIZE)
	var positions := layout_result.get("positions", {}) as Dictionary
	_expect(
		positions.size() == int(snapshot.get("stats", {}).get("node_count", -1)),
		"organic layout should position every fixture node",
	)
	_expect(
		_is_centered(positions, "%s/actor.tscn" % FIXTURE_ROOT),
		"highest-degree fixture node should be the organic center",
	)
	_expect(
		_not_overlapping(positions, CARD_SIZE),
		"fixture organic cards should not overlap",
	)
	_expect(
		layout_result == layout.calculate(snapshot, CARD_SIZE),
		"organic layout should be deterministic",
	)

	var organic_snapshot := _make_organic_snapshot(8, 6, 3)
	var organic_layout := layout.calculate(organic_snapshot, CARD_SIZE)
	var organic_positions := organic_layout.get("positions", {}) as Dictionary
	var organic_orphans := organic_layout.get("orphan_ids", PackedStringArray()) as PackedStringArray
	_expect(
		_not_overlapping(organic_positions, CARD_SIZE),
		"organic cards should not overlap",
	)
	_expect(
		_fills_disk(organic_positions, organic_orphans, "center"),
		"connected organic graph should occupy the disk interior instead of one ring",
	)
	_expect(
		_orphans_are_outermost(organic_positions, organic_orphans),
		"degree-zero nodes should be outside every connected node",
	)
	_expect(
		organic_layout == layout.calculate(organic_snapshot, CARD_SIZE),
		"organic disk layout should remain deterministic",
	)

	var large_snapshot := _make_organic_snapshot(16, 12, 6)
	var large_layout := layout.calculate(large_snapshot, CARD_SIZE)
	var large_positions := large_layout.get("positions", {}) as Dictionary
	var large_orphans := large_layout.get("orphan_ids", PackedStringArray()) as PackedStringArray
	_expect(
		large_positions.size() == 199,
		"Barnes-Hut layout should position every large-graph node",
	)
	_expect(
		_not_overlapping(large_positions, CARD_SIZE),
		"Barnes-Hut layout should preserve card collision constraints",
	)
	_expect(
		_fills_disk(large_positions, large_orphans, "center"),
		"Barnes-Hut layout should preserve disk occupancy",
	)
	_expect(
		_orphans_are_outermost(large_positions, large_orphans),
		"Barnes-Hut layout should keep independent nodes outermost",
	)

	var save_result := GraphStore.save_json(snapshot, ROUND_TRIP_PATH)
	_expect(save_result == OK, "snapshot should save as JSON")
	var restored := GraphStore.load_json(ROUND_TRIP_PATH)
	_expect(not restored.is_empty(), "saved snapshot should load")
	_expect(
		int(restored.get("stats", {}).get("node_count", -1))
		== int(snapshot.get("stats", {}).get("node_count", -2)),
		"JSON round trip should preserve node count",
	)

	var ignored_snapshot := scanner.scan_project(
		FIXTURE_ROOT,
		PackedStringArray(["tests/fixtures/shared_resource.tres"]),
	)
	_expect(
		not _has_node(
			ignored_snapshot,
			"%s/shared_resource.tres" % FIXTURE_ROOT,
			"Resource",
		),
		"custom Ignore should exclude a matching asset",
	)
	_expect(
		not _has_edge(
			ignored_snapshot,
			"%s/actor.tscn" % FIXTURE_ROOT,
			"%s/shared_resource.tres" % FIXTURE_ROOT,
		),
		"custom Ignore should exclude dependency edges to ignored assets",
	)
	var prefix_ignored_snapshot := scanner.scan_project(
		FIXTURE_ROOT,
		PackedStringArray(["tests/fixtures/**"]),
	)
	_expect(
		int(prefix_ignored_snapshot.get("stats", {}).get("node_count", -1)) == 0,
		"directory Ignore patterns should prune traversal before scanning",
	)
	_expect(
		ProjectGraphScanner.normalize_ignore_patterns(
			PackedStringArray(["# comment", " third_party/** "]),
		) == PackedStringArray(["res://third_party/**"]),
		"Ignore patterns should normalize project-relative paths and comments",
	)

	var full_snapshot := scanner.scan_project()
	_expect(
		not _contains_path_prefix(
			full_snapshot.get("nodes", []),
			"res://addons/",
		),
		"scanner should exclude every addon by default",
	)

	if _failures.is_empty():
		print(
			"PASS: Project Graph core (%d nodes, %d edges)"
			% [
				int(snapshot.get("stats", {}).get("node_count", 0)),
				int(snapshot.get("stats", {}).get("edge_count", 0)),
			]
		)
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _has_node(snapshot: Dictionary, id: String, kind: String) -> bool:
	for node_value: Variant in snapshot.get("nodes", []):
		var node := node_value as Dictionary
		if String(node.get("id", "")) == id and String(node.get("kind", "")) == kind:
			return true
	return false


func _has_edge(snapshot: Dictionary, source: String, target: String) -> bool:
	for edge_value: Variant in snapshot.get("edges", []):
		var edge := edge_value as Dictionary
		if (
			String(edge.get("source", "")) == source
			and String(edge.get("target", "")) == target
			and String(edge.get("relation", "")) == "references"
		):
			return true
	return false


func _has_unique_ids(items: Array) -> bool:
	var ids: Dictionary = {}
	for item_value: Variant in items:
		var item := item_value as Dictionary
		var id := String(item.get("id", ""))
		if id.is_empty() or ids.has(id):
			return false
		ids[id] = true
	return true


func _contains_path_prefix(items: Array, prefix: String) -> bool:
	for item_value: Variant in items:
		var item := item_value as Dictionary
		if String(item.get("path", "")).begins_with(prefix):
			return true
	return false


func _is_centered(positions: Dictionary, node_id: String) -> bool:
	if not positions.has(node_id):
		return false
	var center := positions[node_id] as Vector2
	center += CARD_SIZE / 2.0
	return center.is_equal_approx(Vector2.ZERO)


func _not_overlapping(positions: Dictionary, card_size: Vector2) -> bool:
	var node_ids: Array = positions.keys()
	for left_index: int in node_ids.size():
		var left_id := String(node_ids[left_index])
		var left_rect := Rect2(positions[left_id], card_size)
		for right_index: int in range(left_index + 1, node_ids.size()):
			var right_id := String(node_ids[right_index])
			var right_rect := Rect2(positions[right_id], card_size)
			if left_rect.intersects(right_rect):
				return false
	return true


func _make_organic_snapshot(
	branch_count: int,
	branch_depth: int,
	orphan_count: int,
) -> Dictionary:
	var nodes: Array = [
		GraphSchema.make_node("center", "res://center.tscn", "Scene"),
	]
	var edges: Array = []
	for branch_index: int in branch_count:
		var previous_id := "center"
		for depth_index: int in branch_depth:
			var node_id := "branch_%02d_%02d" % [branch_index, depth_index]
			nodes.append(
				GraphSchema.make_node(
					node_id,
					"res://%s.tres" % node_id,
					"Resource",
				)
			)
			edges.append(GraphSchema.make_edge(previous_id, node_id))
			previous_id = node_id
		if branch_index > 0:
			edges.append(
				GraphSchema.make_edge(
					"branch_%02d_02" % (branch_index - 1),
					"branch_%02d_02" % branch_index,
				)
			)
	for orphan_index: int in orphan_count:
		var orphan_id := "orphan_%02d" % orphan_index
		nodes.append(
			GraphSchema.make_node(
				orphan_id,
				"res://%s.tres" % orphan_id,
				"Resource",
			)
		)
	return GraphSchema.make_snapshot("res://", nodes, edges)


func _fills_disk(
	positions: Dictionary,
	orphan_ids: PackedStringArray,
	center_id: String,
) -> bool:
	if not positions.has(center_id):
		return false
	var orphan_set: Dictionary = {}
	for orphan_id: String in orphan_ids:
		orphan_set[orphan_id] = true

	var center := (positions[center_id] as Vector2) + CARD_SIZE / 2.0
	var maximum_radius := 0.0
	for node_id_value: Variant in positions:
		var node_id := String(node_id_value)
		if node_id == center_id or orphan_set.has(node_id):
			continue
		var node_center := (positions[node_id] as Vector2) + CARD_SIZE / 2.0
		var radius := center.distance_to(node_center)
		maximum_radius = maxf(maximum_radius, radius)
	if maximum_radius <= 0.0:
		return false

	var occupied_bands: Dictionary = {0: true}
	var interior_count := 0
	var connected_count := 1
	for node_id_value: Variant in positions:
		var node_id := String(node_id_value)
		if node_id == center_id or orphan_set.has(node_id):
			continue
		connected_count += 1
		var node_center := (positions[node_id] as Vector2) + CARD_SIZE / 2.0
		var normalized_radius := center.distance_to(node_center) / maximum_radius
		var band := clampi(floori(normalized_radius * 5.0), 0, 4)
		occupied_bands[band] = true
		if normalized_radius > 0.12 and normalized_radius < 0.72:
			interior_count += 1
	return occupied_bands.size() >= 4 and interior_count >= connected_count / 5


func _orphans_are_outermost(
	positions: Dictionary,
	orphan_ids: PackedStringArray,
) -> bool:
	if orphan_ids.is_empty():
		return false
	var orphan_set: Dictionary = {}
	for orphan_id: String in orphan_ids:
		orphan_set[orphan_id] = true

	var maximum_connected_radius := 0.0
	var minimum_orphan_radius := INF
	for node_id_value: Variant in positions:
		var node_id := String(node_id_value)
		var node_center := (positions[node_id] as Vector2) + CARD_SIZE / 2.0
		if orphan_set.has(node_id):
			minimum_orphan_radius = minf(minimum_orphan_radius, node_center.length())
		else:
			maximum_connected_radius = maxf(maximum_connected_radius, node_center.length())
	return minimum_orphan_radius > maximum_connected_radius + CARD_SIZE.length() / 2.0

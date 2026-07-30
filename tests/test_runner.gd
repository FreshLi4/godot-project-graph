extends SceneTree

const GraphSchema = preload("res://addons/freshli4_project_graph/core/graph_schema.gd")
const GraphStore = preload("res://addons/freshli4_project_graph/core/graph_store.gd")
const ProjectGraphScanner = preload(
	"res://addons/freshli4_project_graph/core/project_graph_scanner.gd"
)
const OrganicGraphLayout = preload(
	"res://addons/freshli4_project_graph/core/organic_graph_layout.gd"
)
const SemanticConnectionLayer = preload(
	"res://addons/freshli4_project_graph/ui/semantic_connection_layer.gd"
)
const ProjectGraphPanel = preload(
	"res://addons/freshli4_project_graph/ui/project_graph_panel.gd"
)

const FIXTURE_ROOT := "res://tests/fixtures"
const ROUND_TRIP_PATH := "user://freshli4_project_graph/tests/round-trip.json"
const CARD_SIZE := Vector2(320.0, 320.0)
const LARGE_CARD_SIZE := Vector2(420.0, 420.0)
const LONG_FILENAME_FIXTURE := (
	FIXTURE_ROOT
	+ "/this_is_a_deliberately_very_long_asset_filename_that_must_wrap_inside_a_"
	+ "fixed_width_project_graph_card_without_showing_its_resource_path.tres"
)

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
		_has_node(snapshot, "%s/base_actor.gd" % FIXTURE_ROOT, "Script"),
		"base actor script",
	)
	_expect(
		_has_node(snapshot, "%s/child_actor.gd" % FIXTURE_ROOT, "Script"),
		"child actor script",
	)
	_expect(
		_has_node(snapshot, "%s/shared_resource.tres" % FIXTURE_ROOT, "Resource"),
		"shared resource",
	)
	_expect(
		_has_node(snapshot, LONG_FILENAME_FIXTURE, "Resource"),
		"long filename fixture should be scanned for fixed-width wrapping smoke",
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
	_expect(
		_has_edge(
			snapshot,
			"%s/child_actor.gd" % FIXTURE_ROOT,
			"%s/base_actor.gd" % FIXTURE_ROOT,
			GraphSchema.RELATION_INHERITS,
		),
		"GDScript inheritance should point from child to parent",
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
		_is_centered(positions, "%s/base_actor.gd" % FIXTURE_ROOT),
		"highest inheritance ancestor should override degree as the organic center",
	)
	_expect(
		_not_overlapping(positions, CARD_SIZE),
		"fixture organic cards should not overlap",
	)
	_expect(
		layout_result == layout.calculate(snapshot, CARD_SIZE),
		"organic layout should be deterministic",
	)

	var hierarchy_snapshot := _make_hierarchy_snapshot()
	var hierarchy_layout := layout.calculate(hierarchy_snapshot, CARD_SIZE)
	_expect(
		String(hierarchy_layout.get("root", "")) == "base",
		"highest GDScript ancestor should be the layout center",
	)
	var hierarchy_levels := hierarchy_layout.get("hierarchy_levels", {}) as Dictionary
	_expect(
		int(hierarchy_levels.get("base", -1)) > int(hierarchy_levels.get("middle", -1))
		and int(hierarchy_levels.get("middle", -1)) > int(hierarchy_levels.get("child", -1)),
		"inheritance hierarchy should increase central weight toward ancestors",
	)
	var inheritance_style := SemanticConnectionLayer.edge_style(
		GraphSchema.make_edge(
			"child",
			"base",
			GraphSchema.RELATION_INHERITS,
			GraphSchema.ORIGIN_GDSCRIPT_STATIC,
			GraphSchema.CONFIDENCE_EXACT,
		)
	)
	_expect(
		not bool(inheritance_style.get("dashed", true))
		and String(inheritance_style.get("semantic", "")) == "inherits",
		"exact inheritance should use a solid semantic arrow",
	)
	var inferred_style := SemanticConnectionLayer.edge_style(
		GraphSchema.make_edge(
			"factory",
			"spawned",
			GraphSchema.RELATION_CREATES,
			"RuntimeAnalyzer",
			GraphSchema.CONFIDENCE_INFERRED,
		)
	)
	_expect(
		bool(inferred_style.get("dashed", false))
		and String(inferred_style.get("semantic", "")) == "inferred_dynamic",
		"inferred or dynamic relationships should use dashed arrows",
	)
	_expect(
		ProjectGraphPanel.scroll_offset_after_drag(
			Vector2(20.0, 30.0),
			Vector2(10.0, -6.0),
			2.0,
		).is_equal_approx(Vector2(15.0, 33.0)),
		"left-button canvas dragging should pan relative to the current zoom",
	)
	var route_source := Rect2(0.0, 0.0, 100.0, 60.0)
	var route_target := Rect2(360.0, 0.0, 100.0, 60.0)
	var route_blocker := Rect2(170.0, -30.0, 120.0, 120.0)
	var obstacle_route := SemanticConnectionLayer.route_around_obstacles(
		route_source,
		route_target,
		[route_blocker],
	)
	_expect(
		obstacle_route.size() > 2,
		"semantic edges should detour when a third-party card blocks the direct line",
	)
	_expect(
		SemanticConnectionLayer.polyline_avoids_rects(
			obstacle_route,
			[route_blocker],
		),
		"semantic edge detours should preserve clearance from every blocking card",
	)
	var multi_blocker_route := SemanticConnectionLayer.route_around_obstacles(
		route_source,
		route_target,
		[
			Rect2(125.0, -20.0, 80.0, 95.0),
			Rect2(250.0, -55.0, 75.0, 110.0),
		],
	)
	_expect(
		multi_blocker_route.size() > 2
		and SemanticConnectionLayer.polyline_avoids_rects(
			multi_blocker_route,
			[
				Rect2(125.0, -20.0, 80.0, 95.0),
				Rect2(250.0, -55.0, 75.0, 110.0),
			],
		),
		"visibility routing should discover secondary blockers and remain unobstructed",
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
		_has_minimum_clearance(
			organic_positions,
			CARD_SIZE,
			OrganicGraphLayout.NODE_GAP - 0.1,
		),
		"organic cards should leave visible connector clearance",
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
	_expect(
		int(organic_layout.get("crossings_after", -1))
		<= int(organic_layout.get("crossings_before", -1)),
		"readability refinement should never increase edge crossings",
	)
	_expect(
		int(organic_layout.get("community_pair_count", 0)) > 0,
		"shared neighbors should produce deterministic community attraction pairs",
	)
	_expect(
		_all_snapshot_routes_avoid_cards(
			organic_snapshot,
			organic_positions,
			CARD_SIZE,
		),
		"every organic semantic edge should route around unrelated asset cards",
	)
	var oversized_layout := layout.calculate(organic_snapshot, LARGE_CARD_SIZE)
	_expect(
		_has_minimum_clearance(
			oversized_layout.get("positions", {}) as Dictionary,
			LARGE_CARD_SIZE,
			OrganicGraphLayout.NODE_GAP - 0.1,
		),
		"layout should preserve clearance for alternate fixed card envelopes",
	)

	var cluster_snapshot := _make_cluster_snapshot()
	var cluster_layout := layout.calculate(cluster_snapshot, CARD_SIZE)
	var cluster_positions := cluster_layout.get("positions", {}) as Dictionary
	_expect(
		_mean_linked_distance(cluster_snapshot, cluster_positions)
		< _mean_unlinked_distance(cluster_snapshot, cluster_positions),
		"directly related assets should be closer than unrelated assets",
	)
	_expect(
		_has_minimum_clearance(
			cluster_positions,
			CARD_SIZE,
			OrganicGraphLayout.NODE_GAP - 0.1,
		),
		"cluster refinement should preserve card clearance",
	)

	var crossing_snapshot := _make_crossing_snapshot()
	var crossing_refinement := layout.refine_positions(
		crossing_snapshot,
		_make_crossing_positions(),
		CARD_SIZE,
	)
	_expect(
		int(crossing_refinement.get("crossings_before", -1)) == 1
		and int(crossing_refinement.get("crossings_after", -1)) == 0,
		"angular swaps should remove a geometrically avoidable crossing",
	)
	_expect(
		_has_minimum_clearance(
			crossing_refinement.get("positions", {}) as Dictionary,
			CARD_SIZE,
			OrganicGraphLayout.NODE_GAP - 0.1,
		),
		"crossing refinement should preserve existing card clearance",
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
			(
				"READABILITY: crossings organic %d -> %d, large %d -> %d; "
				+ "cluster linked %.1f vs unlinked %.1f"
			)
			% [
				int(organic_layout.get("crossings_before", 0)),
				int(organic_layout.get("crossings_after", 0)),
				int(large_layout.get("crossings_before", 0)),
				int(large_layout.get("crossings_after", 0)),
				_mean_linked_distance(cluster_snapshot, cluster_positions),
				_mean_unlinked_distance(cluster_snapshot, cluster_positions),
			]
		)
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


func _has_edge(
	snapshot: Dictionary,
	source: String,
	target: String,
	relation: String = GraphSchema.RELATION_REFERENCE,
) -> bool:
	for edge_value: Variant in snapshot.get("edges", []):
		var edge := edge_value as Dictionary
		if (
			String(edge.get("source", "")) == source
			and String(edge.get("target", "")) == target
			and String(edge.get("relation", "")) == relation
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
	return _has_minimum_clearance(positions, card_size, 0.0)


func _has_minimum_clearance(
	positions: Dictionary,
	card_size: Vector2,
	minimum_clearance: float,
) -> bool:
	var node_ids: Array = positions.keys()
	for left_index: int in node_ids.size():
		var left_id := String(node_ids[left_index])
		var left_rect := Rect2(positions[left_id], card_size)
		for right_index: int in range(left_index + 1, node_ids.size()):
			var right_id := String(node_ids[right_index])
			var right_rect := Rect2(positions[right_id], card_size)
			var horizontal_gap := (
				maxf(left_rect.position.x, right_rect.position.x)
				- minf(left_rect.end.x, right_rect.end.x)
			)
			var vertical_gap := (
				maxf(left_rect.position.y, right_rect.position.y)
				- minf(left_rect.end.y, right_rect.end.y)
			)
			if (
				horizontal_gap < minimum_clearance
				and vertical_gap < minimum_clearance
			):
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


func _make_hierarchy_snapshot() -> Dictionary:
	var nodes: Array = [
		GraphSchema.make_node("base", "res://base.gd", "Script"),
		GraphSchema.make_node("middle", "res://middle.gd", "Script"),
		GraphSchema.make_node("child", "res://child.gd", "Script"),
	]
	var edges: Array = [
		GraphSchema.make_edge(
			"child",
			"middle",
			GraphSchema.RELATION_INHERITS,
			GraphSchema.ORIGIN_GDSCRIPT_STATIC,
		),
		GraphSchema.make_edge(
			"middle",
			"base",
			GraphSchema.RELATION_INHERITS,
			GraphSchema.ORIGIN_GDSCRIPT_STATIC,
		),
	]
	return GraphSchema.make_snapshot("res://", nodes, edges)


func _make_cluster_snapshot() -> Dictionary:
	var nodes: Array = []
	for node_id: String in [
		"hub_a",
		"a_1",
		"a_2",
		"a_3",
		"hub_b",
		"b_1",
		"b_2",
		"b_3",
	]:
		nodes.append(
			GraphSchema.make_node(
				node_id,
				"res://%s.tres" % node_id,
				"Resource",
			)
		)
	var edges: Array = [
		GraphSchema.make_edge("hub_a", "a_1"),
		GraphSchema.make_edge("hub_a", "a_2"),
		GraphSchema.make_edge("hub_a", "a_3"),
		GraphSchema.make_edge("a_1", "a_2"),
		GraphSchema.make_edge("hub_b", "b_1"),
		GraphSchema.make_edge("hub_b", "b_2"),
		GraphSchema.make_edge("hub_b", "b_3"),
		GraphSchema.make_edge("b_1", "b_2"),
		GraphSchema.make_edge("hub_a", "hub_b"),
	]
	return GraphSchema.make_snapshot("res://", nodes, edges)


func _make_crossing_snapshot() -> Dictionary:
	var nodes: Array = []
	for node_id: String in ["a", "b", "c", "d"]:
		nodes.append(
			GraphSchema.make_node(
				node_id,
				"res://%s.tres" % node_id,
				"Resource",
			)
		)
	var edges: Array = [
		GraphSchema.make_edge("a", "b"),
		GraphSchema.make_edge("c", "d"),
	]
	return GraphSchema.make_snapshot("res://", nodes, edges)


func _make_crossing_positions() -> Dictionary:
	var half_card := CARD_SIZE / 2.0
	return {
		"a": Vector2(-300.0, -300.0) - half_card,
		"b": Vector2(300.0, 300.0) - half_card,
		"c": Vector2(300.0, -300.0) - half_card,
		"d": Vector2(-300.0, 300.0) - half_card,
	}


func _mean_linked_distance(snapshot: Dictionary, positions: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for edge_value: Variant in snapshot.get("edges", []):
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		var source_center := (positions[source_id] as Vector2) + CARD_SIZE / 2.0
		var target_center := (positions[target_id] as Vector2) + CARD_SIZE / 2.0
		total += source_center.distance_to(target_center)
		count += 1
	return total / float(maxi(count, 1))


func _mean_unlinked_distance(snapshot: Dictionary, positions: Dictionary) -> float:
	var linked_pairs: Dictionary = {}
	for edge_value: Variant in snapshot.get("edges", []):
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		linked_pairs[_undirected_pair_key(source_id, target_id)] = true
	var node_ids: Array = positions.keys()
	node_ids.sort()
	var total := 0.0
	var count := 0
	for left_offset: int in node_ids.size():
		var left_id := String(node_ids[left_offset])
		for right_offset: int in range(left_offset + 1, node_ids.size()):
			var right_id := String(node_ids[right_offset])
			if linked_pairs.has(_undirected_pair_key(left_id, right_id)):
				continue
			var left_center := (positions[left_id] as Vector2) + CARD_SIZE / 2.0
			var right_center := (positions[right_id] as Vector2) + CARD_SIZE / 2.0
			total += left_center.distance_to(right_center)
			count += 1
	return total / float(maxi(count, 1))


func _undirected_pair_key(left_id: String, right_id: String) -> String:
	return (
		"%s|%s" % [left_id, right_id]
		if left_id < right_id
		else "%s|%s" % [right_id, left_id]
	)


func _all_snapshot_routes_avoid_cards(
	snapshot: Dictionary,
	positions: Dictionary,
	card_size: Vector2,
) -> bool:
	for edge_value: Variant in snapshot.get("edges", []):
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		if not positions.has(source_id) or not positions.has(target_id):
			return false
		var obstacles: Array = []
		for node_id_value: Variant in positions:
			var node_id := String(node_id_value)
			if node_id == source_id or node_id == target_id:
				continue
			obstacles.append(Rect2(positions[node_id], card_size))
		var route := SemanticConnectionLayer.route_around_obstacles(
			Rect2(positions[source_id], card_size),
			Rect2(positions[target_id], card_size),
			obstacles,
		)
		if not SemanticConnectionLayer.polyline_avoids_rects(route, obstacles):
			return false
	return true


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

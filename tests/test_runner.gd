extends SceneTree

const GraphSchema = preload("res://addons/freshli4_project_graph/core/graph_schema.gd")
const GraphStore = preload("res://addons/freshli4_project_graph/core/graph_store.gd")
const ProjectGraphScanner = preload(
	"res://addons/freshli4_project_graph/core/project_graph_scanner.gd"
)

const FIXTURE_ROOT := "res://tests/fixtures"
const ROUND_TRIP_PATH := "user://freshli4_project_graph/tests/round-trip.json"

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

	var save_result := GraphStore.save_json(snapshot, ROUND_TRIP_PATH)
	_expect(save_result == OK, "snapshot should save as JSON")
	var restored := GraphStore.load_json(ROUND_TRIP_PATH)
	_expect(not restored.is_empty(), "saved snapshot should load")
	_expect(
		int(restored.get("stats", {}).get("node_count", -1))
		== int(snapshot.get("stats", {}).get("node_count", -2)),
		"JSON round trip should preserve node count",
	)

	var full_snapshot := scanner.scan_project()
	_expect(
		not _contains_path_prefix(
			full_snapshot.get("nodes", []),
			"res://addons/freshli4_project_graph",
		),
		"scanner should exclude its own addon implementation",
	)

	if _failures.is_empty():
		print(
			"PASS: Project Graph Phase 1 (%d nodes, %d edges)"
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

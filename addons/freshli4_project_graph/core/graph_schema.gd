@tool
extends RefCounted

const SCHEMA_VERSION := 1
const RELATION_REFERENCE := "references"
const RELATION_INHERITS := "inherits"
const RELATION_CREATES := "creates"
const CONFIDENCE_EXACT := "exact"
const CONFIDENCE_INFERRED := "inferred"
const ORIGIN_RESOURCE_LOADER := "ResourceLoader"
const ORIGIN_GDSCRIPT_STATIC := "GDScriptStatic"

const NODE_KINDS := [
	"Scene",
	"Script",
	"Resource",
	"Mesh",
	"Texture",
	"Audio",
	"Shader",
	"Data",
]


static func make_node(
	id: String,
	path: String,
	kind: String,
	missing: bool = false,
	metadata: Dictionary = {},
) -> Dictionary:
	return {
		"id": id,
		"label": path.get_file(),
		"kind": kind,
		"path": path,
		"missing": missing,
		"metadata": metadata.duplicate(true),
	}


static func make_edge(
	source: String,
	target: String,
	relation: String = RELATION_REFERENCE,
	origin: String = ORIGIN_RESOURCE_LOADER,
	confidence: String = CONFIDENCE_EXACT,
	metadata: Dictionary = {},
) -> Dictionary:
	return {
		"id": "%s|%s|%s" % [source, relation, target],
		"source": source,
		"target": target,
		"relation": relation,
		"origin": origin,
		"confidence": confidence,
		"metadata": metadata.duplicate(true),
	}


static func make_snapshot(
	root_path: String,
	nodes: Array,
	edges: Array,
) -> Dictionary:
	var type_counts: Dictionary = {}
	var missing_count := 0
	for node_value: Variant in nodes:
		var node := node_value as Dictionary
		var kind := String(node.get("kind", "Data"))
		type_counts[kind] = int(type_counts.get(kind, 0)) + 1
		if bool(node.get("missing", false)):
			missing_count += 1

	return {
		"schema_version": SCHEMA_VERSION,
		"generated_at": Time.get_datetime_string_from_system(true),
		"project": {
			"name": String(ProjectSettings.get_setting(
				"application/config/name",
				"Unnamed Godot Project",
			)),
			"root": root_path,
		},
		"nodes": nodes,
		"edges": edges,
		"stats": {
			"node_count": nodes.size(),
			"edge_count": edges.size(),
			"missing_node_count": missing_count,
			"node_type_counts": type_counts,
		},
	}


static func validate_snapshot(snapshot: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(snapshot.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)

	var project_value: Variant = snapshot.get("project")
	if not project_value is Dictionary:
		errors.append("project must be a Dictionary")

	var nodes_value: Variant = snapshot.get("nodes")
	var edges_value: Variant = snapshot.get("edges")
	if not nodes_value is Array:
		errors.append("nodes must be an Array")
	if not edges_value is Array:
		errors.append("edges must be an Array")
	if not errors.is_empty():
		return errors

	var node_ids: Dictionary = {}
	for node_value: Variant in nodes_value:
		if not node_value is Dictionary:
			errors.append("every node must be a Dictionary")
			continue
		var node := node_value as Dictionary
		for key: String in ["id", "label", "kind", "path", "missing", "metadata"]:
			if not node.has(key):
				errors.append("node is missing key: %s" % key)
		var node_id := String(node.get("id", ""))
		if node_id.is_empty():
			errors.append("node id must not be empty")
		elif node_ids.has(node_id):
			errors.append("duplicate node id: %s" % node_id)
		else:
			node_ids[node_id] = true
		if not NODE_KINDS.has(String(node.get("kind", ""))):
			errors.append("unsupported node kind: %s" % String(node.get("kind", "")))

	var edge_ids: Dictionary = {}
	for edge_value: Variant in edges_value:
		if not edge_value is Dictionary:
			errors.append("every edge must be a Dictionary")
			continue
		var edge := edge_value as Dictionary
		for key: String in [
			"id",
			"source",
			"target",
			"relation",
			"origin",
			"confidence",
			"metadata",
		]:
			if not edge.has(key):
				errors.append("edge is missing key: %s" % key)
		var edge_id := String(edge.get("id", ""))
		if edge_id.is_empty():
			errors.append("edge id must not be empty")
		elif edge_ids.has(edge_id):
			errors.append("duplicate edge id: %s" % edge_id)
		else:
			edge_ids[edge_id] = true
		var source := String(edge.get("source", ""))
		var target := String(edge.get("target", ""))
		if not node_ids.has(source):
			errors.append("edge source is missing: %s" % source)
		if not node_ids.has(target):
			errors.append("edge target is missing: %s" % target)

	return errors

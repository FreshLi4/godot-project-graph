@tool
extends RefCounted

const GraphSchema = preload("res://addons/freshli4_project_graph/core/graph_schema.gd")

const SELF_ADDON_PATH := "res://addons/freshli4_project_graph"
const IGNORED_DIRECTORY_NAMES := [
	".git",
	".godot",
	".import",
	".mono",
]

const KIND_BY_EXTENSION := {
	"tscn": "Scene",
	"scn": "Scene",
	"gd": "Script",
	"cs": "Script",
	"tres": "Resource",
	"res": "Resource",
	"material": "Resource",
	"theme": "Resource",
	"glb": "Mesh",
	"gltf": "Mesh",
	"fbx": "Mesh",
	"obj": "Mesh",
	"dae": "Mesh",
	"mesh": "Mesh",
	"png": "Texture",
	"jpg": "Texture",
	"jpeg": "Texture",
	"webp": "Texture",
	"svg": "Texture",
	"dds": "Texture",
	"ktx": "Texture",
	"ktx2": "Texture",
	"wav": "Audio",
	"ogg": "Audio",
	"mp3": "Audio",
	"gdshader": "Shader",
	"shader": "Shader",
	"json": "Data",
	"cfg": "Data",
	"csv": "Data",
	"xml": "Data",
}

const DEPENDENCY_EXTENSIONS := [
	"tscn",
	"scn",
	"tres",
	"res",
	"gd",
	"cs",
	"glb",
	"gltf",
]

var _nodes_by_id: Dictionary = {}
var _edges_by_id: Dictionary = {}


func scan_project(root_path: String = "res://") -> Dictionary:
	_nodes_by_id.clear()
	_edges_by_id.clear()

	var normalized_root := _normalize_root(root_path)
	var files := PackedStringArray()
	_collect_files(normalized_root, files)
	files.sort()

	for path: String in files:
		if _is_supported_asset(path):
			_add_asset_node(path, false)

	for path: String in files:
		if _nodes_by_id.has(path) and _can_report_dependencies(path):
			_scan_dependencies(path)

	var nodes: Array = _nodes_by_id.values()
	var edges: Array = _edges_by_id.values()
	nodes.sort_custom(_sort_by_id)
	edges.sort_custom(_sort_by_id)
	return GraphSchema.make_snapshot(normalized_root, nodes, edges)


func _collect_files(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		var entry_path := directory_path.path_join(entry_name)
		if directory.current_is_dir():
			if (
				not IGNORED_DIRECTORY_NAMES.has(entry_name)
				and not entry_path.begins_with(SELF_ADDON_PATH)
			):
				_collect_files(entry_path, output)
		elif not entry_name.begins_with("."):
			output.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _scan_dependencies(source_path: String) -> void:
	for raw_dependency: String in ResourceLoader.get_dependencies(source_path):
		var dependency_path := _normalize_dependency(raw_dependency)
		if (
			dependency_path.is_empty()
			or not dependency_path.begins_with("res://")
			or dependency_path.begins_with(SELF_ADDON_PATH)
		):
			continue

		var dependency_exists := (
			FileAccess.file_exists(dependency_path)
			or ResourceLoader.exists(dependency_path)
		)
		if not _nodes_by_id.has(dependency_path):
			_add_asset_node(dependency_path, not dependency_exists)

		var edge := GraphSchema.make_edge(source_path, dependency_path)
		_edges_by_id[String(edge["id"])] = edge


func _add_asset_node(path: String, missing: bool) -> void:
	var extension := path.get_extension().to_lower()
	var kind := String(KIND_BY_EXTENSION.get(extension, "Data"))
	_nodes_by_id[path] = GraphSchema.make_node(
		path,
		path,
		kind,
		missing,
		{"extension": extension},
	)


func _normalize_dependency(raw_dependency: String) -> String:
	if raw_dependency.begins_with("res://"):
		return raw_dependency

	var components := raw_dependency.split("::", false)
	for component_value: String in components:
		if component_value.begins_with("res://"):
			return component_value

	var uid_text := ""
	for component_value: String in components:
		if component_value.begins_with("uid://"):
			uid_text = component_value
			break
	if not uid_text.is_empty():
		var uid := ResourceUID.text_to_id(uid_text)
		if uid != ResourceUID.INVALID_ID:
			return ResourceUID.get_id_path(uid)

	return ""


func _normalize_root(root_path: String) -> String:
	var normalized := root_path.strip_edges()
	if normalized.is_empty():
		return "res://"
	if normalized != "res://" and normalized.ends_with("/"):
		normalized = normalized.trim_suffix("/")
	return normalized


func _is_supported_asset(path: String) -> bool:
	return KIND_BY_EXTENSION.has(path.get_extension().to_lower())


func _can_report_dependencies(path: String) -> bool:
	return DEPENDENCY_EXTENSIONS.has(path.get_extension().to_lower())


func _sort_by_id(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("id", "")) < String(right.get("id", ""))

@tool
extends RefCounted

const GraphSchema = preload("res://addons/freshli4_project_graph/core/graph_schema.gd")

const DEFAULT_IGNORE_PATTERNS := [
	"res://addons/**",
	"res://.godot/**",
	"res://.import/**",
]
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
var _ignore_patterns := PackedStringArray()


func scan_project(
	root_path: String = "res://",
	custom_ignore_patterns: PackedStringArray = PackedStringArray(),
) -> Dictionary:
	_nodes_by_id.clear()
	_edges_by_id.clear()
	_ignore_patterns = get_combined_ignore_patterns(custom_ignore_patterns)

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

	_scan_gdscript_inheritance(files)

	var nodes: Array = _nodes_by_id.values()
	var edges: Array = _edges_by_id.values()
	nodes.sort_custom(_sort_by_id)
	edges.sort_custom(_sort_by_id)
	return GraphSchema.make_snapshot(normalized_root, nodes, edges)


func _collect_files(directory_path: String, output: PackedStringArray) -> void:
	if _is_ignored_path(directory_path):
		return
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
				and not _is_ignored_path(entry_path)
			):
				_collect_files(entry_path, output)
		elif (
			not entry_name.begins_with(".")
			and not _is_ignored_path(entry_path)
		):
			output.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _scan_dependencies(source_path: String) -> void:
	for raw_dependency: String in ResourceLoader.get_dependencies(source_path):
		var dependency_path := _normalize_dependency(raw_dependency)
		if (
			dependency_path.is_empty()
			or not dependency_path.begins_with("res://")
			or _is_ignored_path(dependency_path)
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


func _scan_gdscript_inheritance(files: PackedStringArray) -> void:
	var class_paths: Dictionary = {}
	var script_sources: Dictionary = {}
	for path: String in files:
		if path.get_extension().to_lower() != "gd" or not _nodes_by_id.has(path):
			continue
		var source := _read_text(path)
		if source.is_empty():
			continue
		script_sources[path] = source
		var declared_class := _find_declaration_value(source, "class_name")
		if not declared_class.is_empty():
			class_paths[declared_class] = path

	for source_path_value: Variant in script_sources:
		var source_path := String(source_path_value)
		var parent_path := _resolve_gdscript_parent(
			source_path,
			String(script_sources[source_path]),
			class_paths,
		)
		if (
			parent_path.is_empty()
			or parent_path == source_path
			or _is_ignored_path(parent_path)
		):
			continue
		var parent_exists := (
			FileAccess.file_exists(parent_path)
			or ResourceLoader.exists(parent_path)
		)
		if not _nodes_by_id.has(parent_path):
			_add_asset_node(parent_path, not parent_exists)
		var reference_id := "%s|%s|%s" % [
			source_path,
			GraphSchema.RELATION_REFERENCE,
			parent_path,
		]
		_edges_by_id.erase(reference_id)
		var inheritance_edge := GraphSchema.make_edge(
			source_path,
			parent_path,
			GraphSchema.RELATION_INHERITS,
			GraphSchema.ORIGIN_GDSCRIPT_STATIC,
			GraphSchema.CONFIDENCE_EXACT,
		)
		_edges_by_id[String(inheritance_edge["id"])] = inheritance_edge


func _resolve_gdscript_parent(
	source_path: String,
	source: String,
	class_paths: Dictionary,
) -> String:
	var declaration := _find_extends_declaration(source)
	if declaration.is_empty():
		return ""
	if declaration.begins_with("res://"):
		return declaration.simplify_path()
	if declaration.contains("/") or declaration.ends_with(".gd"):
		return source_path.get_base_dir().path_join(declaration).simplify_path()
	return String(class_paths.get(declaration, ""))


func _find_extends_declaration(source: String) -> String:
	for raw_line: String in source.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if not line.begins_with("extends "):
			continue
		var expression := line.trim_prefix("extends ").strip_edges()
		var comment_index := expression.find(" #")
		if comment_index >= 0:
			expression = expression.left(comment_index).strip_edges()
		for function_name: String in ["preload", "load"]:
			var prefix := function_name + "("
			if expression.begins_with(prefix) and expression.ends_with(")"):
				expression = expression.trim_prefix(prefix).trim_suffix(")").strip_edges()
				break
		if (
			expression.length() >= 2
			and (
				(expression.begins_with("\"") and expression.ends_with("\""))
				or (expression.begins_with("'") and expression.ends_with("'"))
			)
		):
			expression = expression.substr(1, expression.length() - 2)
		return expression
	return ""


func _find_declaration_value(source: String, keyword: String) -> String:
	var prefix := keyword + " "
	for raw_line: String in source.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with(prefix):
			var value := line.trim_prefix(prefix).strip_edges().get_slice(" ", 0)
			return value.get_slice("#", 0).strip_edges()
	return ""


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


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


static func get_combined_ignore_patterns(
	custom_ignore_patterns: PackedStringArray = PackedStringArray(),
) -> PackedStringArray:
	var combined := normalize_ignore_patterns(PackedStringArray(DEFAULT_IGNORE_PATTERNS))
	for pattern: String in normalize_ignore_patterns(custom_ignore_patterns):
		if not combined.has(pattern):
			combined.append(pattern)
	return combined


static func normalize_ignore_patterns(
	raw_patterns: PackedStringArray,
) -> PackedStringArray:
	var normalized_patterns := PackedStringArray()
	for raw_pattern: String in raw_patterns:
		var pattern := raw_pattern.strip_edges().replace("\\", "/")
		if pattern.is_empty() or pattern.begins_with("#"):
			continue
		if not pattern.begins_with("res://"):
			pattern = "res://" + pattern.trim_prefix("/")
		if not normalized_patterns.has(pattern):
			normalized_patterns.append(pattern)
	return normalized_patterns


func _is_ignored_path(path: String) -> bool:
	var normalized_path := path.replace("\\", "/").trim_suffix("/")
	for pattern: String in _ignore_patterns:
		if pattern.ends_with("/**"):
			var prefix := pattern.trim_suffix("/**").trim_suffix("/")
			if normalized_path == prefix or normalized_path.begins_with(prefix + "/"):
				return true
		elif pattern.ends_with("/"):
			var prefix := pattern.trim_suffix("/")
			if normalized_path == prefix or normalized_path.begins_with(prefix + "/"):
				return true
		elif pattern.contains("*") or pattern.contains("?"):
			if normalized_path.match(pattern):
				return true
		elif normalized_path == pattern:
			return true
	return false


func _is_supported_asset(path: String) -> bool:
	return KIND_BY_EXTENSION.has(path.get_extension().to_lower())


func _can_report_dependencies(path: String) -> bool:
	return DEPENDENCY_EXTENSIONS.has(path.get_extension().to_lower())


func _sort_by_id(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("id", "")) < String(right.get("id", ""))

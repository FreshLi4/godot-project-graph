@tool
extends RefCounted

const GraphSchema = preload("res://addons/freshli4_project_graph/core/graph_schema.gd")
const DEFAULT_EXPORT_PATH := "user://freshli4_project_graph/project-graph.json"


static func save_json(snapshot: Dictionary, path: String = DEFAULT_EXPORT_PATH) -> Error:
	var validation_errors := GraphSchema.validate_snapshot(snapshot)
	if not validation_errors.is_empty():
		push_error("Cannot save invalid project graph: %s" % "; ".join(validation_errors))
		return ERR_INVALID_DATA

	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot, "\t", true))
	file.store_string("\n")
	return OK


static func load_json(path: String = DEFAULT_EXPORT_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var snapshot := parsed as Dictionary
	if not GraphSchema.validate_snapshot(snapshot).is_empty():
		return {}
	return snapshot

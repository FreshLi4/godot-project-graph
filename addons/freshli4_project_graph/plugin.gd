@tool
extends EditorPlugin

const ProjectGraphPanel = preload(
	"res://addons/freshli4_project_graph/ui/project_graph_panel.gd"
)

var _panel: Control


func _enter_tree() -> void:
	_panel = ProjectGraphPanel.new()
	_panel.name = "FreshLi4ProjectGraph"
	_panel.asset_activated.connect(_open_asset)
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)
	if OS.get_cmdline_user_args().has("--project-graph-smoke"):
		_panel.call_deferred("run_editor_smoke")


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		if _panel.asset_activated.is_connected(_open_asset):
			_panel.asset_activated.disconnect(_open_asset)
		_panel.queue_free()
	_panel = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_panel):
		_panel.visible = visible


func _get_plugin_name() -> String:
	return "Project Graph"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GraphEdit", "EditorIcons")


func _open_asset(path: String) -> void:
	if path.is_empty() or not path.begins_with("res://"):
		return
	if path.get_extension().to_lower() in ["tscn", "scn"]:
		EditorInterface.open_scene_from_path(path)
		return

	var resource := ResourceLoader.load(path)
	if resource == null:
		push_warning("Project Graph could not open missing resource: %s" % path)
	elif resource is Script:
		EditorInterface.edit_script(resource)
	else:
		EditorInterface.edit_resource(resource)

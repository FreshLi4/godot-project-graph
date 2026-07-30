@tool
extends VBoxContainer

signal asset_activated(path: String)

const ProjectGraphScanner = preload(
	"res://addons/freshli4_project_graph/core/project_graph_scanner.gd"
)
const GraphStore = preload(
	"res://addons/freshli4_project_graph/core/graph_store.gd"
)
const OrganicGraphLayout = preload(
	"res://addons/freshli4_project_graph/core/organic_graph_layout.gd"
)
const ScanIgnoreSettings = preload(
	"res://addons/freshli4_project_graph/core/scan_ignore_settings.gd"
)

const CARD_SIZE := Vector2(270.0, 96.0)

var _scanner := ProjectGraphScanner.new()
var _layout := OrganicGraphLayout.new()
var _snapshot: Dictionary = {}
var _graph_names_by_id: Dictionary = {}
var _cards_by_id: Dictionary = {}
var _custom_ignore_patterns := PackedStringArray()

var _scan_button: Button
var _layout_button: Button
var _ignore_button: Button
var _export_button: Button
var _search_field: LineEdit
var _status_label: Label
var _graph_edit: GraphEdit
var _export_dialog: EditorFileDialog
var _ignore_dialog: ConfirmationDialog
var _ignore_editor: TextEdit


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_custom_ignore_patterns = ScanIgnoreSettings.load_custom_patterns()
	_build_ui()


func _build_ui() -> void:
	add_theme_constant_override("separation", 8)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	_scan_button = Button.new()
	_scan_button.text = "Scan Project"
	_scan_button.tooltip_text = "Scan res:// without instantiating scenes."
	_scan_button.pressed.connect(_scan_project)
	toolbar.add_child(_scan_button)

	_layout_button = Button.new()
	_layout_button.text = "Organic Layout"
	_layout_button.tooltip_text = "Restore the deterministic force-directed disk layout."
	_layout_button.disabled = true
	_layout_button.pressed.connect(_apply_organic_layout)
	toolbar.add_child(_layout_button)

	_ignore_button = Button.new()
	_ignore_button.text = "Ignore…"
	_ignore_button.tooltip_text = (
		"Exclude project paths before scanning. "
		+ "addons and Godot-generated directories are excluded by default."
	)
	_ignore_button.pressed.connect(_show_ignore_dialog)
	toolbar.add_child(_ignore_button)

	_export_button = Button.new()
	_export_button.text = "Export JSON"
	_export_button.disabled = true
	_export_button.pressed.connect(_show_export_dialog)
	toolbar.add_child(_export_button)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search name, path, or type"
	_search_field.clear_button_enabled = true
	_search_field.custom_minimum_size.x = 280.0
	_search_field.text_changed.connect(_apply_search)
	toolbar.add_child(_search_field)

	_status_label = Label.new()
	_status_label.text = "Ready. Click Scan Project."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_status_label)

	_graph_edit = GraphEdit.new()
	_graph_edit.name = "AssetGraph"
	_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.minimap_enabled = true
	_graph_edit.show_arrange_button = false
	_graph_edit.zoom_min = 0.02
	_graph_edit.connection_lines_curvature = 0.35
	_graph_edit.add_valid_connection_type(0, 0)
	add_child(_graph_edit)

	_export_dialog = EditorFileDialog.new()
	add_child(_export_dialog)
	_export_dialog.title = "Export Project Graph JSON"
	_export_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_export_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.filters = PackedStringArray(["*.json ; JSON files"])
	_export_dialog.current_file = "project-graph.json"
	_export_dialog.file_selected.connect(_export_json)

	_ignore_dialog = ConfirmationDialog.new()
	add_child(_ignore_dialog)
	_ignore_dialog.title = "Project Graph Scan Ignore"
	_ignore_dialog.confirmed.connect(_save_ignore_patterns)
	_ignore_dialog.get_ok_button().text = "Save and Rescan"

	var ignore_content := VBoxContainer.new()
	ignore_content.custom_minimum_size = Vector2(680.0, 420.0)
	ignore_content.add_theme_constant_override("separation", 8)
	_ignore_dialog.add_child(ignore_content)

	var default_heading := Label.new()
	default_heading.text = "Always ignored"
	ignore_content.add_child(default_heading)

	var default_patterns := Label.new()
	default_patterns.text = ScanIgnoreSettings.format_default_patterns()
	default_patterns.modulate = Color(1.0, 1.0, 1.0, 0.65)
	default_patterns.tooltip_text = (
		"Godot engine resources outside res:// never enter the project scan."
	)
	ignore_content.add_child(default_patterns)

	var custom_heading := Label.new()
	custom_heading.text = "Custom patterns · one per line"
	ignore_content.add_child(custom_heading)

	_ignore_editor = TextEdit.new()
	_ignore_editor.placeholder_text = (
		"Examples:\n"
		+ "res://third_party/**\n"
		+ "res://art/source/*.psd\n"
		+ "# Lines beginning with # are comments"
	)
	_ignore_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ignore_content.add_child(_ignore_editor)

	var ignore_help := Label.new()
	ignore_help.text = (
		"Patterns are stored in user://freshli4_project_graph/settings.cfg "
		+ "and applied before traversal and dependency collection."
	)
	ignore_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ignore_content.add_child(ignore_help)


func _scan_project() -> void:
	_scan_button.disabled = true
	_status_label.text = "Scanning project..."
	_snapshot = _scanner.scan_project("res://", _custom_ignore_patterns)
	_render_snapshot()
	_export_button.disabled = false
	_layout_button.disabled = false
	_scan_button.disabled = false
	_apply_search(_search_field.text)


func run_editor_smoke() -> void:
	_scan_project()
	var graph_node_count := 0
	var graph_positions: Dictionary = {}
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			graph_node_count += 1
			var graph_node := child as GraphNode
			graph_positions[graph_node.position_offset.round()] = true
	if graph_node_count > 0 and (
		graph_node_count == 1 or graph_positions.size() > 1
	):
		print("PASS: Project Graph editor panel smoke (%d graph nodes)" % graph_node_count)
	else:
		push_error("Project Graph editor panel smoke rendered an invalid layout")


func _render_snapshot() -> void:
	_clear_graph()
	var nodes: Array = _snapshot.get("nodes", [])
	for index: int in nodes.size():
		var node := nodes[index] as Dictionary
		var node_id := String(node.get("id", ""))

		var graph_name := StringName("asset_%05d" % index)
		var card := _make_card(node, graph_name)
		_graph_edit.add_child(card)
		_graph_names_by_id[node_id] = graph_name
		_cards_by_id[node_id] = card

	_apply_organic_layout(false)
	_fit_graph_to_view.call_deferred()


func _make_card(node: Dictionary, graph_name: StringName) -> GraphNode:
	var kind := String(node.get("kind", "Data"))
	var path := String(node.get("path", ""))
	var missing := bool(node.get("missing", false))
	var port_color := _color_for_kind(kind, missing)

	var card := GraphNode.new()
	card.name = graph_name
	card.title = String(node.get("label", path.get_file()))
	card.custom_minimum_size = CARD_SIZE
	card.resizable = true
	card.tooltip_text = path
	card.set_meta("asset_id", String(node.get("id", "")))
	card.set_meta("asset_path", path)
	card.gui_input.connect(_on_card_input.bind(card))

	var details := Label.new()
	details.text = "%s%s\n%s" % [
		kind,
		" · missing" if missing else "",
		path,
	]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = CARD_SIZE - Vector2(24.0, 34.0)
	details.modulate = port_color
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(details)
	card.set_slot(0, true, 0, port_color, true, 0, port_color)
	return card


func _clear_graph() -> void:
	_graph_edit.clear_connections()
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			_graph_edit.remove_child(child)
			child.queue_free()
	_graph_names_by_id.clear()
	_cards_by_id.clear()


func _refresh_connections() -> void:
	_graph_edit.clear_connections()
	var edges: Array = _snapshot.get("edges", [])
	for edge_value: Variant in edges:
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		if (
			not _graph_names_by_id.has(source_id)
			or not _graph_names_by_id.has(target_id)
		):
			continue
		var source_card := _cards_by_id[source_id] as GraphNode
		var target_card := _cards_by_id[target_id] as GraphNode
		if not source_card.visible or not target_card.visible:
			continue
		_graph_edit.connect_node(
			_graph_names_by_id[source_id],
			0,
			_graph_names_by_id[target_id],
			0,
			true,
		)


func _apply_organic_layout(fit_view: bool = true) -> void:
	if _snapshot.is_empty():
		return
	var result := _layout.calculate(_snapshot, CARD_SIZE)
	var positions := result.get("positions", {}) as Dictionary
	for node_id: String in _cards_by_id:
		var card := _cards_by_id[node_id] as GraphNode
		card.position_offset = positions.get(node_id, Vector2.ZERO)
	_refresh_connections()
	if fit_view:
		_fit_graph_to_view.call_deferred()


func _fit_graph_to_view() -> void:
	if _cards_by_id.is_empty() or _graph_edit.size.x <= 1.0 or _graph_edit.size.y <= 1.0:
		return
	var bounds := Rect2()
	var has_bounds := false
	for node_id: String in _cards_by_id:
		var card := _cards_by_id[node_id] as GraphNode
		if not card.visible:
			continue
		var card_size := card.size if card.size.length_squared() > 1.0 else CARD_SIZE
		var card_bounds := Rect2(card.position_offset, card_size)
		if has_bounds:
			bounds = bounds.merge(card_bounds)
		else:
			bounds = card_bounds
			has_bounds = true
	if not has_bounds:
		return

	var viewport_size := _graph_edit.size - Vector2(96.0, 96.0)
	var target_zoom := minf(
		viewport_size.x / maxf(bounds.size.x, 1.0),
		viewport_size.y / maxf(bounds.size.y, 1.0),
	)
	_graph_edit.zoom = clampf(target_zoom, _graph_edit.zoom_min, 1.0)
	_graph_edit.scroll_offset = (
		bounds.get_center()
		- _graph_edit.size / (2.0 * _graph_edit.zoom)
	)


func _apply_search(raw_query: String) -> void:
	var query := raw_query.strip_edges().to_lower()
	var visible_count := 0
	for node_id: String in _cards_by_id:
		var card := _cards_by_id[node_id] as GraphNode
		var node := _find_node(node_id)
		var searchable := "%s %s %s" % [
			String(node.get("label", "")),
			String(node.get("path", "")),
			String(node.get("kind", "")),
		]
		card.visible = query.is_empty() or searchable.to_lower().contains(query)
		if card.visible:
			visible_count += 1
	_refresh_connections()
	if _snapshot.is_empty():
		_status_label.text = "Ready. Click Scan Project."
	else:
		var stats := _snapshot.get("stats", {}) as Dictionary
		_status_label.text = "%d/%d nodes · %d edges · %d missing" % [
			visible_count,
			int(stats.get("node_count", 0)),
			int(stats.get("edge_count", 0)),
			int(stats.get("missing_node_count", 0)),
		]


func _find_node(node_id: String) -> Dictionary:
	var nodes: Array = _snapshot.get("nodes", [])
	for node_value: Variant in nodes:
		var node := node_value as Dictionary
		if String(node.get("id", "")) == node_id:
			return node
	return {}


func _on_card_input(event: InputEvent, card: GraphNode) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.double_click
	):
		asset_activated.emit(String(card.get_meta("asset_path", "")))
		card.accept_event()


func _show_export_dialog() -> void:
	if _snapshot.is_empty():
		return
	_export_dialog.popup_centered_ratio(0.7)


func _show_ignore_dialog() -> void:
	_ignore_editor.text = ScanIgnoreSettings.format_text(_custom_ignore_patterns)
	_ignore_dialog.popup_centered(Vector2i(720, 520))
	_ignore_editor.grab_focus()


func _save_ignore_patterns() -> void:
	var patterns := ScanIgnoreSettings.parse_text(_ignore_editor.text)
	var result := ScanIgnoreSettings.save_custom_patterns(patterns)
	if result != OK:
		_status_label.text = "Could not save Ignore settings: %s" % error_string(result)
		push_error("Project Graph Ignore settings failed: %s" % error_string(result))
		return
	_custom_ignore_patterns = patterns
	_scan_project()


func _export_json(path: String) -> void:
	var result := GraphStore.save_json(_snapshot, path)
	if result == OK:
		_status_label.text = "Exported %s" % path
	else:
		_status_label.text = "Export failed: %s" % error_string(result)
		push_error("Project Graph export failed: %s" % error_string(result))


func _color_for_kind(kind: String, missing: bool) -> Color:
	if missing:
		return Color("#EB5757")
	match kind:
		"Scene":
			return Color("#5DA9E9")
		"Script":
			return Color("#F2C94C")
		"Resource":
			return Color("#BB86FC")
		"Mesh":
			return Color("#56CC9D")
		"Texture":
			return Color("#F2994A")
		"Audio":
			return Color("#EB6F92")
		"Shader":
			return Color("#6FCFDE")
		_:
			return Color("#A0AEC0")

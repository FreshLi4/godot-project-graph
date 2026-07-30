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
const SemanticConnectionLayer = preload(
	"res://addons/freshli4_project_graph/ui/semantic_connection_layer.gd"
)

const CARD_SIZE := Vector2(320.0, 190.0)
const CARD_BODY_SIZE := Vector2(292.0, 128.0)
const TITLE_VIEW_WIDTH := 250.0
const MIN_VISIBLE_CONNECTION_GAP := 64.0

var _scanner := ProjectGraphScanner.new()
var _layout := OrganicGraphLayout.new()
var _snapshot: Dictionary = {}
var _graph_names_by_id: Dictionary = {}
var _cards_by_id: Dictionary = {}
var _title_widgets_by_id: Dictionary = {}
var _selected_title_ids: Dictionary = {}
var _title_tweens_by_id: Dictionary = {}
var _hovered_title_id := ""
var _custom_ignore_patterns := PackedStringArray()

var _scan_button: Button
var _layout_button: Button
var _ignore_button: Button
var _legend_button: Button
var _export_button: Button
var _search_field: LineEdit
var _status_label: Label
var _graph_edit: GraphEdit
var _connection_layer: Control
var _export_dialog: EditorFileDialog
var _ignore_dialog: ConfirmationDialog
var _ignore_editor: TextEdit
var _legend_dialog: AcceptDialog
var _title_popup: PopupPanel
var _title_popup_label: Label


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

	_legend_button = Button.new()
	_legend_button.text = "Legend…"
	_legend_button.tooltip_text = (
		"Node colors identify asset types. "
		+ "Arrow color and line style identify relationship semantics."
	)
	_legend_button.pressed.connect(_show_legend_dialog)
	toolbar.add_child(_legend_button)

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
	_graph_edit.node_selected.connect(_on_node_selected)
	_graph_edit.node_deselected.connect(_on_node_deselected)
	add_child(_graph_edit)

	_connection_layer = SemanticConnectionLayer.new()
	_connection_layer.name = "SemanticConnections"
	_connection_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_edit.add_child(_connection_layer)

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

	_build_legend_dialog()
	_build_title_popup()


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
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_organic_layout(false)
	await get_tree().process_frame
	var graph_node_count := 0
	var graph_positions: Dictionary = {}
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			graph_node_count += 1
			var graph_node := child as GraphNode
			graph_positions[graph_node.position_offset.round()] = true
	if (
		graph_node_count > 0
		and (graph_node_count == 1 or graph_positions.size() > 1)
		and _cards_have_fixed_size()
		and _rendered_cards_have_clearance(MIN_VISIBLE_CONNECTION_GAP)
		and _semantic_ui_is_valid()
	):
		print("PASS: Project Graph editor panel smoke (%d graph nodes)" % graph_node_count)
	else:
		push_error(
			"Project Graph editor panel smoke rendered overlapping or invalid cards"
		)


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
	_finalize_fixed_card_layout.call_deferred()


func _make_card(node: Dictionary, graph_name: StringName) -> GraphNode:
	var kind := String(node.get("kind", "Data"))
	var path := String(node.get("path", ""))
	var missing := bool(node.get("missing", false))
	var port_color := _color_for_kind(kind, missing)

	var card := GraphNode.new()
	card.name = graph_name
	card.title = ""
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.resizable = false
	card.tooltip_text = path
	var node_id := String(node.get("id", ""))
	var title := String(node.get("label", path.get_file()))
	card.set_meta("asset_id", node_id)
	card.set_meta("asset_path", path)
	card.set_meta("fixed_card_size", CARD_SIZE)
	card.gui_input.connect(_on_card_input.bind(card))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(node_id, title))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(node_id))

	var titlebar := card.get_titlebar_hbox()
	for child: Node in titlebar.get_children():
		if child is Label:
			(child as Label).visible = false

	var ellipsis_title := Label.new()
	ellipsis_title.text = title
	ellipsis_title.custom_minimum_size = Vector2(TITLE_VIEW_WIDTH, 24.0)
	ellipsis_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ellipsis_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ellipsis_title.clip_text = true
	ellipsis_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titlebar.add_child(ellipsis_title)

	var title_scroll := ScrollContainer.new()
	title_scroll.custom_minimum_size = Vector2(TITLE_VIEW_WIDTH, 24.0)
	title_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	title_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	title_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_scroll.visible = false
	titlebar.add_child(title_scroll)

	var full_title := Label.new()
	full_title.text = title
	full_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_scroll.add_child(full_title)
	_title_widgets_by_id[node_id] = {
		"ellipsis": ellipsis_title,
		"scroll": title_scroll,
		"full": full_title,
	}

	var body_scroll := ScrollContainer.new()
	body_scroll.custom_minimum_size = CARD_BODY_SIZE
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.set_meta("card_body_scroll", true)
	card.add_child(body_scroll)

	var details := Label.new()
	details.text = "%s%s\n%s" % [
		kind,
		" · missing" if missing else "",
		path,
	]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = CARD_BODY_SIZE.x - 16.0
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.modulate = port_color
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_scroll.add_child(details)
	return card


func _clear_graph() -> void:
	_graph_edit.clear_connections()
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			_graph_edit.remove_child(child)
			child.queue_free()
	_graph_names_by_id.clear()
	_cards_by_id.clear()
	_title_widgets_by_id.clear()
	_selected_title_ids.clear()
	_stop_all_title_tweens()
	_connection_layer.configure(_graph_edit, _cards_by_id, [])


func _refresh_connections() -> void:
	_graph_edit.clear_connections()
	var visible_edges: Array = []
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
		visible_edges.append(edge)
	_connection_layer.configure(_graph_edit, _cards_by_id, visible_edges)


func _apply_organic_layout(fit_view: bool = true) -> void:
	if _snapshot.is_empty():
		return
	var result := _layout.calculate(_snapshot, CARD_SIZE)
	var positions := result.get("positions", {}) as Dictionary
	for node_id: String in _cards_by_id:
		var card := _cards_by_id[node_id] as GraphNode
		card.size = CARD_SIZE
		card.position_offset = positions.get(node_id, Vector2.ZERO)
	_refresh_connections()
	if fit_view:
		_fit_graph_to_view.call_deferred()


func _finalize_fixed_card_layout() -> void:
	await get_tree().process_frame
	if _snapshot.is_empty():
		return
	_apply_organic_layout(false)
	_fit_graph_to_view.call_deferred()


func _measure_card(card: GraphNode) -> Vector2:
	return card.size if card.size.length_squared() > 1.0 else CARD_SIZE


func _cards_have_fixed_size() -> bool:
	for card_value: Variant in _cards_by_id.values():
		var card := card_value as GraphNode
		if not card.size.is_equal_approx(CARD_SIZE):
			return false
		var body_scroll := _find_card_body_scroll(card)
		if body_scroll == null:
			return false
	return true


func _semantic_ui_is_valid() -> bool:
	if _graph_edit.get_connection_list().size() != 0:
		return false
	if _title_widgets_by_id.size() != _cards_by_id.size():
		return false
	var found_inheritance := false
	for edge_value: Variant in _snapshot.get("edges", []):
		var edge := edge_value as Dictionary
		if String(edge.get("relation", "")) != "inherits":
			continue
		found_inheritance = true
		var style := SemanticConnectionLayer.edge_style(edge)
		if (
			bool(style.get("dashed", true))
			or String(style.get("semantic", "")) != "inherits"
		):
			return false
	return found_inheritance


func _find_card_body_scroll(card: GraphNode) -> ScrollContainer:
	for child: Node in card.get_children():
		if child is ScrollContainer and bool(child.get_meta("card_body_scroll", false)):
			return child as ScrollContainer
	return null


func _rendered_cards_have_clearance(minimum_clearance: float) -> bool:
	var node_ids: Array = _cards_by_id.keys()
	for left_index: int in node_ids.size():
		var left_card := _cards_by_id[String(node_ids[left_index])] as GraphNode
		if not left_card.visible:
			continue
		var left_rect := Rect2(left_card.position_offset, _measure_card(left_card))
		for right_index: int in range(left_index + 1, node_ids.size()):
			var right_card := _cards_by_id[String(node_ids[right_index])] as GraphNode
			if not right_card.visible:
				continue
			var right_rect := Rect2(
				right_card.position_offset,
				_measure_card(right_card),
			)
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


func _on_card_mouse_entered(node_id: String, title: String) -> void:
	_hovered_title_id = node_id
	_set_title_reveal(node_id, true)
	_show_title_popup(title)


func _on_card_mouse_exited(node_id: String) -> void:
	if _hovered_title_id == node_id:
		_hovered_title_id = ""
	if not _selected_title_ids.has(node_id):
		_set_title_reveal(node_id, false)
	_title_popup.hide()


func _on_node_selected(node: Node) -> void:
	var card := node as GraphNode
	if card == null:
		return
	var node_id := String(card.get_meta("asset_id", ""))
	_selected_title_ids[node_id] = true
	_set_title_reveal(node_id, true)


func _on_node_deselected(node: Node) -> void:
	var card := node as GraphNode
	if card == null:
		return
	var node_id := String(card.get_meta("asset_id", ""))
	_selected_title_ids.erase(node_id)
	if _hovered_title_id != node_id:
		_set_title_reveal(node_id, false)


func _set_title_reveal(node_id: String, reveal: bool) -> void:
	if not _title_widgets_by_id.has(node_id):
		return
	var widgets := _title_widgets_by_id[node_id] as Dictionary
	var ellipsis_title := widgets["ellipsis"] as Label
	var title_scroll := widgets["scroll"] as ScrollContainer
	ellipsis_title.visible = not reveal
	title_scroll.visible = reveal
	if reveal:
		_start_title_marquee.call_deferred(node_id)
	else:
		_stop_title_tween(node_id)
		title_scroll.scroll_horizontal = 0


func _start_title_marquee(node_id: String) -> void:
	await get_tree().process_frame
	if not _title_widgets_by_id.has(node_id):
		return
	if _hovered_title_id != node_id and not _selected_title_ids.has(node_id):
		return
	_stop_title_tween(node_id)
	var widgets := _title_widgets_by_id[node_id] as Dictionary
	var title_scroll := widgets["scroll"] as ScrollContainer
	var full_title := widgets["full"] as Label
	var maximum_scroll := maxi(
		0,
		ceili(full_title.get_combined_minimum_size().x - title_scroll.size.x),
	)
	title_scroll.scroll_horizontal = 0
	if maximum_scroll <= 0:
		return
	var duration := maxf(1.2, float(maximum_scroll) / 55.0)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_interval(0.45)
	tween.tween_property(
		title_scroll,
		"scroll_horizontal",
		maximum_scroll,
		duration,
	).set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(0.65)
	tween.tween_property(
		title_scroll,
		"scroll_horizontal",
		0,
		duration,
	).set_trans(Tween.TRANS_LINEAR)
	_title_tweens_by_id[node_id] = tween


func _stop_title_tween(node_id: String) -> void:
	if not _title_tweens_by_id.has(node_id):
		return
	var tween := _title_tweens_by_id[node_id] as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_title_tweens_by_id.erase(node_id)


func _stop_all_title_tweens() -> void:
	for node_id_value: Variant in _title_tweens_by_id.keys():
		_stop_title_tween(String(node_id_value))


func _build_title_popup() -> void:
	_title_popup = PopupPanel.new()
	_title_popup.transient = true
	_title_popup.unresizable = true
	add_child(_title_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_title_popup.add_child(margin)

	_title_popup_label = Label.new()
	_title_popup_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_popup_label.custom_minimum_size.y = 24.0
	margin.add_child(_title_popup_label)


func _show_title_popup(title: String) -> void:
	_title_popup_label.text = title
	var popup_width := clampi(
		ceili(_title_popup_label.get_theme_default_font().get_string_size(
			title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			_title_popup_label.get_theme_default_font_size(),
		).x) + 32,
		180,
		560,
	)
	var mouse_position := Vector2i(get_viewport().get_mouse_position().round())
	_title_popup.popup(
		Rect2i(
			mouse_position + Vector2i(18, 20),
			Vector2i(popup_width, 48),
		)
	)


func _build_legend_dialog() -> void:
	_legend_dialog = AcceptDialog.new()
	_legend_dialog.title = "Project Graph Legend"
	_legend_dialog.get_ok_button().text = "Close"
	add_child(_legend_dialog)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(660.0, 520.0)
	content.add_theme_constant_override("separation", 10)
	_legend_dialog.add_child(content)

	var edge_heading := Label.new()
	edge_heading.text = "Relationship lines"
	content.add_child(edge_heading)

	var edge_legend := RichTextLabel.new()
	edge_legend.bbcode_enabled = true
	edge_legend.fit_content = true
	edge_legend.custom_minimum_size.y = 118.0
	edge_legend.text = (
		"[color=#B8C0CC]━━━━▶[/color]  Static reference · source uses target\n"
		+ "[color=#6FCFDE]━━━━▶[/color]  Inheritance · child points to parent; "
		+ "higher ancestors are pulled toward the center\n"
		+ "[color=#F2B84B]━ ━ ━▶[/color]  Inferred / dynamic · not an exact "
		+ "static dependency\n\n"
		+ "Arrowheads always point from the relationship source to its target."
	)
	content.add_child(edge_legend)

	var node_heading := Label.new()
	node_heading.text = "Asset node colors"
	content.add_child(node_heading)

	var node_grid := GridContainer.new()
	node_grid.columns = 2
	node_grid.add_theme_constant_override("h_separation", 12)
	node_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(node_grid)
	for kind: String in [
		"Scene",
		"Script",
		"Resource",
		"Mesh",
		"Texture",
		"Audio",
		"Shader",
		"Data",
	]:
		_add_legend_color_row(node_grid, kind, _color_for_kind(kind, false))
	_add_legend_color_row(node_grid, "Missing / broken", _color_for_kind("Data", true))

	var explanation := Label.new()
	explanation.text = (
		"Blue means Scene only. Node colors never encode direction or confidence; "
		+ "those meanings belong exclusively to the relationship lines above."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)


func _add_legend_color_row(
	grid: GridContainer,
	label_text: String,
	color: Color,
) -> void:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(22.0, 18.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(swatch)
	var label := Label.new()
	label.text = "%s · %s" % [label_text, color.to_html(false)]
	grid.add_child(label)


func _show_legend_dialog() -> void:
	_legend_dialog.popup_centered(Vector2i(700, 580))


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

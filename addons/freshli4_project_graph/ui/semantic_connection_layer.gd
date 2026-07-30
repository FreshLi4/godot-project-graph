@tool
extends Control

const REFERENCE_COLOR := Color("#B8C0CC")
const INHERITANCE_COLOR := Color("#6FCFDE")
const INFERRED_COLOR := Color("#F2B84B")
const LINE_WIDTH := 2.2
const DASH_LENGTH := 11.0
const DASH_GAP := 7.0
const ARROW_LENGTH := 12.0
const ARROW_HALF_WIDTH := 5.5

var _graph_edit: GraphEdit
var _cards_by_id: Dictionary = {}
var _edges: Array = []


func configure(
	graph_edit: GraphEdit,
	cards_by_id: Dictionary,
	edges: Array,
) -> void:
	_graph_edit = graph_edit
	_cards_by_id = cards_by_id
	_edges = edges.duplicate(true)
	_track_geometry_changes()
	queue_redraw()


static func edge_style(edge: Dictionary) -> Dictionary:
	var relation := String(edge.get("relation", "references"))
	var confidence := String(edge.get("confidence", "exact"))
	var origin := String(edge.get("origin", "")).to_lower()
	var metadata := edge.get("metadata", {}) as Dictionary
	var inferred := (
		confidence != "exact"
		or relation == "creates"
		or origin.contains("runtime")
		or origin.contains("dynamic")
		or bool(metadata.get("dynamic", false))
	)
	if inferred:
		return {
			"color": INFERRED_COLOR,
			"dashed": true,
			"arrow": true,
			"semantic": "inferred_dynamic",
		}
	if relation == "inherits":
		return {
			"color": INHERITANCE_COLOR,
			"dashed": false,
			"arrow": true,
			"semantic": "inherits",
		}
	return {
		"color": REFERENCE_COLOR,
		"dashed": false,
		"arrow": true,
		"semantic": "references",
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _graph_edit != null:
		_track_geometry_changes()


func _draw() -> void:
	if _graph_edit == null:
		return
	for edge_value: Variant in _edges:
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		if not _cards_by_id.has(source_id) or not _cards_by_id.has(target_id):
			continue
		var source_card := _cards_by_id[source_id] as GraphNode
		var target_card := _cards_by_id[target_id] as GraphNode
		if (
			not is_instance_valid(source_card)
			or not is_instance_valid(target_card)
			or not source_card.visible
			or not target_card.visible
		):
			continue
		_draw_edge(
			_card_rect_in_layer(source_card),
			_card_rect_in_layer(target_card),
			edge_style(edge),
		)


func _draw_edge(
	source_rect: Rect2,
	target_rect: Rect2,
	style: Dictionary,
) -> void:
	var source_center := source_rect.get_center()
	var target_center := target_rect.get_center()
	var direction := target_center - source_center
	if direction.length_squared() < 1.0:
		return
	direction = direction.normalized()
	var start := _rect_boundary(source_rect, direction)
	var finish := _rect_boundary(target_rect, -direction)
	var color := style.get("color", REFERENCE_COLOR) as Color
	if bool(style.get("dashed", false)):
		_draw_dashed_segment(start, finish, color)
	else:
		draw_line(start, finish, color, LINE_WIDTH, true)
	if bool(style.get("arrow", true)):
		_draw_arrow(finish, direction, color)


func _draw_dashed_segment(start: Vector2, finish: Vector2, color: Color) -> void:
	var delta := finish - start
	var distance := delta.length()
	if distance <= 0.01:
		return
	var direction := delta / distance
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(cursor + DASH_LENGTH, distance)
		draw_line(
			start + direction * cursor,
			start + direction * segment_end,
			color,
			LINE_WIDTH,
			true,
		)
		cursor += DASH_LENGTH + DASH_GAP


func _draw_arrow(tip: Vector2, direction: Vector2, color: Color) -> void:
	var perpendicular := Vector2(-direction.y, direction.x)
	var base_center := tip - direction * ARROW_LENGTH
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			base_center + perpendicular * ARROW_HALF_WIDTH,
			base_center - perpendicular * ARROW_HALF_WIDTH,
		]),
		color,
	)


func _rect_boundary(rect: Rect2, direction: Vector2) -> Vector2:
	var half := rect.size / 2.0
	var x_scale := INF if absf(direction.x) < 0.0001 else half.x / absf(direction.x)
	var y_scale := INF if absf(direction.y) < 0.0001 else half.y / absf(direction.y)
	return rect.get_center() + direction * minf(x_scale, y_scale)


func _card_rect_in_layer(card: GraphNode) -> Rect2:
	var card_to_layer := get_global_transform().affine_inverse() * card.get_global_transform()
	var top_left := card_to_layer * Vector2.ZERO
	var bottom_right := card_to_layer * card.size
	return Rect2(top_left, bottom_right - top_left).abs()


func _track_geometry_changes() -> void:
	if _graph_edit != null:
		if not _graph_edit.resized.is_connected(_on_geometry_changed):
			_graph_edit.resized.connect(_on_geometry_changed)
		if (
			_graph_edit.has_signal("scroll_offset_changed")
			and not _graph_edit.is_connected(
				"scroll_offset_changed",
				_on_scroll_offset_changed,
			)
		):
			_graph_edit.connect("scroll_offset_changed", _on_scroll_offset_changed)
	for card_value: Variant in _cards_by_id.values():
		var card := card_value as GraphNode
		if not is_instance_valid(card):
			continue
		if not card.item_rect_changed.is_connected(_on_geometry_changed):
			card.item_rect_changed.connect(_on_geometry_changed)
		if not card.visibility_changed.is_connected(_on_geometry_changed):
			card.visibility_changed.connect(_on_geometry_changed)


func _on_geometry_changed() -> void:
	queue_redraw()


func _on_scroll_offset_changed(_offset: Vector2) -> void:
	queue_redraw()

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
const ROUTE_CLEARANCE := 14.0
const ROUTE_EPSILON := 0.5

var _graph_edit: GraphEdit
var _cards_by_id: Dictionary = {}
var _edges: Array = []
var _routes: Array = []
var _routes_dirty := true
var _routing_metrics: Dictionary = {}
var _last_zoom := -1.0
var _last_scroll_offset := Vector2(INF, INF)


func configure(
	graph_edit: GraphEdit,
	cards_by_id: Dictionary,
	edges: Array,
) -> void:
	_graph_edit = graph_edit
	_cards_by_id = cards_by_id
	_edges = edges.duplicate(true)
	_routes_dirty = true
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


static func route_around_obstacles(
	source_rect: Rect2,
	target_rect: Rect2,
	obstacle_rects: Array,
	clearance: float = ROUTE_CLEARANCE,
) -> PackedVector2Array:
	var source := source_rect.abs()
	var target := target_rect.abs()
	var source_center := source.get_center()
	var target_center := target.get_center()
	if source_center.distance_squared_to(target_center) < 1.0:
		return PackedVector2Array()

	var obstacles: Array = []
	for obstacle_value: Variant in obstacle_rects:
		var obstacle := (obstacle_value as Rect2).abs()
		if obstacle.size.x <= 0.0 or obstacle.size.y <= 0.0:
			continue
		obstacles.append(obstacle.grow(clearance))

	var direct_blocker := _first_blocking_obstacle(
		source_center,
		target_center,
		obstacles,
	)
	if direct_blocker < 0:
		return PackedVector2Array([
			_rect_boundary(source, (target_center - source_center).normalized()),
			_rect_boundary(target, (source_center - target_center).normalized()),
		])

	var relevant: Dictionary = {direct_blocker: true}
	while relevant.size() <= obstacles.size():
		var points := PackedVector2Array([source_center, target_center])
		var relevant_indices: Array = relevant.keys()
		relevant_indices.sort()
		for obstacle_index_value: Variant in relevant_indices:
			var obstacle_index := int(obstacle_index_value)
			var obstacle := obstacles[obstacle_index] as Rect2
			points.append(obstacle.position)
			points.append(Vector2(obstacle.end.x, obstacle.position.y))
			points.append(obstacle.end)
			points.append(Vector2(obstacle.position.x, obstacle.end.y))

		var graph := _build_visibility_graph(points, obstacles, relevant)
		var route_indices := _shortest_path(graph.get("neighbors", []), points, 0, 1)
		if not route_indices.is_empty():
			var route := PackedVector2Array()
			for point_index: int in route_indices:
				route.append(points[point_index])
			route = _clip_route_to_cards(route, source, target)
			route = _remove_collinear_points(route)
			if polyline_avoids_rects(route, obstacle_rects, clearance):
				return route

		var discovered := graph.get("discovered", {}) as Dictionary
		var added := false
		for obstacle_index_value: Variant in discovered:
			var obstacle_index := int(obstacle_index_value)
			if not relevant.has(obstacle_index):
				relevant[obstacle_index] = true
				added = true
		if not added:
			break
	return PackedVector2Array()


static func polyline_avoids_rects(
	route: PackedVector2Array,
	obstacle_rects: Array,
	clearance: float = ROUTE_CLEARANCE,
) -> bool:
	if route.size() < 2:
		return false
	for point_index: int in route.size() - 1:
		var start := route[point_index]
		var finish := route[point_index + 1]
		for obstacle_value: Variant in obstacle_rects:
			var obstacle := (obstacle_value as Rect2).abs().grow(clearance)
			if _segment_crosses_rect_interior(start, finish, obstacle):
				return false
	return true


static func _build_visibility_graph(
	points: PackedVector2Array,
	obstacles: Array,
	relevant: Dictionary,
) -> Dictionary:
	var neighbors: Array = []
	for _point: Vector2 in points:
		neighbors.append([])
	var discovered: Dictionary = {}
	for left_index: int in points.size():
		for right_index: int in range(left_index + 1, points.size()):
			var blocker := _first_blocking_obstacle(
				points[left_index],
				points[right_index],
				obstacles,
			)
			if blocker >= 0:
				if not relevant.has(blocker):
					discovered[blocker] = true
				continue
			var distance := points[left_index].distance_to(points[right_index])
			(neighbors[left_index] as Array).append({
				"to": right_index,
				"distance": distance,
			})
			(neighbors[right_index] as Array).append({
				"to": left_index,
				"distance": distance,
			})
	return {
		"neighbors": neighbors,
		"discovered": discovered,
	}


static func _shortest_path(
	neighbors: Array,
	points: PackedVector2Array,
	start_index: int,
	target_index: int,
) -> PackedInt32Array:
	var count := points.size()
	var distances := PackedFloat64Array()
	var previous := PackedInt32Array()
	var visited := PackedByteArray()
	distances.resize(count)
	previous.resize(count)
	visited.resize(count)
	for index: int in count:
		distances[index] = INF
		previous[index] = -1
	distances[start_index] = 0.0

	for _step: int in count:
		var current := -1
		var current_distance := INF
		for index: int in count:
			if visited[index] == 0 and distances[index] < current_distance:
				current = index
				current_distance = distances[index]
		if current < 0:
			break
		if current == target_index:
			break
		visited[current] = 1
		for neighbor_value: Variant in neighbors[current]:
			var neighbor := neighbor_value as Dictionary
			var next_index := int(neighbor.get("to", -1))
			var candidate := current_distance + float(neighbor.get("distance", INF))
			if candidate + 0.001 < distances[next_index]:
				distances[next_index] = candidate
				previous[next_index] = current

	if not is_finite(distances[target_index]):
		return PackedInt32Array()
	var reversed := PackedInt32Array()
	var cursor := target_index
	while cursor >= 0:
		reversed.append(cursor)
		if cursor == start_index:
			break
		cursor = previous[cursor]
	if reversed.is_empty() or reversed[reversed.size() - 1] != start_index:
		return PackedInt32Array()
	reversed.reverse()
	return reversed


static func _clip_route_to_cards(
	route: PackedVector2Array,
	source_rect: Rect2,
	target_rect: Rect2,
) -> PackedVector2Array:
	if route.size() < 2:
		return PackedVector2Array()
	var source_direction := route[1] - source_rect.get_center()
	var target_direction := route[route.size() - 2] - target_rect.get_center()
	if source_direction.length_squared() < 0.001 or target_direction.length_squared() < 0.001:
		return PackedVector2Array()
	route[0] = _rect_boundary(source_rect, source_direction.normalized())
	route[route.size() - 1] = _rect_boundary(target_rect, target_direction.normalized())
	return route


static func _remove_collinear_points(route: PackedVector2Array) -> PackedVector2Array:
	if route.size() <= 2:
		return route
	var result := PackedVector2Array([route[0]])
	for index: int in range(1, route.size() - 1):
		var previous_direction := route[index] - result[result.size() - 1]
		var next_direction := route[index + 1] - route[index]
		if (
			previous_direction.length_squared() > 0.001
			and next_direction.length_squared() > 0.001
			and absf(previous_direction.normalized().cross(next_direction.normalized())) < 0.001
			and previous_direction.dot(next_direction) > 0.0
		):
			continue
		result.append(route[index])
	result.append(route[route.size() - 1])
	return result


static func _first_blocking_obstacle(
	start: Vector2,
	finish: Vector2,
	obstacles: Array,
) -> int:
	for obstacle_index: int in obstacles.size():
		if _segment_crosses_rect_interior(
			start,
			finish,
			obstacles[obstacle_index] as Rect2,
		):
			return obstacle_index
	return -1


static func _segment_crosses_rect_interior(
	start: Vector2,
	finish: Vector2,
	rect: Rect2,
) -> bool:
	var inner := rect.abs().grow(-ROUTE_EPSILON)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return false
	var delta := finish - start
	var minimum_t := 0.0
	var maximum_t := 1.0
	for axis: int in 2:
		var origin := start[axis]
		var direction := delta[axis]
		var lower := inner.position[axis]
		var upper := inner.end[axis]
		if absf(direction) < 0.000001:
			if origin <= lower or origin >= upper:
				return false
			continue
		var first := (lower - origin) / direction
		var second := (upper - origin) / direction
		if first > second:
			var swap := first
			first = second
			second = swap
		minimum_t = maxf(minimum_t, first)
		maximum_t = minf(maximum_t, second)
		if maximum_t <= minimum_t:
			return false
	return maximum_t > 0.0001 and minimum_t < 0.9999


static func _rect_boundary(rect: Rect2, direction: Vector2) -> Vector2:
	var half := rect.size / 2.0
	var x_scale := INF if absf(direction.x) < 0.0001 else half.x / absf(direction.x)
	var y_scale := INF if absf(direction.y) < 0.0001 else half.y / absf(direction.y)
	return rect.get_center() + direction * minf(x_scale, y_scale)


func get_routing_metrics() -> Dictionary:
	_ensure_routes()
	return _routing_metrics.duplicate(true)


func all_routes_clear() -> bool:
	_ensure_routes()
	return (
		int(_routing_metrics.get("routed_edge_count", -1))
		== int(_routing_metrics.get("edge_count", -2))
		and int(_routing_metrics.get("blocked_route_count", 1)) == 0
	)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	if _graph_edit != null:
		_track_geometry_changes()


func _process(_delta: float) -> void:
	if _graph_edit == null:
		return
	if (
		not is_equal_approx(_last_zoom, _graph_edit.zoom)
		or not _last_scroll_offset.is_equal_approx(_graph_edit.scroll_offset)
	):
		_last_zoom = _graph_edit.zoom
		_last_scroll_offset = _graph_edit.scroll_offset
		queue_redraw()


func _draw() -> void:
	if _graph_edit == null:
		return
	_ensure_routes()
	for route_value: Variant in _routes:
		var route_data := route_value as Dictionary
		var graph_route := route_data.get("points", PackedVector2Array()) as PackedVector2Array
		var source_card := route_data.get("source_card") as GraphNode
		if graph_route.size() < 2 or not is_instance_valid(source_card):
			continue
		var canvas_route := _graph_route_to_layer(graph_route, source_card)
		var style := route_data.get("style", {}) as Dictionary
		var color := style.get("color", REFERENCE_COLOR) as Color
		if bool(style.get("dashed", false)):
			_draw_dashed_polyline(canvas_route, color)
		else:
			draw_polyline(canvas_route, color, LINE_WIDTH, true)
		if bool(style.get("arrow", true)):
			var direction := (
				canvas_route[canvas_route.size() - 1]
				- canvas_route[canvas_route.size() - 2]
			).normalized()
			_draw_arrow(canvas_route[canvas_route.size() - 1], direction, color)


func _ensure_routes() -> void:
	if not _routes_dirty:
		return
	_routes_dirty = false
	_routes.clear()
	var blocked_route_count := 0
	var detoured_edge_count := 0
	for edge_value: Variant in _edges:
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		if not _cards_by_id.has(source_id) or not _cards_by_id.has(target_id):
			blocked_route_count += 1
			continue
		var source_card := _cards_by_id[source_id] as GraphNode
		var target_card := _cards_by_id[target_id] as GraphNode
		if (
			not is_instance_valid(source_card)
			or not is_instance_valid(target_card)
			or not source_card.visible
			or not target_card.visible
		):
			blocked_route_count += 1
			continue
		var obstacle_rects: Array = []
		for obstacle_id_value: Variant in _cards_by_id:
			var obstacle_id := String(obstacle_id_value)
			if obstacle_id == source_id or obstacle_id == target_id:
				continue
			var obstacle_card := _cards_by_id[obstacle_id] as GraphNode
			if is_instance_valid(obstacle_card) and obstacle_card.visible:
				obstacle_rects.append(_card_rect_in_graph(obstacle_card))
		var route := route_around_obstacles(
			_card_rect_in_graph(source_card),
			_card_rect_in_graph(target_card),
			obstacle_rects,
		)
		if (
			route.size() < 2
			or not polyline_avoids_rects(route, obstacle_rects)
		):
			blocked_route_count += 1
			continue
		if route.size() > 2:
			detoured_edge_count += 1
		_routes.append({
			"points": route,
			"source_card": source_card,
			"style": edge_style(edge),
		})
	_routing_metrics = {
		"edge_count": _edges.size(),
		"routed_edge_count": _routes.size(),
		"blocked_route_count": blocked_route_count,
		"detoured_edge_count": detoured_edge_count,
	}


func _draw_dashed_polyline(points: PackedVector2Array, color: Color) -> void:
	var pattern_cursor := 0.0
	var drawing := true
	for point_index: int in points.size() - 1:
		var start := points[point_index]
		var finish := points[point_index + 1]
		var delta := finish - start
		var distance := delta.length()
		if distance <= 0.01:
			continue
		var direction := delta / distance
		var segment_cursor := 0.0
		while segment_cursor < distance:
			var phase_length := DASH_LENGTH if drawing else DASH_GAP
			var remaining_phase := phase_length - pattern_cursor
			var advance := minf(remaining_phase, distance - segment_cursor)
			if drawing:
				draw_line(
					start + direction * segment_cursor,
					start + direction * (segment_cursor + advance),
					color,
					LINE_WIDTH,
					true,
				)
			segment_cursor += advance
			pattern_cursor += advance
			if pattern_cursor >= phase_length - 0.001:
				pattern_cursor = 0.0
				drawing = not drawing


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


func _card_rect_in_graph(card: GraphNode) -> Rect2:
	return Rect2(card.position_offset, card.size).abs()


func _graph_route_to_layer(
	graph_route: PackedVector2Array,
	reference_card: GraphNode,
) -> PackedVector2Array:
	var card_to_layer := (
		get_global_transform().affine_inverse()
		* reference_card.get_global_transform()
	)
	var result := PackedVector2Array()
	for graph_point: Vector2 in graph_route:
		result.append(card_to_layer * (graph_point - reference_card.position_offset))
	return result


func _track_geometry_changes() -> void:
	if _graph_edit != null:
		if not _graph_edit.resized.is_connected(_on_view_transform_changed):
			_graph_edit.resized.connect(_on_view_transform_changed)
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
		if not card.item_rect_changed.is_connected(_on_card_geometry_changed):
			card.item_rect_changed.connect(_on_card_geometry_changed)
		if not card.visibility_changed.is_connected(_on_card_geometry_changed):
			card.visibility_changed.connect(_on_card_geometry_changed)


func _on_card_geometry_changed() -> void:
	_routes_dirty = true
	queue_redraw()


func _on_view_transform_changed() -> void:
	queue_redraw()


func _on_scroll_offset_changed(_offset: Vector2) -> void:
	queue_redraw()

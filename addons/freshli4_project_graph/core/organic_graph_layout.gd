@tool
extends RefCounted

const DEFAULT_NODE_SIZE := Vector2(270.0, 96.0)
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))
const START_ANGLE := -PI / 2.0

const SEED_SPACING := 235.0
const LINK_LENGTH_FACTOR := 1.65
const LINK_STRENGTH := 0.026
const REPULSION_STRENGTH := 42.0
const CENTER_STRENGTH := 0.0048
const DISK_COMPRESSION_STRENGTH := 0.016
const TARGET_DISK_PADDING := 1.18
const VELOCITY_SCALE := 0.34
const VELOCITY_DAMPING := 0.72
const INITIAL_MAX_STEP := 46.0
const FINAL_MAX_STEP := 4.0
const SMALL_GRAPH_ITERATIONS := 110
const LARGE_GRAPH_ITERATIONS := 72
const BARNES_HUT_THRESHOLD := 180
const BARNES_HUT_THETA := 0.72
const MAX_QUADTREE_DEPTH := 22

const NODE_GAP := 96.0
const COLLISION_PASSES := 320
const ORPHAN_GAP := 180.0
const MIN_ORPHAN_RADIUS := 520.0
const INHERITANCE_LEVEL_WEIGHT := 100
const DIRECT_CHILD_WEIGHT := 12


func calculate(
	snapshot: Dictionary,
	node_size: Vector2 = DEFAULT_NODE_SIZE,
) -> Dictionary:
	var node_ids := _collect_node_ids(snapshot)
	if node_ids.is_empty():
		return {
			"positions": {},
			"degrees": {},
			"hierarchy_levels": {},
			"root": "",
			"orphan_ids": PackedStringArray(),
		}

	var index_by_id: Dictionary = {}
	for index: int in node_ids.size():
		index_by_id[node_ids[index]] = index

	var topology := _build_topology(node_ids, index_by_id, snapshot.get("edges", []))
	var adjacency_sets := topology["adjacency"] as Array
	var edge_pairs := topology["edges"] as Array
	var inheritance_pairs := topology["inheritance_edges"] as Array
	var hierarchy_values := _calculate_hierarchy_levels(
		node_ids.size(),
		inheritance_pairs,
	)
	var direct_child_counts := PackedInt32Array()
	direct_child_counts.resize(node_ids.size())
	for pair_value: Variant in inheritance_pairs:
		var pair := pair_value as Vector2i
		direct_child_counts[pair.y] += 1
	var degrees: Dictionary = {}
	var hierarchy_levels: Dictionary = {}
	var degree_values := PackedInt32Array()
	degree_values.resize(node_ids.size())
	var importance_values := PackedInt32Array()
	importance_values.resize(node_ids.size())
	var connected_records: Array = []
	var orphan_ids := PackedStringArray()

	for index: int in node_ids.size():
		var degree := (adjacency_sets[index] as Dictionary).size()
		degree_values[index] = degree
		degrees[node_ids[index]] = degree
		hierarchy_levels[node_ids[index]] = hierarchy_values[index]
		var importance := (
			degree
			+ hierarchy_values[index] * INHERITANCE_LEVEL_WEIGHT
			+ direct_child_counts[index] * DIRECT_CHILD_WEIGHT
		)
		importance_values[index] = importance
		if degree == 0:
			orphan_ids.append(node_ids[index])
		else:
			connected_records.append({
				"id": node_ids[index],
				"index": index,
				"degree": degree,
				"importance": importance,
			})

	connected_records.sort_custom(_sort_importance_records)
	var positions_by_index: Array = []
	positions_by_index.resize(node_ids.size())
	for index: int in positions_by_index.size():
		positions_by_index[index] = Vector2.ZERO

	var root_id := ""
	var connected_indices := PackedInt32Array()
	if not connected_records.is_empty():
		root_id = String((connected_records[0] as Dictionary)["id"])
		for rank: int in connected_records.size():
			var record := connected_records[rank] as Dictionary
			var node_index := int(record["index"])
			connected_indices.append(node_index)
			if rank == 0:
				positions_by_index[node_index] = Vector2.ZERO
				continue
			var radius := SEED_SPACING * sqrt(float(rank))
			var angle := START_ANGLE + GOLDEN_ANGLE * float(rank)
			positions_by_index[node_index] = Vector2(cos(angle), sin(angle)) * radius

		_relax_connected_graph(
			positions_by_index,
			connected_indices,
			edge_pairs,
			degree_values,
			importance_values,
			node_size,
		)

	var connected_outer_radius := _connected_outer_radius(
		positions_by_index,
		connected_indices,
		node_size,
	)
	_place_orphans(
		positions_by_index,
		orphan_ids,
		index_by_id,
		connected_outer_radius,
		node_size,
	)

	var positions: Dictionary = {}
	for index: int in node_ids.size():
		positions[node_ids[index]] = (positions_by_index[index] as Vector2) - node_size / 2.0

	return {
		"positions": positions,
		"degrees": degrees,
		"hierarchy_levels": hierarchy_levels,
		"root": root_id,
		"orphan_ids": orphan_ids,
	}


func _collect_node_ids(snapshot: Dictionary) -> PackedStringArray:
	var node_ids := PackedStringArray()
	for node_value: Variant in snapshot.get("nodes", []):
		var node := node_value as Dictionary
		var node_id := String(node.get("id", ""))
		if not node_id.is_empty():
			node_ids.append(node_id)
	node_ids.sort()
	return node_ids


func _build_topology(
	node_ids: PackedStringArray,
	index_by_id: Dictionary,
	edges: Array,
) -> Dictionary:
	var adjacency: Array = []
	adjacency.resize(node_ids.size())
	for index: int in adjacency.size():
		adjacency[index] = {}

	var unique_edges: Dictionary = {}
	var unique_inheritance_edges: Dictionary = {}
	var edge_pairs: Array = []
	var inheritance_pairs: Array = []
	for edge_value: Variant in edges:
		var edge := edge_value as Dictionary
		var source_id := String(edge.get("source", ""))
		var target_id := String(edge.get("target", ""))
		if (
			source_id == target_id
			or not index_by_id.has(source_id)
			or not index_by_id.has(target_id)
		):
			continue
		var source_index := int(index_by_id[source_id])
		var target_index := int(index_by_id[target_id])
		if String(edge.get("relation", "")) == "inherits":
			var inheritance_key := "%d:%d" % [source_index, target_index]
			if not unique_inheritance_edges.has(inheritance_key):
				unique_inheritance_edges[inheritance_key] = true
				inheritance_pairs.append(Vector2i(source_index, target_index))
		var low_index := mini(source_index, target_index)
		var high_index := maxi(source_index, target_index)
		var edge_key := "%d:%d" % [low_index, high_index]
		if unique_edges.has(edge_key):
			continue
		unique_edges[edge_key] = true
		(adjacency[low_index] as Dictionary)[high_index] = true
		(adjacency[high_index] as Dictionary)[low_index] = true
		edge_pairs.append(Vector2i(low_index, high_index))

	edge_pairs.sort_custom(_sort_edge_pairs)
	inheritance_pairs.sort_custom(_sort_edge_pairs)
	return {
		"adjacency": adjacency,
		"edges": edge_pairs,
		"inheritance_edges": inheritance_pairs,
	}


func _calculate_hierarchy_levels(
	node_count: int,
	inheritance_pairs: Array,
) -> PackedInt32Array:
	var levels := PackedInt32Array()
	levels.resize(node_count)
	for _pass_index: int in node_count:
		var changed := false
		for pair_value: Variant in inheritance_pairs:
			var pair := pair_value as Vector2i
			var next_level := levels[pair.x] + 1
			if next_level > levels[pair.y]:
				levels[pair.y] = next_level
				changed = true
		if not changed:
			break
	return levels


func _sort_importance_records(left: Dictionary, right: Dictionary) -> bool:
	var left_importance := int(left["importance"])
	var right_importance := int(right["importance"])
	if left_importance != right_importance:
		return left_importance > right_importance
	var left_degree := int(left["degree"])
	var right_degree := int(right["degree"])
	if left_degree != right_degree:
		return left_degree > right_degree
	return String(left["id"]) < String(right["id"])


func _sort_edge_pairs(left: Vector2i, right: Vector2i) -> bool:
	if left.x != right.x:
		return left.x < right.x
	return left.y < right.y


func _relax_connected_graph(
	all_positions: Array,
	connected_indices: PackedInt32Array,
	edge_pairs: Array,
	degrees: PackedInt32Array,
	importance: PackedInt32Array,
	node_size: Vector2,
) -> void:
	if connected_indices.is_empty():
		return

	var local_positions: Array = []
	var local_degrees := PackedInt32Array()
	var local_importance := PackedInt32Array()
	var local_by_global: Dictionary = {}
	for local_index: int in connected_indices.size():
		var global_index := connected_indices[local_index]
		local_by_global[global_index] = local_index
		local_positions.append(all_positions[global_index])
		local_degrees.append(degrees[global_index])
		local_importance.append(importance[global_index])

	var local_edges: Array = []
	for edge_pair_value: Variant in edge_pairs:
		var edge_pair := edge_pair_value as Vector2i
		if local_by_global.has(edge_pair.x) and local_by_global.has(edge_pair.y):
			local_edges.append(Vector2i(
				int(local_by_global[edge_pair.x]),
				int(local_by_global[edge_pair.y]),
			))

	var velocities: Array = []
	velocities.resize(local_positions.size())
	for index: int in velocities.size():
		velocities[index] = Vector2.ZERO

	var max_importance := 1
	for importance_value: int in local_importance:
		max_importance = maxi(max_importance, importance_value)

	var iterations := (
		SMALL_GRAPH_ITERATIONS
		if local_positions.size() <= BARNES_HUT_THRESHOLD
		else LARGE_GRAPH_ITERATIONS
	)
	var link_length := maxf(node_size.x, node_size.y) * LINK_LENGTH_FACTOR
	var target_disk_radius := (
		sqrt(
			float(local_positions.size())
			* (node_size.x + NODE_GAP)
			* (node_size.y + NODE_GAP)
			/ PI
		)
		* TARGET_DISK_PADDING
	)
	var masses := PackedFloat64Array()
	for degree: int in local_degrees:
		masses.append(float(degree + 1))

	for iteration: int in iterations:
		var forces: Array = []
		for index: int in local_positions.size():
			forces.append(Vector2.ZERO)

		if local_positions.size() <= BARNES_HUT_THRESHOLD:
			_accumulate_exact_repulsion(local_positions, masses, forces, node_size)
		else:
			_accumulate_barnes_hut_repulsion(local_positions, masses, forces, node_size)

		for edge_pair_value: Variant in local_edges:
			var edge_pair := edge_pair_value as Vector2i
			var source_position := local_positions[edge_pair.x] as Vector2
			var target_position := local_positions[edge_pair.y] as Vector2
			var delta := target_position - source_position
			var distance := maxf(delta.length(), 0.001)
			var spring_force := (
				delta / distance
				* (distance - link_length)
				* LINK_STRENGTH
			)
			forces[edge_pair.x] = (forces[edge_pair.x] as Vector2) + spring_force
			forces[edge_pair.y] = (forces[edge_pair.y] as Vector2) - spring_force

		for index: int in local_positions.size():
			if index == 0:
				continue
			var centrality := float(local_importance[index]) / float(max_importance)
			var center_force := (
				-(local_positions[index] as Vector2)
				* CENTER_STRENGTH
				* lerpf(1.0, 2.6, centrality)
			)
			var distance_from_center := (local_positions[index] as Vector2).length()
			if distance_from_center > target_disk_radius:
				center_force += (
					-(local_positions[index] as Vector2).normalized()
					* (distance_from_center - target_disk_radius)
					* DISK_COMPRESSION_STRENGTH
				)
			forces[index] = (forces[index] as Vector2) + center_force

		var progress := float(iteration) / float(maxi(iterations - 1, 1))
		var max_step := lerpf(INITIAL_MAX_STEP, FINAL_MAX_STEP, progress)
		for index: int in local_positions.size():
			if index == 0:
				local_positions[index] = Vector2.ZERO
				velocities[index] = Vector2.ZERO
				continue
			var velocity := (
				(velocities[index] as Vector2)
				+ (forces[index] as Vector2) * VELOCITY_SCALE
			) * VELOCITY_DAMPING
			velocity = velocity.limit_length(max_step)
			velocities[index] = velocity
			local_positions[index] = (local_positions[index] as Vector2) + velocity

		if iteration % 8 == 7:
			_resolve_collisions(local_positions, node_size, 0, 1)

	_resolve_collisions(local_positions, node_size, 0, COLLISION_PASSES)
	local_positions[0] = Vector2.ZERO

	for local_index: int in connected_indices.size():
		all_positions[connected_indices[local_index]] = local_positions[local_index]


func _accumulate_exact_repulsion(
	positions: Array,
	masses: PackedFloat64Array,
	forces: Array,
	node_size: Vector2,
) -> void:
	var minimum_distance := maxf(node_size.length() * 0.42, 1.0)
	for left_index: int in positions.size():
		for right_index: int in range(left_index + 1, positions.size()):
			var delta := (positions[left_index] as Vector2) - (positions[right_index] as Vector2)
			if delta.length_squared() < 0.0001:
				delta = _stable_direction(left_index, right_index)
			var distance := maxf(delta.length(), minimum_distance)
			var repulsion := (
				delta.normalized()
				* REPULSION_STRENGTH
				* masses[left_index]
				* masses[right_index]
				/ distance
			)
			forces[left_index] = (forces[left_index] as Vector2) + repulsion
			forces[right_index] = (forces[right_index] as Vector2) - repulsion


func _accumulate_barnes_hut_repulsion(
	positions: Array,
	masses: PackedFloat64Array,
	forces: Array,
	node_size: Vector2,
) -> void:
	var tree := _build_quadtree(positions, masses)
	var minimum_distance := maxf(node_size.length() * 0.42, 1.0)
	for index: int in positions.size():
		forces[index] = (
			(forces[index] as Vector2)
			+ _quadtree_repulsion(
				index,
				positions[index] as Vector2,
				masses[index],
				tree,
				positions,
				masses,
				minimum_distance,
			)
		)


func _build_quadtree(
	positions: Array,
	masses: PackedFloat64Array,
) -> Dictionary:
	var minimum := positions[0] as Vector2
	var maximum := positions[0] as Vector2
	for position_value: Variant in positions:
		var position := position_value as Vector2
		minimum.x = minf(minimum.x, position.x)
		minimum.y = minf(minimum.y, position.y)
		maximum.x = maxf(maximum.x, position.x)
		maximum.y = maxf(maximum.y, position.y)

	var center := (minimum + maximum) / 2.0
	var half_size := maxf(maximum.x - minimum.x, maximum.y - minimum.y) / 2.0
	var tree := _make_quadtree_node(center, maxf(half_size + 1.0, 2.0))
	for index: int in positions.size():
		_quadtree_insert(tree, index, positions, masses, 0)
	return tree


func _make_quadtree_node(center: Vector2, half_size: float) -> Dictionary:
	return {
		"center": center,
		"half_size": half_size,
		"mass": 0.0,
		"mass_center": Vector2.ZERO,
		"indices": [],
		"children": [],
	}


func _quadtree_insert(
	node: Dictionary,
	point_index: int,
	positions: Array,
	masses: PackedFloat64Array,
	depth: int,
) -> void:
	var point_mass := masses[point_index]
	var point_position := positions[point_index] as Vector2
	var previous_mass := float(node["mass"])
	var combined_mass := previous_mass + point_mass
	node["mass_center"] = (
		(node["mass_center"] as Vector2) * previous_mass
		+ point_position * point_mass
	) / combined_mass
	node["mass"] = combined_mass

	var children := node["children"] as Array
	if children.is_empty():
		var indices := node["indices"] as Array
		if (
			indices.is_empty()
			or depth >= MAX_QUADTREE_DEPTH
			or float(node["half_size"]) <= 0.5
		):
			indices.append(point_index)
			node["indices"] = indices
			return

		_subdivide_quadtree_node(node)
		children = node["children"] as Array
		for existing_index_value: Variant in indices:
			var existing_index := int(existing_index_value)
			var existing_child := _quadtree_child_index(
				node["center"] as Vector2,
				positions[existing_index] as Vector2,
			)
			_quadtree_insert(
				children[existing_child] as Dictionary,
				existing_index,
				positions,
				masses,
				depth + 1,
			)
		node["indices"] = []

	var child_index := _quadtree_child_index(
		node["center"] as Vector2,
		point_position,
	)
	_quadtree_insert(
		(node["children"] as Array)[child_index] as Dictionary,
		point_index,
		positions,
		masses,
		depth + 1,
	)


func _subdivide_quadtree_node(node: Dictionary) -> void:
	var center := node["center"] as Vector2
	var child_half := float(node["half_size"]) / 2.0
	node["children"] = [
		_make_quadtree_node(center + Vector2(-child_half, -child_half), child_half),
		_make_quadtree_node(center + Vector2(child_half, -child_half), child_half),
		_make_quadtree_node(center + Vector2(-child_half, child_half), child_half),
		_make_quadtree_node(center + Vector2(child_half, child_half), child_half),
	]


func _quadtree_child_index(center: Vector2, point: Vector2) -> int:
	var x_offset := 1 if point.x >= center.x else 0
	var y_offset := 2 if point.y >= center.y else 0
	return x_offset + y_offset


func _quadtree_repulsion(
	point_index: int,
	point_position: Vector2,
	point_mass: float,
	node: Dictionary,
	positions: Array,
	masses: PackedFloat64Array,
	minimum_distance: float,
) -> Vector2:
	if float(node["mass"]) <= 0.0:
		return Vector2.ZERO

	var children := node["children"] as Array
	if children.is_empty():
		var force := Vector2.ZERO
		for other_index_value: Variant in node["indices"] as Array:
			var other_index := int(other_index_value)
			if other_index == point_index:
				continue
			var delta := point_position - (positions[other_index] as Vector2)
			if delta.length_squared() < 0.0001:
				delta = _stable_direction(point_index, other_index)
			var distance := maxf(delta.length(), minimum_distance)
			force += (
				delta.normalized()
				* REPULSION_STRENGTH
				* point_mass
				* masses[other_index]
				/ distance
			)
		return force

	var delta_to_mass := point_position - (node["mass_center"] as Vector2)
	var distance_to_mass := maxf(delta_to_mass.length(), 0.001)
	var width := float(node["half_size"]) * 2.0
	if width / distance_to_mass < BARNES_HUT_THETA:
		return (
			delta_to_mass.normalized()
			* REPULSION_STRENGTH
			* point_mass
			* float(node["mass"])
			/ maxf(distance_to_mass, minimum_distance)
		)

	var force := Vector2.ZERO
	for child_value: Variant in children:
		force += _quadtree_repulsion(
			point_index,
			point_position,
			point_mass,
			child_value as Dictionary,
			positions,
			masses,
			minimum_distance,
		)
	return force


func _stable_direction(left_index: int, right_index: int) -> Vector2:
	var angle := GOLDEN_ANGLE * float(left_index * 131 + right_index * 17 + 1)
	return Vector2(cos(angle), sin(angle))


func _resolve_collisions(
	positions: Array,
	node_size: Vector2,
	pinned_index: int,
	passes: int,
) -> void:
	if positions.size() < 2:
		return
	var cell_size := maxf(node_size.x, node_size.y) + NODE_GAP
	for _pass_index: int in passes:
		var grid: Dictionary = {}
		for index: int in positions.size():
			var position := positions[index] as Vector2
			var cell := Vector2i(
				floori(position.x / cell_size),
				floori(position.y / cell_size),
			)
			var key := "%d:%d" % [cell.x, cell.y]
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(index)

		var moved := false
		for left_index: int in positions.size():
			var left_position := positions[left_index] as Vector2
			var left_cell := Vector2i(
				floori(left_position.x / cell_size),
				floori(left_position.y / cell_size),
			)
			for cell_y: int in range(left_cell.y - 1, left_cell.y + 2):
				for cell_x: int in range(left_cell.x - 1, left_cell.x + 2):
					var key := "%d:%d" % [cell_x, cell_y]
					if not grid.has(key):
						continue
					for right_index_value: Variant in grid[key] as Array:
						var right_index := int(right_index_value)
						if right_index <= left_index:
							continue
						if _separate_pair(
							positions,
							left_index,
							right_index,
							node_size,
							pinned_index,
						):
							moved = true
		positions[pinned_index] = Vector2.ZERO
		if not moved:
			return


func _separate_pair(
	positions: Array,
	left_index: int,
	right_index: int,
	node_size: Vector2,
	pinned_index: int,
) -> bool:
	var left := positions[left_index] as Vector2
	var right := positions[right_index] as Vector2
	var delta := right - left
	var overlap_x := node_size.x + NODE_GAP - absf(delta.x)
	var overlap_y := node_size.y + NODE_GAP - absf(delta.y)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return false

	var offset := Vector2.ZERO
	if overlap_x < overlap_y:
		var direction_x := signf(delta.x)
		if is_zero_approx(direction_x):
			direction_x = 1.0 if (left_index + right_index) % 2 == 0 else -1.0
		offset.x = direction_x * (overlap_x + 0.01)
	else:
		var direction_y := signf(delta.y)
		if is_zero_approx(direction_y):
			direction_y = 1.0 if (left_index + right_index) % 2 == 0 else -1.0
		offset.y = direction_y * (overlap_y + 0.01)

	if left_index == pinned_index:
		positions[right_index] = right + offset
	elif right_index == pinned_index:
		positions[left_index] = left - offset
	else:
		positions[left_index] = left - offset / 2.0
		positions[right_index] = right + offset / 2.0
	return true


func _connected_outer_radius(
	positions: Array,
	connected_indices: PackedInt32Array,
	node_size: Vector2,
) -> float:
	var outer_radius := 0.0
	var half_diagonal := node_size.length() / 2.0
	for index: int in connected_indices:
		outer_radius = maxf(
			outer_radius,
			(positions[index] as Vector2).length() + half_diagonal,
		)
	return outer_radius


func _place_orphans(
	positions: Array,
	orphan_ids: PackedStringArray,
	index_by_id: Dictionary,
	connected_outer_radius: float,
	node_size: Vector2,
) -> void:
	if orphan_ids.is_empty():
		return

	var half_diagonal := node_size.length() / 2.0
	var minimum_chord := node_size.length() + NODE_GAP
	var radius := maxf(
		connected_outer_radius + ORPHAN_GAP + half_diagonal,
		MIN_ORPHAN_RADIUS,
	)
	if orphan_ids.size() > 1:
		radius = maxf(
			radius,
			minimum_chord / (2.0 * sin(PI / float(orphan_ids.size()))),
		)

	for index: int in orphan_ids.size():
		var node_id := orphan_ids[index]
		var angle := START_ANGLE + TAU * float(index) / float(orphan_ids.size())
		var global_index := int(index_by_id[node_id])
		positions[global_index] = Vector2(cos(angle), sin(angle)) * radius

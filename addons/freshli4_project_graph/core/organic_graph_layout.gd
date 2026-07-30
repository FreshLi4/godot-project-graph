@tool
extends RefCounted

const DEFAULT_NODE_SIZE := Vector2(320.0, 190.0)
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))
const START_ANGLE := -PI / 2.0

const SEED_SPACING := 235.0
const LINK_STRENGTH := 0.038
const COMMUNITY_STRENGTH := 0.0065
const COMMUNITY_DISTANCE_FACTOR := 1.45
const MAX_COMMUNITY_HUB_DEGREE := 64
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
const CROSSING_SWAP_PASSES := 3
const LARGE_CROSSING_SWAP_PASSES := 1
const FULL_CROSSING_OPTIMIZATION_NODES := 240
const FULL_CROSSING_OPTIMIZATION_EDGES := 480
const MAX_CROSSING_OPTIMIZATION_NODES := 1200
const MAX_CROSSING_OPTIMIZATION_EDGES := 2400
const MAX_EDGE_LENGTH_INCREASE := 1.18


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
			"crossings_before": 0,
			"crossings_after": 0,
			"mean_edge_length": 0.0,
			"community_pair_count": 0,
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
	var readability_metrics := {
		"crossings_before": 0,
		"crossings_after": 0,
		"mean_edge_length": 0.0,
		"community_pair_count": 0,
	}
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

		readability_metrics = _relax_connected_graph(
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
		"crossings_before": int(readability_metrics["crossings_before"]),
		"crossings_after": int(readability_metrics["crossings_after"]),
		"mean_edge_length": float(readability_metrics["mean_edge_length"]),
		"community_pair_count": int(readability_metrics["community_pair_count"]),
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
) -> Dictionary:
	if connected_indices.is_empty():
		return {
			"crossings_before": 0,
			"crossings_after": 0,
			"mean_edge_length": 0.0,
			"community_pair_count": 0,
		}

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
	var local_adjacency := _build_adjacency(local_positions.size(), local_edges)
	var community_pairs := _build_community_pairs(local_adjacency)

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
	var link_length := maxf(
		node_size.x + NODE_GAP,
		node_size.y + NODE_GAP,
	)
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
			var endpoint_degree := maxi(
				1,
				mini(local_degrees[edge_pair.x], local_degrees[edge_pair.y]),
			)
			var adaptive_strength := LINK_STRENGTH / sqrt(float(endpoint_degree))
			var spring_force := (
				delta / distance
				* (distance - link_length)
				* adaptive_strength
			)
			forces[edge_pair.x] = (forces[edge_pair.x] as Vector2) + spring_force
			forces[edge_pair.y] = (forces[edge_pair.y] as Vector2) - spring_force

		for community_pair_value: Variant in community_pairs:
			var community_pair := community_pair_value as Vector3i
			var left_position := local_positions[community_pair.x] as Vector2
			var right_position := local_positions[community_pair.y] as Vector2
			var delta := right_position - left_position
			var distance := maxf(delta.length(), 0.001)
			var target_distance := link_length * COMMUNITY_DISTANCE_FACTOR
			if distance <= target_distance:
				continue
			var shared_neighbor_weight := sqrt(float(community_pair.z))
			var community_force := (
				delta / distance
				* (distance - target_distance)
				* COMMUNITY_STRENGTH
				* shared_neighbor_weight
			)
			forces[community_pair.x] = (
				(forces[community_pair.x] as Vector2) + community_force
			)
			forces[community_pair.y] = (
				(forces[community_pair.y] as Vector2) - community_force
			)

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
	var readability_metrics := _reduce_edge_crossings(
		local_positions,
		local_edges,
		local_adjacency,
		node_size,
		0,
	)
	readability_metrics["community_pair_count"] = community_pairs.size()

	for local_index: int in connected_indices.size():
		all_positions[connected_indices[local_index]] = local_positions[local_index]
	return readability_metrics


func _build_adjacency(node_count: int, edge_pairs: Array) -> Array:
	var adjacency: Array = []
	adjacency.resize(node_count)
	for index: int in node_count:
		adjacency[index] = {}
	for edge_pair_value: Variant in edge_pairs:
		var edge_pair := edge_pair_value as Vector2i
		(adjacency[edge_pair.x] as Dictionary)[edge_pair.y] = true
		(adjacency[edge_pair.y] as Dictionary)[edge_pair.x] = true
	return adjacency


func _build_community_pairs(adjacency: Array) -> Array:
	var weights: Dictionary = {}
	for hub_index: int in adjacency.size():
		var neighbors: Array = (adjacency[hub_index] as Dictionary).keys()
		if neighbors.size() < 2 or neighbors.size() > MAX_COMMUNITY_HUB_DEGREE:
			continue
		neighbors.sort()
		for left_offset: int in neighbors.size():
			var left_index := int(neighbors[left_offset])
			for right_offset: int in range(left_offset + 1, neighbors.size()):
				var right_index := int(neighbors[right_offset])
				if (adjacency[left_index] as Dictionary).has(right_index):
					continue
				var low_index := mini(left_index, right_index)
				var high_index := maxi(left_index, right_index)
				var key := "%d:%d" % [low_index, high_index]
				weights[key] = int(weights.get(key, 0)) + 1

	var pairs: Array = []
	for key_value: Variant in weights:
		var key := String(key_value)
		var components := key.split(":", false, 1)
		pairs.append(Vector3i(
			int(components[0]),
			int(components[1]),
			int(weights[key]),
		))
	pairs.sort_custom(_sort_community_pairs)
	return pairs


func _sort_community_pairs(left: Vector3i, right: Vector3i) -> bool:
	if left.x != right.x:
		return left.x < right.x
	if left.y != right.y:
		return left.y < right.y
	return left.z > right.z


func refine_positions(
	snapshot: Dictionary,
	input_positions: Dictionary,
	node_size: Vector2 = DEFAULT_NODE_SIZE,
) -> Dictionary:
	var node_ids := _collect_node_ids(snapshot)
	var index_by_id: Dictionary = {}
	var positions: Array = []
	for index: int in node_ids.size():
		index_by_id[node_ids[index]] = index
		positions.append(
			(input_positions.get(node_ids[index], Vector2.ZERO) as Vector2)
			+ node_size / 2.0
		)
	var topology := _build_topology(
		node_ids,
		index_by_id,
		snapshot.get("edges", []),
	)
	var edge_pairs := topology["edges"] as Array
	var adjacency := topology["adjacency"] as Array
	var pinned_index := _nearest_to_origin(positions)
	var metrics := _reduce_edge_crossings(
		positions,
		edge_pairs,
		adjacency,
		node_size,
		pinned_index,
	)
	var refined_positions: Dictionary = {}
	for index: int in node_ids.size():
		refined_positions[node_ids[index]] = (positions[index] as Vector2) - node_size / 2.0
	metrics["positions"] = refined_positions
	return metrics


func _nearest_to_origin(positions: Array) -> int:
	if positions.is_empty():
		return -1
	var nearest_index := 0
	var nearest_distance := (positions[0] as Vector2).length_squared()
	for index: int in range(1, positions.size()):
		var distance := (positions[index] as Vector2).length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _reduce_edge_crossings(
	positions: Array,
	edge_pairs: Array,
	adjacency: Array,
	node_size: Vector2,
	pinned_index: int,
) -> Dictionary:
	var crossing_count := _count_edge_crossings(positions, edge_pairs)
	var total_edge_length := _total_edge_length(positions, edge_pairs)
	var edge_count := maxi(edge_pairs.size(), 1)
	var mean_edge_length := total_edge_length / float(edge_count)
	var metrics := {
		"crossings_before": crossing_count,
		"crossings_after": crossing_count,
		"mean_edge_length": mean_edge_length,
		"community_pair_count": 0,
	}
	if (
		crossing_count == 0
		or positions.size() > MAX_CROSSING_OPTIMIZATION_NODES
		or edge_pairs.size() > MAX_CROSSING_OPTIMIZATION_EDGES
	):
		return metrics

	var incident_edges := _build_incident_edges(positions.size(), edge_pairs)
	var maximum_mean_length := mean_edge_length * MAX_EDGE_LENGTH_INCREASE
	var band_width := maxf(
		node_size.y + NODE_GAP,
		node_size.x * 0.8,
	)

	var crossing_passes := (
		CROSSING_SWAP_PASSES
		if (
			positions.size() <= FULL_CROSSING_OPTIMIZATION_NODES
			and edge_pairs.size() <= FULL_CROSSING_OPTIMIZATION_EDGES
		)
		else LARGE_CROSSING_SWAP_PASSES
	)
	for _pass_index: int in crossing_passes:
		var improved := false
		var radial_bands := _build_radial_bands(
			positions,
			band_width,
			pinned_index,
		)
		var band_keys: Array = radial_bands.keys()
		band_keys.sort()
		for band_key_value: Variant in band_keys:
			var band_nodes := radial_bands[band_key_value] as Array
			band_nodes.sort()
			var swap_candidates := _build_swap_candidates(
				band_nodes,
				positions,
				adjacency,
			)
			for candidate_value: Variant in swap_candidates:
				var candidate := candidate_value as Vector2i
				var left_index := candidate.x
				var right_index := candidate.y
				var affected_edges := _collect_affected_edges(
					incident_edges,
					left_index,
					right_index,
				)
				var previous_local_crossings := _count_local_crossings(
					positions,
					edge_pairs,
					affected_edges,
				)
				var previous_local_length := _edge_subset_length(
					positions,
					edge_pairs,
					affected_edges,
				)
				var previous_position := positions[left_index] as Vector2
				positions[left_index] = positions[right_index]
				positions[right_index] = previous_position
				var next_local_crossings := _count_local_crossings(
					positions,
					edge_pairs,
					affected_edges,
				)
				var next_local_length := _edge_subset_length(
					positions,
					edge_pairs,
					affected_edges,
				)
				var candidate_crossings := (
					crossing_count
					+ next_local_crossings
					- previous_local_crossings
				)
				var candidate_total_length := (
					total_edge_length
					+ next_local_length
					- previous_local_length
				)
				var candidate_mean_length := (
					candidate_total_length / float(edge_count)
				)
				var accept := (
					(
						candidate_crossings < crossing_count
						and candidate_mean_length <= maximum_mean_length
					)
					or (
						candidate_crossings == crossing_count
						and candidate_total_length < total_edge_length - 0.01
					)
				)
				if accept:
					crossing_count = candidate_crossings
					total_edge_length = candidate_total_length
					improved = true
				else:
					previous_position = positions[left_index] as Vector2
					positions[left_index] = positions[right_index]
					positions[right_index] = previous_position
		if not improved:
			break

	metrics["crossings_after"] = crossing_count
	metrics["mean_edge_length"] = total_edge_length / float(edge_count)
	return metrics


func _build_swap_candidates(
	band_nodes: Array,
	positions: Array,
	adjacency: Array,
) -> Array:
	if band_nodes.size() < 2:
		return []
	var angle_records: Array = []
	for node_index_value: Variant in band_nodes:
		var node_index := int(node_index_value)
		var position := positions[node_index] as Vector2
		angle_records.append({
			"index": node_index,
			"angle": atan2(position.y, position.x),
		})
	angle_records.sort_custom(_sort_angle_records)

	var unique_pairs: Dictionary = {}
	for offset: int in angle_records.size():
		var left_index := int((angle_records[offset] as Dictionary)["index"])
		var right_index := int(
			(angle_records[(offset + 1) % angle_records.size()] as Dictionary)["index"]
		)
		_add_swap_candidate(unique_pairs, left_index, right_index)

	for node_index_value: Variant in band_nodes:
		var node_index := int(node_index_value)
		var neighbor_center := Vector2.ZERO
		var neighbor_count := 0
		var neighbor_indices: Array = (adjacency[node_index] as Dictionary).keys()
		neighbor_indices.sort()
		for neighbor_index_value: Variant in neighbor_indices:
			neighbor_center += positions[int(neighbor_index_value)] as Vector2
			neighbor_count += 1
		if neighbor_count == 0 or neighbor_center.length_squared() < 0.001:
			continue
		var desired_angle := atan2(neighbor_center.y, neighbor_center.x)
		var closest_index := -1
		var closest_difference := INF
		for candidate_index_value: Variant in band_nodes:
			var candidate_index := int(candidate_index_value)
			if candidate_index == node_index:
				continue
			var candidate_position := positions[candidate_index] as Vector2
			var candidate_angle := atan2(candidate_position.y, candidate_position.x)
			var difference := absf(
				wrapf(candidate_angle - desired_angle, -PI, PI)
			)
			if (
				difference < closest_difference - 0.0001
				or (
					is_equal_approx(difference, closest_difference)
					and candidate_index < closest_index
				)
			):
				closest_difference = difference
				closest_index = candidate_index
		if closest_index >= 0:
			_add_swap_candidate(unique_pairs, node_index, closest_index)

	var candidates: Array = []
	for key_value: Variant in unique_pairs:
		var key := String(key_value)
		var components := key.split(":", false, 1)
		candidates.append(Vector2i(int(components[0]), int(components[1])))
	candidates.sort_custom(_sort_edge_pairs)
	return candidates


func _sort_angle_records(left: Dictionary, right: Dictionary) -> bool:
	var left_angle := float(left["angle"])
	var right_angle := float(right["angle"])
	if not is_equal_approx(left_angle, right_angle):
		return left_angle < right_angle
	return int(left["index"]) < int(right["index"])


func _add_swap_candidate(
	unique_pairs: Dictionary,
	left_index: int,
	right_index: int,
) -> void:
	if left_index == right_index:
		return
	var low_index := mini(left_index, right_index)
	var high_index := maxi(left_index, right_index)
	unique_pairs["%d:%d" % [low_index, high_index]] = true


func _build_radial_bands(
	positions: Array,
	band_width: float,
	pinned_index: int,
) -> Dictionary:
	var bands: Dictionary = {}
	for index: int in positions.size():
		if index == pinned_index:
			continue
		var radius := (positions[index] as Vector2).length()
		var band := maxi(1, roundi(radius / maxf(band_width, 1.0)))
		if not bands.has(band):
			bands[band] = []
		(bands[band] as Array).append(index)
	return bands


func _build_incident_edges(node_count: int, edge_pairs: Array) -> Array:
	var incident_edges: Array = []
	incident_edges.resize(node_count)
	for index: int in node_count:
		incident_edges[index] = []
	for edge_index: int in edge_pairs.size():
		var edge_pair := edge_pairs[edge_index] as Vector2i
		(incident_edges[edge_pair.x] as Array).append(edge_index)
		(incident_edges[edge_pair.y] as Array).append(edge_index)
	return incident_edges


func _collect_affected_edges(
	incident_edges: Array,
	left_index: int,
	right_index: int,
) -> Dictionary:
	var affected: Dictionary = {}
	for edge_index_value: Variant in incident_edges[left_index] as Array:
		affected[int(edge_index_value)] = true
	for edge_index_value: Variant in incident_edges[right_index] as Array:
		affected[int(edge_index_value)] = true
	return affected


func _count_edge_crossings(positions: Array, edge_pairs: Array) -> int:
	var crossings := 0
	for left_edge_index: int in edge_pairs.size():
		var left_edge := edge_pairs[left_edge_index] as Vector2i
		for right_edge_index: int in range(left_edge_index + 1, edge_pairs.size()):
			var right_edge := edge_pairs[right_edge_index] as Vector2i
			if _edges_share_node(left_edge, right_edge):
				continue
			if _segments_cross(
				positions[left_edge.x] as Vector2,
				positions[left_edge.y] as Vector2,
				positions[right_edge.x] as Vector2,
				positions[right_edge.y] as Vector2,
			):
				crossings += 1
	return crossings


func _count_local_crossings(
	positions: Array,
	edge_pairs: Array,
	affected_edges: Dictionary,
) -> int:
	var crossings := 0
	for left_edge_index: int in edge_pairs.size():
		var left_edge := edge_pairs[left_edge_index] as Vector2i
		for right_edge_index: int in range(left_edge_index + 1, edge_pairs.size()):
			if (
				not affected_edges.has(left_edge_index)
				and not affected_edges.has(right_edge_index)
			):
				continue
			var right_edge := edge_pairs[right_edge_index] as Vector2i
			if _edges_share_node(left_edge, right_edge):
				continue
			if _segments_cross(
				positions[left_edge.x] as Vector2,
				positions[left_edge.y] as Vector2,
				positions[right_edge.x] as Vector2,
				positions[right_edge.y] as Vector2,
			):
				crossings += 1
	return crossings


func _edges_share_node(left: Vector2i, right: Vector2i) -> bool:
	return (
		left.x == right.x
		or left.x == right.y
		or left.y == right.x
		or left.y == right.y
	)


func _segments_cross(
	left_start: Vector2,
	left_end: Vector2,
	right_start: Vector2,
	right_end: Vector2,
) -> bool:
	var left_right_start := _orientation(left_start, left_end, right_start)
	var left_right_end := _orientation(left_start, left_end, right_end)
	var right_left_start := _orientation(right_start, right_end, left_start)
	var right_left_end := _orientation(right_start, right_end, left_end)
	const EPSILON := 0.001
	if (
		absf(left_right_start) <= EPSILON
		or absf(left_right_end) <= EPSILON
		or absf(right_left_start) <= EPSILON
		or absf(right_left_end) <= EPSILON
	):
		return false
	return (
		(left_right_start > 0.0) != (left_right_end > 0.0)
		and (right_left_start > 0.0) != (right_left_end > 0.0)
	)


func _orientation(first: Vector2, second: Vector2, third: Vector2) -> float:
	return (second - first).cross(third - first)


func _total_edge_length(positions: Array, edge_pairs: Array) -> float:
	var total := 0.0
	for edge_pair_value: Variant in edge_pairs:
		var edge_pair := edge_pair_value as Vector2i
		total += (positions[edge_pair.x] as Vector2).distance_to(
			positions[edge_pair.y] as Vector2
		)
	return total


func _edge_subset_length(
	positions: Array,
	edge_pairs: Array,
	edge_indices: Dictionary,
) -> float:
	var total := 0.0
	for edge_index_value: Variant in edge_indices:
		var edge_pair := edge_pairs[int(edge_index_value)] as Vector2i
		total += (positions[edge_pair.x] as Vector2).distance_to(
			positions[edge_pair.y] as Vector2
		)
	return total


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

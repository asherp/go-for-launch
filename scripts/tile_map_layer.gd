extends TileMapLayer

func _ready() -> void:
	var filled_tiles := get_used_cells()
	
	for filled_tile: Vector2i in filled_tiles:
		var atlas_coords = get_cell_atlas_coords(filled_tile)
		
		# Skip barrier placement for tiles with atlas coords (6, 0)
		if atlas_coords == Vector2i(6, 0):
			continue
		
		var neighboring_tiles := get_surrounding_cells(filled_tile)
		
		for neighbor: Vector2i in neighboring_tiles:
			# add barriers in empty places
			if get_cell_source_id(neighbor) == -1:
				# Check if there's a tile in the floor below at this position
				if has_tile_below(neighbor):
					# Skip placing barrier - allow falling to floor below
					continue
				
				set_cell(neighbor, 0, Vector2i(0,1))

func has_tile_above(tile_pos: Vector2i) -> bool:
	# Check if there's a tile at this position in the floor above
	var floor_above = get_floor_above()
	if floor_above:
		# Subtract (1,1) offset for isometric alignment to check floor above
		var adjusted_pos = tile_pos - Vector2i(1, 1)
		var tile_id = floor_above.get_cell_source_id(adjusted_pos)
		var atlas = floor_above.get_cell_atlas_coords(adjusted_pos)
		
		# Returns true if there's a real tile (not a barrier at 0,1)
		return tile_id != -1 and atlas != Vector2i(0, 1)
	return false

func has_tile_below(tile_pos: Vector2i) -> bool:
	# Check if there's a tile at this position in the floor below
	var floor_below = get_floor_below()
	if floor_below:
		# Add (1,1) offset for isometric alignment between floors
		var adjusted_pos = tile_pos + Vector2i(1, 1)
		var tile_id = floor_below.get_cell_source_id(adjusted_pos)
		var atlas = floor_below.get_cell_atlas_coords(adjusted_pos)
		
		# Returns true if there's a real tile (not a barrier at 0,1)
		return tile_id != -1 and atlas != Vector2i(0, 1)
	return false

func get_floor_above() -> TileMapLayer:
	# Get the floor above the current one
	var root = get_parent()
	if not root:
		return null
	
	var floor_order = ["GroundFloor", "FirstFloor", "SecondFloor"]
	var current_index = floor_order.find(name)
	
	if current_index == -1 or current_index >= floor_order.size() - 1:
		return null  # No floor above
	
	var above_floor_name = floor_order[current_index + 1]
	return root.get_node_or_null(above_floor_name)

func get_floor_below() -> TileMapLayer:
	# Get the floor below the current one
	var root = get_parent()
	if not root:
		return null
	
	var floor_order = ["SecondFloor", "FirstFloor", "GroundFloor"]
	var current_index = floor_order.find(name)
	
	if current_index == -1 or current_index >= floor_order.size() - 1:
		return null  # No floor below
	
	var below_floor_name = floor_order[current_index + 1]
	return root.get_node_or_null(below_floor_name)

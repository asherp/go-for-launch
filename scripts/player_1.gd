extends CharacterBody2D

const max_speed := 40.0
const min_speed := 8.0
const time_to_max_speed := 0.1
const time_to_stop := 0.05
const time_to_turn := 0.05

const acceleration := max_speed / time_to_max_speed
const friction := max_speed / time_to_stop
const turn_speed := max_speed / time_to_turn

# Jump and height constants
const jump_strength := 60.0  # How high the player jumps
const gravity := 240.0  # How fast player falls
const ground_height := 0.0  # Default ground level

var dir_input := Vector2.ZERO
var z_height := 0.0  # Simulated Z-axis height
var z_velocity := 0.0  # Vertical velocity for jumping
var ground_z := ground_height  # Height of current tile
var current_direction := Vector2.ZERO  # Current movement direction (locked)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sprite_alt: Sprite2D = get_node_or_null("Player")

func _ready() -> void:
	# Try to find the sprite node with either name
	if sprite == null:
		sprite = sprite_alt
	if sprite == null:
		push_warning("No Sprite2D child found! Jump visual won't work.")

func _physics_process(delta: float) -> void:
	# Get tilemap to check ground height
	var tilemap = get_parent().get_node_or_null("TileMapLayer")
	if tilemap:
		var tile_pos = tilemap.local_to_map(position)
		var tile_id = tilemap.get_cell_source_id(tile_pos)
		if tile_id != -1:
			# Player is over a valid tile
			ground_z = ground_height
		# You can add custom heights per tile here later
	
	# Handle jump input (spacebar)
	if Input.is_action_just_pressed("jump") and z_height <= ground_z + 1.0:
		z_velocity = jump_strength
		print("Jump! z_velocity: ", z_velocity)
	
	# Apply gravity to z_velocity
	z_velocity -= gravity * delta
	z_height += z_velocity * delta
	
	# Clamp to ground
	if z_height <= ground_z:
		z_height = ground_z
		z_velocity = 0.0
	
	# Update sprite position to show height
	if sprite:
		sprite.position.y = -6 - z_height
	
	# Handle horizontal movement (4-directional diagonal only, Pac-Man style)
	# Define the 4 isometric diagonal directions (32x16 tiles = 2:1 ratio)
	var northeast := Vector2(2, -1).normalized()  # Up-right on screen
	var southeast := Vector2(2, 1).normalized()   # Down-right on screen
	var southwest := Vector2(-2, 1).normalized()  # Down-left on screen
	var northwest := Vector2(-2, -1).normalized() # Up-left on screen
	
	# Check for newly pressed keys (just pressed this frame takes priority)
	var right_just_pressed := Input.is_action_just_pressed("ui_right")
	var left_just_pressed := Input.is_action_just_pressed("ui_left")
	var up_just_pressed := Input.is_action_just_pressed("ui_up")
	var down_just_pressed := Input.is_action_just_pressed("ui_down")
	
	# Update direction based on the most recently pressed key
	if right_just_pressed:
		current_direction = southeast  # East = down-right
	elif left_just_pressed:
		current_direction = northwest  # West = up-left
	elif up_just_pressed:
		current_direction = northeast  # North = up-right
	elif down_just_pressed:
		current_direction = southwest  # South = down-left
	
	# Check if any directional key is currently held
	var right_pressed := Input.is_action_pressed("ui_right")
	var left_pressed := Input.is_action_pressed("ui_left")
	var up_pressed := Input.is_action_pressed("ui_up")
	var down_pressed := Input.is_action_pressed("ui_down")
	var any_key_pressed := right_pressed or left_pressed or up_pressed or down_pressed
	
	if any_key_pressed:
		
		# Move in the current direction
		if !current_direction.is_equal_approx(velocity.normalized()) and velocity.length() > 0.1:
			velocity += current_direction * turn_speed * delta
		else:
			velocity += current_direction * acceleration * delta
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
		
		# Snap to isometric grid based on movement direction
		# Convert screen position to isometric coordinates
		# iso_x and iso_y represent position in isometric grid space
		var iso_x = (position.x / 32.0) + (position.y / 16.0)
		var iso_y = (position.y / 16.0) - (position.x / 32.0)
		
		if current_direction == southeast or current_direction == northwest:
			# Moving along iso_x axis (east/west) - lock iso_y to integer
			iso_y = round(iso_y)
		elif current_direction == northeast or current_direction == southwest:
			# Moving along iso_y axis (north/south) - lock iso_x to integer
			iso_x = round(iso_x)
		
		# Convert back to screen coordinates
		position.x = (iso_x - iso_y) * 16.0
		position.y = (iso_x + iso_y) * 8.0
	else:
		# No keys pressed - reset direction lock and apply friction
		current_direction = Vector2.ZERO
		if velocity != Vector2.ZERO:
			velocity -= velocity.normalized() * friction * delta 
			if velocity.length() < min_speed:
				velocity = Vector2.ZERO
	
	move_and_slide()

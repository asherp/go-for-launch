extends Camera2D

## Smooth camera that follows a target node with interpolation
## Usage: Set the target node path in the inspector or via code

# The node this camera will follow
@export var target: Node2D

# How quickly the camera follows (higher = faster, 1.0 = instant)
@export_range(0.01, 1.0) var follow_speed: float = 0.1

# Optional: Add camera offset from the target
@export var target_offset: Vector2 = Vector2.ZERO

# Optional: Enable position smoothing
@export var use_smoothing: bool = true

# Optional: Deadzone - camera won't move until target leaves this area
@export var deadzone_width: float = 0.0
@export var deadzone_height: float = 0.0

func _ready() -> void:
	# Find the player target
	_find_target()
	
	# Initialize camera position to target position
	if target:
		global_position = target.global_position + target_offset

func _find_target() -> void:
	"""Find the target node if not already set."""
	if not target:
		# Try to find by group first (best for multi-floor scenarios)
		target = get_tree().get_first_node_in_group("player")
		if not target:
			# Fallback: try common player node names
			target = get_node_or_null("../Player1")
		if not target:
			target = get_node_or_null("../Player")
		
		if not target:
			push_warning("SmoothCamera: No target set and couldn't find player!")

func _process(_delta: float) -> void:
	# Dynamically find target if it's lost (handles reparenting across floors)
	if not is_instance_valid(target):
		_find_target()
	
	if not target:
		return
	
	var target_pos = target.global_position + target_offset
	
	if use_smoothing:
		# Check deadzone
		if deadzone_width > 0 or deadzone_height > 0:
			var distance = target_pos - global_position
			var abs_distance = distance.abs()
			
			# Only move if outside deadzone
			if abs_distance.x > deadzone_width / 2.0 or abs_distance.y > deadzone_height / 2.0:
				# Smooth interpolation
				global_position = global_position.lerp(target_pos, follow_speed)
		else:
			# Smooth interpolation without deadzone
			global_position = global_position.lerp(target_pos, follow_speed)
	else:
		# Instant following (no smoothing)
		global_position = target_pos


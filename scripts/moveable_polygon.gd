extends CharacterBody2D

@export var speed: float = 200.0
@export var drag: float = 0.9

var is_selected: bool = false

func _ready():
	# Add to the moveable group for easy access
	add_to_group("moveable")

func _physics_process(delta):
	# Only handle physics if being dragged
	if is_selected:
		# Apply any velocity from dragging
		set_velocity(velocity)
		move_and_slide()
		velocity = velocity

func _input(event):
	# Handle mouse input for selection and dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is within polygon bounds
				var mouse_pos = get_global_mouse_position()
				var distance = global_position.distance_to(mouse_pos)
				
				# Simple circular selection area (you can make this more precise)
				if distance < 30:
					select_polygon()
					# Consume the event to prevent player navigation
					get_viewport().set_input_as_handled()
			else:
				# Release when mouse button is released
				if is_selected:
					deselect_polygon()
					# Consume the event to prevent player navigation
					get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_selected:
		# Drag the polygon when selected
		var mouse_pos = get_global_mouse_position()
		var direction = (mouse_pos - global_position).normalized()
		var distance = global_position.distance_to(mouse_pos)
		velocity = direction * min(distance * 10, speed)  # Smooth dragging with speed limit
		# Consume the event to prevent player navigation
		get_viewport().set_input_as_handled()

func select_polygon():
	is_selected = true
	# Change color to indicate selection
	$Polygon2D.color = Color(1, 0.5, 0.2, 0.8)  # Orange when selected

func deselect_polygon():
	is_selected = false
	velocity = Vector2.ZERO  # Stop movement when deselected
	# Return to original color
	$Polygon2D.color = Color(0.2, 0.8, 1, 0.8)  # Blue when not selected

func _draw():
	# Optional: Draw selection indicator
	if is_selected:
		draw_circle(Vector2.ZERO, 25, Color(1, 1, 0, 0.3))

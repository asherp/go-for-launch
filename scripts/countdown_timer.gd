extends Label

# Countdown timer configuration
@export var start_time: float = 30.0
@export var font_size: int = 32

var time_remaining: float = 0.0
var is_running: bool = false

signal timer_finished
signal timer_updated(time_left: float)

func _ready():
	# Set initial properties
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_theme_font_size_override("font_size", font_size)
	
	# Add outline for better visibility
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 2)
	
	# Start the timer
	reset_timer()

func _process(delta):
	if is_running:
		time_remaining -= delta
		
		if time_remaining <= 0:
			time_remaining = 0
			is_running = false
			print("[CountdownTimer] Timer finished! Emitting signal...")
			timer_finished.emit()
		
		update_display()
		timer_updated.emit(time_remaining)

func update_display():
	var minutes = floori(time_remaining / 60.0)
	var seconds = int(time_remaining) % 60
	var milliseconds = int((time_remaining - int(time_remaining)) * 100)
	
	# Color changes based on time remaining
	if time_remaining <= 10:
		add_theme_color_override("font_color", Color.RED)
	elif time_remaining <= 20:
		add_theme_color_override("font_color", Color.YELLOW)
	else:
		add_theme_color_override("font_color", Color.WHITE)
	
	text = "%02d:%02d.%02d" % [minutes, seconds, milliseconds]

func reset_timer():
	time_remaining = start_time
	is_running = true
	update_display()
	print("[CountdownTimer] Timer reset to %.1f seconds" % start_time)

func pause_timer():
	is_running = false

func resume_timer():
	is_running = true

func stop_timer():
	is_running = false
	time_remaining = 0
	update_display()


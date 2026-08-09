extends Camera2D
@export var map: Sprite2D

var is_dragging :bool = false
@export_group("Zoom Settings")
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.5

func _ready() -> void:
	if map and map.texture:
		setup_limits()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Right Click Drag toggle
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed

		# Scroll Up -> Zoom In
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(zoom_step)

		# Scroll Down -> Zoom Out
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(-zoom_step)

	if event is InputEventMouseMotion:
		if is_dragging:
			position -= event.relative / zoom
			clamp_camera_position()


func setup_limits() -> void:
	var size: Vector2 = map.texture.get_size() * map.global_scale
	var top_left: Vector2 = map.global_position
	if map.centered:
		top_left -= size * 0.5
		
	limit_left = int(top_left.x)
	limit_top = int(top_left.y)
	limit_right = int(top_left.x + size.x)
	limit_bottom = int(top_left.y + size.y)
	
func adjust_zoom(amount: float) -> void:
	# Clamp zoom value within limits
	var new_zoom_val: float = clamp(zoom.x + amount, min_zoom, max_zoom)
	zoom = Vector2(new_zoom_val, new_zoom_val)

	# Re-clamp position so zooming out doesn't reveal areas outside the map limits
	clamp_camera_position()

func clamp_camera_position() -> void:
	var half_view_size: Vector2 = (get_viewport_rect().size / zoom) * 0.5

	var min_x: float = limit_left + half_view_size.x
	var max_x: float = limit_right - half_view_size.x
	var min_y: float = limit_top + half_view_size.y
	var max_y: float = limit_bottom - half_view_size.y

	if min_x > max_x:
		position.x = (limit_left + limit_right) / 2.0
	else:
		position.x = clamp(position.x, min_x, max_x)

	if min_y > max_y:
		position.y = (limit_top + limit_bottom) / 2.0
	else:
		position.y = clamp(position.y, min_y, max_y)

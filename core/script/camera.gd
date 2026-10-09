extends Camera2D
@export var map: Sprite2D

@export var target: Node2D
@export var follow_speed: float = 8.0

@export_group("Zoom Settings")
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.5

func _ready() -> void:
	if map and map.texture:
		setup_limits()

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		var weight = 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(target.global_position, weight)
		clamp_camera_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(zoom_step)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(-zoom_step)


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

extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D

var is_hovered: bool = false

func _ready() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# Ensure material is unique to this instance
	if sprite_2d.material:
		sprite_2d.material = sprite_2d.material.duplicate()
	_set_highlight(false)

func _on_mouse_entered() -> void:
	is_hovered = true
	_set_highlight(true)

func _on_mouse_exited() -> void:
	is_hovered = false
	_set_highlight(false)

# Failsafe check: if mouse leaves the area unexpectedly, clear highlight
func _process(_delta: float) -> void:
	if is_hovered and not _is_mouse_over_shape():
		is_hovered = false
		_set_highlight(false)

func _is_mouse_over_shape() -> bool:
	var mouse_pos = get_global_mouse_position()
	# Checks if the current global mouse position intersects this Area2D's shapes
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	for result in results:
		if result.collider == self:
			return true
	return false

func _set_highlight(active: bool) -> void:
	if sprite_2d.material:
		var thickness = 2.0 if active else 0.0
		sprite_2d.material.set_shader_parameter("line_thickness", thickness)

extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D

var is_hovered: bool = false
var is_nearby: bool = false
var location_label: Label

func _ready() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# Ensure material is unique to this instance
	if sprite_2d.material:
		sprite_2d.material = sprite_2d.material.duplicate()
	_setup_location_label()
	_set_highlight(false)

func _on_mouse_entered() -> void:
	is_hovered = true
	_update_highlight()

func _on_mouse_exited() -> void:
	is_hovered = false
	_update_highlight()

# Failsafe check: if mouse leaves the area unexpectedly, clear highlight
func _process(_delta: float) -> void:
	if is_hovered and not _is_mouse_over_shape():
		is_hovered = false
		_update_highlight()

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

func set_proximity_highlight(active: bool) -> void:
	is_nearby = active
	_update_highlight()

func _update_highlight() -> void:
	var active := is_hovered or is_nearby
	var was_visible := location_label != null and location_label.visible
	_set_highlight(active)
	if location_label:
		location_label.visible = active
		if active and not was_visible:
			location_label.scale = Vector2(0.75, 0.75)
			location_label.modulate = Color(1, 1, 1, 0)
			var reveal = create_tween().set_parallel(true)
			reveal.tween_property(location_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			reveal.tween_property(location_label, "modulate", Color.WHITE, 0.14)

func _setup_location_label() -> void:
	location_label = Label.new()
	location_label.text = "  " + name.to_upper() + "  "
	location_label.position = Vector2(-72, -108)
	location_label.size = Vector2(144, 30)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_label.z_index = 10
	location_label.add_theme_font_size_override("font_size", 14)
	location_label.add_theme_color_override("font_color", Color("#4b1d13"))
	location_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.96, 0.87, 0.85))
	location_label.add_theme_constant_override("shadow_offset_x", 2)
	location_label.add_theme_constant_override("shadow_offset_y", 2)
	location_label.add_theme_constant_override("shadow_outline_size", 3)

	var badge = StyleBoxFlat.new()
	badge.bg_color = Color("#f7e8cd")
	badge.border_color = Color("#78301f")
	badge.set_border_width_all(2)
	badge.set_corner_radius_all(6)
	badge.content_margin_left = 8.0
	badge.content_margin_right = 8.0
	badge.content_margin_top = 3.0
	badge.content_margin_bottom = 3.0
	badge.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	badge.shadow_size = 4
	badge.shadow_offset = Vector2(0, 3)
	location_label.add_theme_stylebox_override("normal", badge)
	location_label.hide()
	add_child(location_label)

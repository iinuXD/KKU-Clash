extends CharacterBody2D

signal activity_requested(place: Node2D)

@export var speed: float = 180.0

var movement_enabled: bool = false
var nearby_place: Node2D
var nearby_area: Area2D
var nearby_areas: Array[Area2D] = []
@onready var interaction_area: Area2D = $InteractionArea
@onready var animation_player: AnimationPlayer = $Panel/CenterPoint/AnimationPlayer

func _ready() -> void:
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

func _physics_process(_delta: float) -> void:
	if get_tree().paused or not movement_enabled:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		direction = global_position.direction_to(get_global_mouse_position())
	velocity = direction * speed
	move_and_slide()
	_refresh_nearest_place()

	if direction.length_squared() > 0.0:
		_play_walk_animation(direction)
	else:
		animation_player.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not get_tree().paused and movement_enabled and event.is_action_pressed("interact") and nearby_place:
		activity_requested.emit(nearby_place)

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		animation_player.play("idle")

func _on_area_entered(area: Area2D) -> void:
	if not nearby_areas.has(area):
		nearby_areas.append(area)
	_refresh_nearest_place()

func _on_area_exited(area: Area2D) -> void:
	nearby_areas.erase(area)
	_refresh_nearest_place()

func _refresh_nearest_place() -> void:
	var nearest_area: Area2D
	var nearest_distance := INF

	for area in nearby_areas:
		if not is_instance_valid(area):
			continue
		var distance = global_position.distance_squared_to(area.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_area = area

	if nearby_area != nearest_area:
		if nearby_area and is_instance_valid(nearby_area) and nearby_area.has_method("set_proximity_highlight"):
			nearby_area.set_proximity_highlight(false)
		nearby_area = nearest_area
		if nearby_area and nearby_area.has_method("set_proximity_highlight"):
			nearby_area.set_proximity_highlight(true)

	nearby_place = nearby_area

func _play_walk_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		animation_player.play("walk_right" if direction.x > 0.0 else "walk_left")
	else:
		animation_player.play("walk_down" if direction.y > 0.0 else "walk_up")

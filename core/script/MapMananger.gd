extends Node2D

@onready var path = $Path2D
@onready var path_follow = $Path2D/PathFollow2D
@onready var game_manager = $".." # Reference to MainGame

var current_location_pos: Vector2
var is_moving = false
func _ready():
	# Set starting position to the Dorm
	current_location_pos = $Locations/Dorm.global_position
	
	# Optional: Snap the player instantly to the dorm at start
	path.curve = Curve2D.new()
	path.curve.add_point(current_location_pos)
	path_follow.progress_ratio = 0.0
	

#signal 
func _on_food_court_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	pass # Replace with function body.


func _on_study_hall_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	pass # Replace with function body.


func _on_dorm_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	pass # Replace with function body.


#movement logic
func is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressedd
	
func attempt_travel(target_pos: Vector2, location_name: String):
	if is_moving:
		return # Prevent clicking while already traveling
		
	if current_location_pos == target_pos:
		print("You are already at the ", location_name)
		return
		
	if Global.time_remaining < Global.travel_time_cost:
		print("Not enough time to travel!")
		return

	print("Traveling to ", location_name)
	travel_to_location(current_location_pos, target_pos)
	current_location_pos = target_pos # Update for next time

func travel_to_location(start_pos: Vector2, target_pos: Vector2):
	is_moving = true
	
	# Deduct costs via GameManager
	game_manager.spend_time(Global.travel_time_cost)
	Global.update_stat("energy", -Global.travel_energy_cost)
	
	# Draw the path
	var curve = Curve2D.new()
	curve.add_point(start_pos)
	curve.add_point(target_pos)
	path.curve = curve
	
	# Animate the player along the path
	path_follow.progress_ratio = 0.0
	var tween = create_tween()
	tween.tween_property(path_follow, "progress_ratio", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	is_moving = false
	print("Arrived!")
	
	# THIS is where we will eventually pop up the Action Menu!

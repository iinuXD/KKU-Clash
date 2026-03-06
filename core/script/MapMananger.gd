extends Node2D

@onready var path = $Path2D
@onready var path_follow = $Path2D/PathFollow2D
@onready var game_manager = $".." # Reference to MainGame

var astar = AStar2D.new()
var waypoint_ids = {} # This will help us remember which point is which

var current_location_pos: Vector2
var is_moving = false

func _ready():
	# Set starting position to the Dorm
	current_location_pos = $Locations/Dorm.global_position
	
	# Optional: Snap the player instantly to the dorm at start
	path.curve = Curve2D.new()
	path.curve.add_point(current_location_pos)
	#path_follow.progress_ratio = 0.0
	setup_pathfinding()
	

# --- SIGNALS ---
# Added underscores to _viewport and _shape_idx to clear the warnings
# Fixed paths to match $"../Locations/..." so it doesn't crash!

func _on_food_court_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/FoodCourt.global_position, "Food Court")

func _on_study_hall_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/StudyHall.global_position, "Study Hall")

func _on_dorm_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/Dorm.global_position, "Dorm")

func _on_hospital_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/Hospital.global_position, "Hospital")

func _on_library_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/Library.global_position, "Library")

func _on_sport_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/Sport.global_position, "Sport")

func _on_shop_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/Shop.global_position, "Shop")

func _on_fun_place_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_left_click(event): attempt_travel($Locations/FunPlace.global_position, "Fun Place")


# --- MOVEMENT LOGIC ---

func is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	
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
	travel_to_location(current_location_pos, target_pos, location_name)
	current_location_pos = target_pos # Update for next time

func travel_to_location(start_pos: Vector2, target_pos: Vector2, location_name: String):
	is_moving = true
	
	# Deduct costs
	game_manager.spend_time(Global.travel_time_cost)
	Global.update_stat("energy", -Global.travel_energy_cost)
	
	# --- NEW ASTAR ROUTING ---
	
	# Ask AStar which ID is closest to our Start and End positions
	var start_id = astar.get_closest_point(start_pos)
	var end_id = astar.get_closest_point(target_pos)
	
	# Get the array of Vector2 points that form the road path
	var path_route = astar.get_point_path(start_id, end_id)
	
	# Build the curve using the points AStar gave us
	var curve = Curve2D.new()
	for point in path_route:
		curve.add_point(path.to_local(point))
		
	path.curve = curve
	
	# -------------------------
	
	# Animate the player along the new curving path
	path_follow.progress_ratio = 0.0
	var tween = create_tween()
	# Optional: calculate tween time based on how long the road is!
	var travel_time = path_route.size() * 0.3 # 0.3 seconds per dot
	tween.tween_property(path_follow, "progress_ratio", 1.0, travel_time).set_trans(Tween.TRANS_LINEAR)
	
	await tween.finished
	is_moving = false
	print("Arrived at ", location_name, "!")
	
func setup_pathfinding():
	var id = 0
	for point in $Waypoints.get_children():
		astar.add_point(id, point.global_position)
		waypoint_ids[point.name] = id
		id += 1
		
	# 2. Connect the roads! 
	connect_points("Dorm", "Intersec1")
	connect_points("Intersec1", "Hospital")
	connect_points("Hospital", "Corner1")
	connect_points("Corner1", "Corner2")
	connect_points("Corner2", "Sport")
	connect_points("Sport", "Library")
	connect_points("Library", "Corner3")
	connect_points("Corner3", "StudyHall")
	connect_points("StudyHall", "Corner4")
	connect_points("Corner4", "FoodCourt")
	connect_points("FoodCourt", "Shop")
	connect_points("Shop", "Corner5")
	connect_points("Corner5", "FunPlace")
	connect_points("FunPlace", "Intersec1")

func connect_points(point_name_a: String, point_name_b: String):
	if waypoint_ids.has(point_name_a) and waypoint_ids.has(point_name_b):
		var id_a = waypoint_ids[point_name_a]
		var id_b = waypoint_ids[point_name_b]
		astar.connect_points(id_a, id_b)
	else:
		print("ERROR: Check your spelling! Couldn't connect ", point_name_a, " to ", point_name_b)
	# If your UILayer is set up, uncomment this next line to open the menu!
	# get_node("../UILayer").open_action_menu(location_name)

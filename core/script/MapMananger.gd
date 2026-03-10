extends Node2D

signal returned_to_dorm()

@onready var path = $Path2D
@onready var path_follow = $Path2D/PathFollow2D
@onready var game_manager = $".." # Reference to MainGame
@onready var activity_ui = $"../ActivityUI"

var astar = AStar2D.new()
var waypoint_ids = {} # This will help us remember which point is which

var current_location_pos: Vector2
var current_location_name: String = "Dorm"
var is_moving = false
var current_activities: Array[Dictionary] = []
var _current_tween: Tween = null

# ---------------------------------------------------------------
# ACTIVITY DATA
# Each activity: id, name, time, energy, hunger, happy, study, money, special
# ---------------------------------------------------------------
func _get_location_data(location_name: String) -> Dictionary:
	match location_name:
		"Dorm":
			return {
				"dialog": "Home sweet home. What would you like to do?",
				"activities": [
					{"id":"sleep",        "name":"Sleep (3h)",          "time":3, "energy":40,  "hunger":-10, "happy":5,   "study":0, "money":0,    "special":"sleep"},
					{"id":"nap",          "name":"Quick Nap (1h)",       "time":1, "energy":15,  "hunger":-5,  "happy":0,   "study":0, "money":0,    "special":""},
					{"id":"study_home",   "name":"Study at Home (2h)",   "time":2, "energy":-10, "hunger":-10, "happy":-5,  "study":2, "money":0,    "special":""},
					{"id":"take_medicine","name":"Take Medicine (1h)",   "time":1, "energy":5,   "hunger":0,   "happy":0,   "study":0, "money":0,    "special":"take_medicine"},
				]
			}
		"Food Court":
			return {
				"dialog": "Something smells amazing! What'll you have?",
				"activities": [
					{"id":"full_meal",   "name":"Full Meal (1h) -$200",     "time":1, "energy":10,  "hunger":50, "happy":5,  "study":0, "money":-200, "special":""},
					{"id":"quick_snack", "name":"Quick Snack (1h) -$100",   "time":1, "energy":5,   "hunger":25, "happy":0,  "study":0, "money":-100, "special":""},
					{"id":"coffee",      "name":"Coffee (1h) -$50",         "time":1, "energy":20,  "hunger":-5, "happy":5,  "study":0, "money":-50,  "special":""},
					{"id":"treat",       "name":"Treat Yourself! (1h) -$300","time":1, "energy":10, "hunger":30, "happy":20, "study":0, "money":-300, "special":""},
				]
			}
		"Study Hall":
			return {
				"dialog": "Time to hit the books! How hard will you study?",
				"activities": [
					{"id":"study_hard",   "name":"Study Hard (3h)",    "time":3, "energy":-20, "hunger":-15, "happy":-10, "study":4, "money":0, "special":""},
					{"id":"casual_study", "name":"Casual Study (2h)",  "time":2, "energy":-10, "hunger":-10, "happy":-5,  "study":2, "money":0, "special":""},
					{"id":"group_study",  "name":"Group Study (2h)",   "time":2, "energy":-5,  "hunger":-5,  "happy":10,  "study":2, "money":0, "special":""},
					{"id":"leave",        "name":"Leave",               "time":0, "energy":0,   "hunger":0,   "happy":0,   "study":0, "money":0, "special":"leave"},
				]
			}
		"Library":
			return {
				"dialog": "Shh! Welcome to the library.",
				"activities": [
					{"id":"quiet_study", "name":"Quiet Study (2h)",    "time":2, "energy":-15, "hunger":-10, "happy":0,   "study":3, "money":0, "special":""},
					{"id":"read_fun",    "name":"Read for Fun (1h)",    "time":1, "energy":-5,  "hunger":0,   "happy":10,  "study":1, "money":0, "special":""},
					{"id":"research",    "name":"Deep Research (3h)",   "time":3, "energy":-25, "hunger":-20, "happy":-10, "study":5, "money":0, "special":""},
					{"id":"leave",       "name":"Leave",                "time":0, "energy":0,   "hunger":0,   "happy":0,   "study":0, "money":0, "special":"leave"},
				]
			}
		"Hospital":
			return {
				"dialog": "Welcome to the hospital. How can we help?",
				"activities": [
					{"id":"buy_medicine",   "name":"Buy Medicine -$300",    "time":1, "energy":0,  "hunger":0,   "happy":0, "study":0, "money":-300, "special":"buy_medicine"},
					{"id":"checkup",        "name":"Get Checkup -$200",     "time":1, "energy":0,  "hunger":0,   "happy":0, "study":0, "money":-200, "special":"checkup"},
					{"id":"hospital_rest",  "name":"Rest & Recover (2h)",   "time":2, "energy":30, "hunger":-10, "happy":0, "study":0, "money":0,    "special":"hospital_rest"},
					{"id":"buy_bandage",    "name":"Buy Bandage -$100",     "time":1, "energy":0,  "hunger":0,   "happy":0, "study":0, "money":-100, "special":"buy_bandage"},
				]
			}
		"Shop":
			return {
				"dialog": "Welcome! What are you shopping for?",
				"activities": [
					{"id":"buy_groceries", "name":"Buy Groceries -$200",   "time":1, "energy":0,  "hunger":20, "happy":5,  "study":0, "money":-200, "special":""},
					{"id":"energy_drink",  "name":"Energy Drink -$100",    "time":1, "energy":30, "hunger":-5, "happy":0,  "study":0, "money":-100, "special":""},
					{"id":"shop_medicine", "name":"Buy Medicine -$300",    "time":1, "energy":0,  "hunger":0,  "happy":0,  "study":0, "money":-300, "special":"buy_medicine"},
					{"id":"leave",         "name":"Leave",                  "time":0, "energy":0,  "hunger":0,  "happy":0,  "study":0, "money":0,    "special":"leave"},
				]
			}
		"Sport":
			return {
				"dialog": "Ready to break a sweat?",
				"activities": [
					{"id":"jog",           "name":"Morning Jog (2h)",     "time":2, "energy":-20, "hunger":-15, "happy":20, "study":0, "money":0, "special":""},
					{"id":"play_sport",    "name":"Play Sport (2h)",      "time":2, "energy":-25, "hunger":-20, "happy":25, "study":0, "money":0, "special":""},
					{"id":"light_workout", "name":"Light Workout (1h)",   "time":1, "energy":-10, "hunger":-10, "happy":15, "study":0, "money":0, "special":""},
					{"id":"leave",         "name":"Leave",                 "time":0, "energy":0,   "hunger":0,   "happy":0,  "study":0, "money":0, "special":"leave"},
				]
			}
		"Fun Place":
			return {
				"dialog": "This is the place to be! What's your vibe?",
				"activities": [
					{"id":"play_games",  "name":"Play Games (2h) -$200",  "time":2, "energy":-10, "hunger":-5, "happy":25, "study":0, "money":-200, "special":""},
					{"id":"watch_movie", "name":"Watch Movie (2h) -$200", "time":2, "energy":-5,  "hunger":-5, "happy":30, "study":0, "money":-200, "special":""},
					{"id":"karaoke",     "name":"Karaoke (2h) -$300",     "time":2, "energy":-15, "hunger":-5, "happy":35, "study":0, "money":-300, "special":""},
					{"id":"hangout",     "name":"Hang Out (1h)",           "time":1, "energy":-5,  "hunger":-5, "happy":10, "study":0, "money":0,    "special":""},
				]
			}
	return {}

# ---------------------------------------------------------------
# ACTIVITY UI LOGIC
# ---------------------------------------------------------------
func show_activity_ui(location_name: String) -> void:
	var data = _get_location_data(location_name)
	if data.is_empty():
		return
	var raw_activities: Array = data["activities"]
	current_activities.clear()
	for a in raw_activities:
		current_activities.append(a)
	var activity_list: Array[Dictionary] = []
	for act in current_activities:
		activity_list.append({"id": act["id"], "name": act["name"]})
	activity_ui.setup(location_name, null, data["dialog"], activity_list)
	activity_ui.visible = true

func _on_activity_selected(activity_id: String) -> void:
	activity_ui.visible = false
	for act in current_activities:
		if act["id"] == activity_id:
			_perform_activity(act)
			return

func _perform_activity(activity: Dictionary) -> void:
	var special: String = activity.get("special", "")

	# Leave just closes the UI
	if special == "leave":
		return

	# Check if player can afford the activity
	var money_change: int = activity.get("money", 0)
	if money_change < 0 and Global.money < -money_change:
		print("Not enough money for: ", activity["name"])
		activity_ui.visible = true  # Re-show so player can pick another
		return

	# Apply stat changes FIRST so effects are counted even if time runs out mid-activity
	Global.update_stat("energy",      activity.get("energy", 0))
	Global.update_stat("happy",       activity.get("happy",  0))
	Global.update_stat("hunger",      activity.get("hunger", 0))
	Global.update_stat("money",       money_change)
	Global.update_stat("study_score", activity.get("study",  0))

	# Handle special effects
	match special:
		"sleep":
			if Global.is_sick:
				Global.sick_sleep_count += 1
				if Global.sick_sleep_count >= 3:
					Global.is_sick = false
					print("Slept it off — you've recovered from sickness!")
				else:
					print("Still sick... sleep more to recover (%d/3)." % Global.sick_sleep_count)
		"take_medicine":
			if Global.is_sick and Global.has_medicine:
				Global.is_sick = false
				Global.has_medicine = false
				print("Medicine taken! You feel much better.")
			elif Global.is_sick:
				print("You're sick but have no medicine. Buy some at the Hospital or Shop.")
			else:
				print("You're not sick right now.")
		"buy_medicine":
			Global.has_medicine = true
			print("Medicine purchased! Use it at the Dorm.")
		"checkup":
			if Global.is_sick:
				Global.is_sick = false
				print("The doctor treated your sickness. You're cured!")
			else:
				print("You're healthy! The doctor gives you a clean bill of health.")
		"hospital_rest":
			if Global.is_injured:
				Global.is_injured = false
				Global.travel_time_cost = max(Global.travel_time_cost - 1, 2)
				print("Rest healed your injury!")
			else:
				print("Rest and recovery complete. Feeling refreshed!")
		"buy_bandage":
			if Global.is_injured:
				Global.is_injured = false
				Global.travel_time_cost = max(Global.travel_time_cost - 1, 2)
				print("Bandage applied — injury healed!")
			else:
				print("You're not injured, but you now have a bandage just in case.")

	print("Completed: ", activity["name"])

	# Spend time last — if time runs out this triggers end_round → snap_to_dorm → new round,
	# but all activity effects have already been applied above.
	var time_cost: int = activity.get("time", 0)
	if time_cost > 0:
		game_manager.spend_time(time_cost)

	# Fire a contextual eat event after food activities (35% chance, only if round still active)
	var food_ids = ["full_meal", "quick_snack", "coffee", "treat", "buy_groceries"]
	if activity.get("id", "") in food_ids and Global.time_remaining > 0:
		game_manager.fire_context_event("eat", 35)

func _ready():
	# Set starting position to the Dorm
	current_location_pos = $Locations/Dorm.global_position

	# Snap the player instantly to the dorm at start
	path.curve = Curve2D.new()
	path.curve.add_point(current_location_pos)
	setup_pathfinding()

	# Connect activity UI signal and hide it initially
	activity_ui.visible = false
	activity_ui.activity_selected.connect(_on_activity_selected)

func snap_to_dorm() -> void:
	# Cancel any in-progress movement and stop the tween so it can't override progress_ratio
	if _current_tween:
		_current_tween.kill()
		_current_tween = null
	is_moving = false
	activity_ui.visible = false

	var dorm_pos = $Locations/Dorm.global_position
	current_location_pos = dorm_pos
	current_location_name = "Dorm"

	# Rebuild the path curve to just the dorm point so PathFollow2D lands there
	path.curve = Curve2D.new()
	path.curve.add_point(path.to_local(dorm_pos))
	path_follow.progress_ratio = 0.0

## Animates the player back to Dorm using pathfinding; emits returned_to_dorm when done.
func travel_to_dorm() -> void:
	activity_ui.visible = false
	if current_location_name == "Dorm":
		returned_to_dorm.emit()
		return

	# Kill any existing tween
	if _current_tween:
		_current_tween.kill()
		_current_tween = null
	is_moving = true

	var dorm_pos = $Locations/Dorm.global_position
	var start_id = astar.get_closest_point(current_location_pos)
	var end_id   = astar.get_closest_point(dorm_pos)
	var path_route = astar.get_point_path(start_id, end_id)

	var curve = Curve2D.new()
	for point in path_route:
		curve.add_point(path.to_local(point))
	path.curve = curve

	path_follow.progress_ratio = 0.0
	_current_tween = create_tween()
	var travel_time = path_route.size() * 0.3
	_current_tween.tween_property(path_follow, "progress_ratio", 1.0, travel_time).set_trans(Tween.TRANS_LINEAR)

	await _current_tween.finished
	_current_tween = null
	is_moving = false
	current_location_pos = dorm_pos
	current_location_name = "Dorm"
	returned_to_dorm.emit()


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
		show_activity_ui(location_name)
		return

	print("Traveling to ", location_name)
	travel_to_location(current_location_pos, target_pos, location_name)
	current_location_pos = target_pos # Update for next time
	current_location_name = location_name

func travel_to_location(start_pos: Vector2, target_pos: Vector2, location_name: String):
	is_moving = true
	var round_at_start: int = Global.current_round
	
	# --- ASTAR ROUTING (must happen before spend_time so we know the distance) ---

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

	# Calculate in-game time cost from actual road distance (pixels).
	# Sum up each segment length so crossing many short hops is still counted correctly.
	var road_distance: float = 0.0
	for i in range(1, path_route.size()):
		road_distance += path_route[i - 1].distance_to(path_route[i])
	# Each 200 px ≈ 1 in-game hour; clamp to 1–4 hours.
	var base_time_cost: int = clampi(int(road_distance / 200.0), 1, 4)
	# Apply any active penalty (injury, event effect, etc.) on top.
	var time_cost: int = base_time_cost + (Global.travel_time_cost - 2)
	time_cost = clampi(time_cost, 1, 4)
	print("Travel distance: %.0f px → %d hour(s)" % [road_distance, time_cost])

	# Deduct costs
	game_manager.spend_time(time_cost)
	Global.update_stat("energy", -Global.travel_energy_cost)

	# Animate the player along the new curving path
	path_follow.progress_ratio = 0.0
	_current_tween = create_tween()
	var travel_time = path_route.size() * 0.3  # 0.3 seconds per waypoint dot
	_current_tween.tween_property(path_follow, "progress_ratio", 1.0, travel_time).set_trans(Tween.TRANS_LINEAR)
	
	await _current_tween.finished
	is_moving = false
	if Global.current_round == round_at_start:
		# Fire a travel event (25% chance); show activity UI only after card is dismissed
		game_manager.fire_context_event_then("travel", 25, func():
			if Global.current_round == round_at_start:
				print("Arrived at ", location_name, "!")
				show_activity_ui(location_name)
		)
	
func setup_pathfinding():
	var id = 0
	for point in $Waypoints.get_children():
		astar.add_point(id, point.global_position)
		waypoint_ids[point.name] = id
		id += 1
		
	# 2. Connect the roads! 
	connect_points("Dorm", "Intersection1")
	connect_points("Intersection1", "Shop")
	connect_points("Shop", "FoodCourt")
	connect_points("FoodCourt", "Corner1")
	connect_points("Corner1", "Intersection2")
	connect_points("Intersection2", "StudyHall")
	connect_points("StudyHall", "Intersection3")
	connect_points("Intersection3","Library")
	connect_points("Library","Intersection1")
	connect_points("Intersection2", "Hospital")
	connect_points("Hospital", "Corner2")
	connect_points("Corner2", "Intersection4")
	connect_points("Intersection4", "Intersection3")
	connect_points("Intersection4", "Corner3")
	connect_points("Corner3", "Sport")
	connect_points("Sport", "FunPlace")
	connect_points("FunPlace", "Corner4")
	connect_points("Corner4", "Dorm")

func connect_points(point_name_a: String, point_name_b: String):
	if waypoint_ids.has(point_name_a) and waypoint_ids.has(point_name_b):
		var id_a = waypoint_ids[point_name_a]
		var id_b = waypoint_ids[point_name_b]
		astar.connect_points(id_a, id_b)
	else:
		print("ERROR: Check your spelling! Couldn't connect ", point_name_a, " to ", point_name_b)
	# If your UILayer is set up, uncomment this next line to open the menu!
	# get_node("../UILayer").open_action_menu(location_name)

extends Node2D

@onready var card_event_manager = $CardEventManager
@onready var _end_game_ui: Control = $EndgameUI
var _card_event_ui: Node = null
var _round_active: bool = false

func _ready():
	if _end_game_ui:
		_end_game_ui.visible = false
	_card_event_ui = get_node_or_null("EventUI")
	if _card_event_ui and card_event_manager:
		_card_event_ui.set_card_event_manager(card_event_manager)
	if card_event_manager:
		card_event_manager.time_depleted.connect(end_round)
	start_new_round()

func spend_time(amount: int):
	Global.time_remaining -= amount
	if Global.time_remaining <= 0:
		end_round()

func start_new_round():
	_round_active = true
	Global.time_remaining = Global.max_time

	# Apply any time penalty carried over from the previous round
	if Global.next_round_time_penalty_pct > 0:
		var penalty = int(Global.max_time * Global.next_round_time_penalty_pct / 100.0)
		Global.time_remaining -= penalty
		Global.next_round_time_penalty_pct = 0

	Global.travel_time_cost = 2 # Reset travel cost
	Global.travel_energy_cost = 0 # Reset energy cost
	
	# Round 3 Bonus
	if Global.current_round == 3:
		Global.money += 2000
		print("Round 3! Received 2000 money from family.")
		
	# Reset per-round state
	Global.weather = "normal"
	Global.skip_next_activity_ui = false

	# Draw 1-2 start-of-round event cards
	if card_event_manager:
		card_event_manager.draw_start_round_events()

	print("Round ", Global.current_round, " started!")

func end_round():
	if not _round_active:
		return
	_round_active = false
	print("Time's up! Returning to Dorm.")
	var map_manager = get_node_or_null("Map")
	if map_manager:
		map_manager.returned_to_dorm.connect(_on_returned_to_dorm, CONNECT_ONE_SHOT)
		map_manager.travel_to_dorm()
	else:
		_on_returned_to_dorm()

func _on_returned_to_dorm() -> void:
	# Show 2 end-of-round cards, then advance the round after they are resolved
	if card_event_manager:
		card_event_manager.draw_end_of_round_cards()
	Global.current_round += 1
	if Global.current_round > Global.max_rounds:
		_wait_then_call(end_game)
	else:
		_wait_then_call(start_new_round)

# Calls callback immediately if no card is showing, otherwise waits for it to resolve
func _wait_then_call(callback: Callable) -> void:
	if _card_event_ui and _card_event_ui.visible:
		_card_event_ui.event_resolved.connect(callback, CONNECT_ONE_SHOT)
	else:
		callback.call()

# Fires a travel event for the given location; defers callback until card dismissed if one fires
func fire_travel_event_then(location: String, callback: Callable) -> void:
	var fired = false
	if card_event_manager:
		fired = card_event_manager.check_travel_event(location)
	if fired:
		_wait_then_call(callback)
	else:
		callback.call()

# Fires an activity event for the given location (no follow-up callback needed)
func fire_activity_event(location: String) -> void:
	if card_event_manager:
		card_event_manager.check_activity_event(location)


func end_game():
	print("--- GAME OVER ---")
	# Apply exam bonus (from card events)
	var exam_multiplier = 1.0 + (Global.exam_bonus_pct / 100.0)
	var boosted_study = int(Global.study_score * exam_multiplier)
	var final_score = (0.5 * boosted_study) + (0.1 * Global.happy) + (0.2 * Global.energy) + (0.2 * Global.hunger)
	print("Final Score: ", final_score, " (exam bonus: ", Global.exam_bonus_pct, "%)")

	get_tree().paused = true
	_end_game_ui.visible = true
	_end_game_ui.setup(final_score, Global.exam_bonus_pct)

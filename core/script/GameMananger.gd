extends Node2D

@onready var card_event_manager = $CardEventManager
var _card_event_ui: Node = null
var _round_active: bool = false

func _ready():
	_card_event_ui = get_node_or_null("EventUI")
	if _card_event_ui and card_event_manager:
		_card_event_ui.set_card_event_manager(card_event_manager)
	if card_event_manager:
		card_event_manager.time_depleted.connect(end_round)
	start_new_round()

func spend_time(amount: int):
	Global.time_remaining -= amount
	if card_event_manager:
		card_event_manager.check_mid_round_cards()
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
		
	# Queue 2 mid-round card events and show 1 start-of-round card
	if card_event_manager:
		card_event_manager.queue_mid_round_cards()
		card_event_manager.draw_start_round_card()

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

# Fires a contextual event; if one fires, defers callback until the card is resolved
func fire_context_event_then(trigger: String, chance_pct: int, callback: Callable) -> void:
	var fired = false
	if card_event_manager:
		fired = card_event_manager.check_contextual_event(trigger, chance_pct)
	if fired:
		_wait_then_call(callback)
	else:
		callback.call()

# Fires a contextual event with no follow-up callback
func fire_context_event(trigger: String, chance_pct: int) -> void:
	if card_event_manager:
		card_event_manager.check_contextual_event(trigger, chance_pct)


func end_game():
	print("--- GAME OVER ---")
	if Global.study_score >= 12:
		print("Main Quest Complete: You studied enough!")
	else:
		print("Main Quest Failed: You partied too much!")
		
	# Apply exam bonus (from card events)
	var exam_multiplier = 1.0 + (Global.exam_bonus_pct / 100.0)
	var boosted_study = int(Global.study_score * exam_multiplier)
	var final_score = (0.5 * boosted_study) + (0.1 * Global.happy) + (0.2 * Global.energy) + (0.2 * Global.hunger)
	print("Final Score: ", final_score, " (exam bonus: ", Global.exam_bonus_pct, "%)")

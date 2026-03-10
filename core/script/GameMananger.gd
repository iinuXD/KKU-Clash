extends Node2D

# Reference to the CardEventManager node (child of this node or sibling)
@onready var card_event_manager = $CardEventManager

func _ready():
	# Wire the card event UI to the manager
	var card_ui = get_node_or_null("Cardevent")
	if card_ui and card_event_manager:
		card_ui.set_card_event_manager(card_event_manager)
	start_new_round()

func spend_time(amount: int):
	Global.time_remaining -= amount
	# Mid-round probabilistic card (25% chance per spend_time call)
	if card_event_manager:
		card_event_manager.check_mid_round_cards()
	check_mid_round_events()
	
	if Global.time_remaining <= 0:
		end_round()

func start_new_round():
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
		
	trigger_start_round_event()

	# Queue 2 mid-round card events for this round
	if card_event_manager:
		card_event_manager.queue_mid_round_cards()

	print("Round ", Global.current_round, " started!")

func end_round():
	print("Time's up! Returning to Dorm.")
	# Snap the player back to Dorm via MapManager
	var map_manager = get_node_or_null("Map")
	if map_manager:
		map_manager.snap_to_dorm()

	# Show 2 end-of-round card events
	if card_event_manager:
		card_event_manager.draw_end_of_round_cards()
	
	Global.current_round += 1
	if Global.current_round > Global.max_rounds:
		end_game()
	else:
		start_new_round()

func trigger_start_round_event():
	var event_roll = randi() % 5
	match event_roll:
		0:
			print("Event: Woke up late!")
			Global.time_remaining -= 4
		1:
			print("Event: Got Sick!")
			Global.is_sick = true
			Global.sick_sleep_count = 0
			Global.has_medicine = false
		2:
			print("Event: Sudden Storm!")
			Global.travel_time_cost += 2 # Costs more time to travel
		3:
			print("Event: Money from family!")
			Global.money += 500
		4:
			print("Event: Super Hot Day!")
			Global.travel_energy_cost += 10 # Traveling drains energy

func check_mid_round_events():
	# 10% chance for a random event when time passes
	if randi() % 100 < 10: 
		var event_roll = randi() % 4
		match event_roll:
			0:
				print("Mid-Event: Got injured!")
				Global.is_injured = true
				Global.travel_time_cost += 1
			1:
				print("Mid-Event: Found lost item!")
				Global.lost_item_active = true
			2:
				print("Mid-Event: Got robbed!")
				Global.money -= 300
			3:
				print("Mid-Event: Got diarrhea!")
				Global.travel_time_cost += 2

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

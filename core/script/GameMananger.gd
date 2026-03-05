extends Node2D

func _ready():
	start_new_round()

func spend_time(amount: int):
	Global.time_remaining -= amount
	check_mid_round_events()
	
	if Global.time_remaining <= 0:
		end_round()

func start_new_round():
	Global.time_remaining = Global.max_time
	Global.travel_time_cost = 2 # Reset travel cost
	Global.travel_energy_cost = 0 # Reset energy cost
	
	# Round 3 Bonus
	if Global.current_round == 3:
		Global.money += 2000
		print("Round 3! Received 2000 money from family.")
		
	trigger_start_round_event()
	print("Round ", Global.current_round, " started!")

func end_round():
	print("Time's up! Returning to Dorm.")
	# Here you would call your MapManager to teleport player to Dorm
	
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
		
	var final_score = (0.5 * Global.study_score) + (0.1 * Global.happy) + (0.2 * Global.energy) + (0.2 * Global.hunger)
	print("Final Score: ", final_score)

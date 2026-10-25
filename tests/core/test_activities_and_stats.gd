extends "res://tests/support/game_test.gd"

func test_A01_global_stats_respect_limits() -> void:
	for stat in ["happy", "energy", "hunger"]:
		Global.update_stat(stat, 9999)
		assert_eq(Global.get(stat), 200)
		Global.update_stat(stat, -9999)
		assert_eq(Global.get(stat), 0)
	Global.update_stat("study_score", 9999)
	assert_eq(Global.study_score, 400)
	Global.update_stat("study_score", -9999)
	assert_eq(Global.study_score, 0)

func test_A02_food_charges_money_and_restores_hunger() -> void:
	var game = make_map()
	var player: Dictionary = Global.player_data[0]
	player["money"] = 100
	player["stats"]["hunger"] = 50
	assert_true(game._can_afford_activity("กินข้าวจานธรรมดา", "Food"))
	assert_false(game.apply_activity_effects("กินข้าวจานธรรมดา", "Food"))
	assert_eq(player["money"], 60)
	assert_eq(player["stats"]["hunger"], 80)

func test_A03_affordability_checks_exact_price_and_insufficient_funds() -> void:
	var game = make_map()
	Global.player_data[0]["money"] = 39
	assert_false(game._can_afford_activity("ซื้อกาแฟ", "Shop"))
	Global.player_data[0]["money"] = 40
	assert_true(game._can_afford_activity("ซื้อกาแฟ", "Shop"))

func test_A04_parttime_rewards_money_and_costs_energy() -> void:
	var game = make_map()
	var player: Dictionary = Global.player_data[0]
	var starting_money: int = player["money"]
	player["stats"]["stamina"] = 100
	game.apply_activity_effects("ทำ Parttime", "Food")
	assert_eq(player["money"], starting_money + 500)
	assert_eq(player["stats"]["stamina"], 80)
	assert_eq(game._get_activity_time_cost("ทำ Parttime", "Food"), 240)

func test_A05_rest_clamps_energy_to_two_hundred() -> void:
	var game = make_map()
	Global.player_data[0]["stats"]["stamina"] = 190
	game.apply_activity_effects("นอนพัก", "Dorm")
	assert_eq(Global.player_data[0]["stats"]["stamina"], 200)

func test_A06_learning_applies_rewards_and_costs_to_active_player_only() -> void:
	var game = make_map()
	var other := canonical(Global.player_data[1])
	assert_false(game._apply_learning_effects(30))
	var stats: Dictionary = Global.player_data[0]["stats"]
	assert_eq(stats["study"], 30)
	assert_eq(stats["stamina"], 55)
	assert_eq(stats["hunger"], 40)
	assert_eq(stats["happiness"], 40)
	assert_eq(canonical(Global.player_data[1]), other)

func test_A07_learning_caps_study_and_detects_fainting() -> void:
	var game = make_map()
	var stats: Dictionary = Global.player_data[0]["stats"]
	stats["study"] = 395
	stats["stamina"] = 5
	assert_true(game._apply_learning_effects(30), "Low energy triggers fainting")
	assert_eq(stats["study"], 400)
	assert_eq(stats["stamina"], 20)

func test_A08_exercise_detects_empty_hunger_and_restores_minimum() -> void:
	var game = make_map()
	Global.player_data[0]["stats"]["hunger"] = 5
	assert_true(game.apply_activity_effects("วิ่ง", "Sport"))
	assert_eq(Global.player_data[0]["stats"]["hunger"], 20)

func test_A09_hospital_and_recreation_respect_stat_limits() -> void:
	var game = make_map()
	var stats: Dictionary = Global.player_data[0]["stats"]
	stats["stamina"] = 180
	stats["happiness"] = 195
	game.apply_activity_effects("เข้ารับการรักษา", "Hospital")
	assert_eq(stats["stamina"], 200)
	assert_eq(stats["happiness"], 200)
	stats["study"] = 0
	game.apply_activity_effects("ปาร์ตี้", "Fun")
	assert_eq(stats["study"], 0)

func test_A10_subject_levels_are_independent_and_capped_at_six() -> void:
	var game = make_map()
	for iteration in range(8):
		game._advance_subject_level(0, "การเขียนโปรแกรมเบื้องต้น")
	assert_eq(game._get_subject_level(0, "การเขียนโปรแกรมเบื้องต้น"), 6)
	assert_eq(game._get_subject_level(1, "การเขียนโปรแกรมเบื้องต้น"), 1)
	assert_eq(game._get_subject_level(0, "ภาษาไทย"), 1)

func test_A11_all_listed_activities_have_time_costs() -> void:
	var game = make_map()
	for place in game.activity_effects:
		for action in game.activity_effects[place]:
			assert_true(game.activity_time_costs.get(place, {}).has(action), "%s / %s needs an explicit time cost" % [place, action])

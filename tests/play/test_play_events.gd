extends "res://tests/support/player_flow_test.gd"

func start_cards() -> void:
	await end_turn(false)
	await frames()
	await until(func(): return not game.random_event_popup.busy, "cards ready")

func test_PLAY_EVENT_01_cards_per_turn() -> void:
	open_game()
	assert_false(game.random_event_popup.visible)
	await start_cards()
	var popup = game.random_event_popup
	assert_between(popup.selected_events.size(), 1, 3)
	var ids: Array = []
	for event in popup.selected_events:
		assert_false(ids.has(event["id"]))
		ids.append(event["id"])
	await resolve_cards()
	assert_true(game.random_event_turns.has("2:0"))
	assert_eq(Global.player_data[0]["event_history"].size(), ids.size())

func test_PLAY_EVENT_02_reveal_before_accepting() -> void:
	open_game()
	await start_cards()
	var popup = game.random_event_popup
	press(popup.close_button)
	assert_true(popup.visible)
	assert_true(Global.player_data[0]["event_history"].is_empty())
	await resolve_cards()
	assert_false(popup.visible)
	assert_gt(Global.player_data[0]["event_history"].size(), 0)

func test_PLAY_EVENT_03_card_details_and_repeat() -> void:
	open_game()
	await start_cards()
	var popup = game.random_event_popup
	card_input(0)
	card_input(0)
	await until(func(): return not popup.busy, "card flip")
	card_input(0)
	assert_true(popup.opened[0])
	popup._show_detail(0) # The card's detail-click handler, not a physical mouse click.
	assert_eq(popup.detail_title.text, str(popup.selected_events[0]["title"]))
	press(popup.detail_confirm)
	assert_true(Global.player_data[0]["event_history"].is_empty())
	await resolve_cards()
	assert_eq(Global.player_data[0]["event_history"].size(), popup.selected_events.size())

func test_PLAY_EVENT_04_effects_and_target_player() -> void:
	open_game(2)
	await end_turn()
	await start_cards()
	var other := snapshot(1)
	var before: Dictionary = Global.player_data[0]["stats"].duplicate()
	var expected := before.duplicate()
	var low: int = Global.player_data[0]["money"]
	var high := low
	var speed := 1.0
	var events: Array = game.random_event_popup.selected_events.duplicate(true)
	for event in events:
		var effect: Dictionary = event.get("effects", {})
		for key in effect.get("stats", {}):
			expected[key] = clampi(int(expected[key]) + int(effect["stats"][key]), 0, 400 if key == "study" else 200)
		if effect.has("money_range"):
			low = maxi(0, low + int(effect["money_range"][0]))
			high = maxi(0, high + int(effect["money_range"][1]))
		speed += float(effect.get("time_speed_bonus", 0.0))
	await resolve_cards()
	assert_eq(Global.player_data[0]["stats"], expected)
	assert_between(int(Global.player_data[0]["money"]), low, high)
	assert_almost_eq(game.player_time_speed_multipliers[0], speed, 0.001)
	assert_eq(snapshot(1), other)

func test_PLAY_EVENT_05_all_reachable_scenario_choices() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios.json"))
	var checked := 0
	for place in db:
		for scenario in db[place]:
			for choice in range(scenario["choices"].size()):
				SaveManager.start_new_game()
				Global.setup_players(1)
				Global.tutorial_seen = true
				open_game()
				var before: Dictionary = Global.player_data[0].duplicate(true)
				var selected_seed := scenario_seed(game.scenario_popup.scenarios_db[place], scenario)
				seed(selected_seed)
				await visit(place, true, choice)
				assert_eq(observed_scenarios.back()["image"], scenario["image"])
				var effect: Dictionary = scenario["choices"][choice].get("effects", {})
				for key in ["money", "study", "happiness", "hunger", "stamina"]:
					var start: int = before["money"] if key == "money" else before["stats"][key]
					var actual: int = Global.player_data[0]["money"] if key == "money" else Global.player_data[0]["stats"][key]
					var wanted := maxi(0, start + int(effect.get(key, 0)))
					if key != "money": wanted = mini(wanted, 400 if key == "study" else 200)
					assert_eq(actual, wanted, "%s choice %d %s" % [place, choice, key])
				var activity = game.get_node("UILayer/ActivityPopup")
				if activity.visible: press(activity.close_btn)
				if game.class_time_popup.visible:
					press(game.class_time_popup.secondary_button if game.class_time_popup.secondary_button.visible else game.class_time_popup.primary_button)
				game.queue_free()
				await frames()
				checked += 1
	assert_eq(checked, 43)

func test_PLAY_EVENT_06_repeated_interaction_does_not_retry_scenario() -> void:
	open_game()
	var scenario: Dictionary = game.scenario_popup.scenarios_db["Shop"][0]
	seed(scenario_seed(game.scenario_popup.scenarios_db["Shop"], scenario))
	await visit("Shop", true)
	assert_eq(observed_scenarios.size(), 1)
	press(game.get_node("UILayer/ActivityPopup").close_btn)
	await frames()
	var attempted: int = game.scenario_attempt_turns.size()
	await visit("Shop", true)
	assert_eq(game.scenario_attempt_turns.size(), attempted)
	assert_eq(observed_scenarios.size(), 1)
	press(game.get_node("UILayer/ActivityPopup").close_btn)

func test_PLAY_EVENT_07_mission_wrong_then_correct_action() -> void:
	open_game()
	seed(event_seed("sick"))
	await end_turn()
	var mission: Dictionary = {}
	for entry in Global.player_data[0]["event_missions"]:
		if entry["id"] == "sick_treatment": mission = entry
	assert_false(mission.is_empty(), "Actual sick card was selected by a reproducible seed")
	if mission.is_empty(): return
	await choose_action("Shop", "ซื้อยา")
	assert_false(mission["is_completed"])
	await choose_action("Hospital", "เข้ารับการรักษา")
	assert_true(mission["is_completed"])
	assert_eq(mission["completed_round"], 2)

func test_PLAY_EVENT_08_mission_score_and_expiration() -> void:
	open_game()
	await attend()
	seed(event_seed("sick"))
	await end_turn()
	assert_eq(Global.player_data[0]["mission_scores"]["1"], 50)
	assert_gt(Global.player_data[0]["event_missions"].size(), 0)
	await end_turn()
	assert_eq(Global.player_data[0]["mission_scores"]["2"], 0)
	for mission in Global.player_data[0]["event_missions"]:
		assert_gte(int(mission["created_round"]), 3)

func test_PLAY_EVENT_09_speed_bonus_and_next_day_reset() -> void:
	open_game()
	seed(event_seed("overslept"))
	await end_turn()
	assert_gt(game.player_time_speed_multipliers[0], 1.0)
	var start: int = game.current_minutes
	tick(10)
	assert_gt(game.current_minutes - start, 10)
	await end_turn(false)
	assert_eq(game.player_time_speed_multipliers[0], 1.0, "Reset before the next day's new cards are accepted")

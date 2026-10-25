extends "res://tests/support/game_test.gd"

func test_T01_class_timing_boundaries() -> void:
	var game = make_map()
	for sample in [[449, "too_early"], [450, "wait"], [479, "wait"], [480, "on_time"], [510, "on_time"], [511, "late"], [540, "late"], [541, "missed"]]:
		assert_eq(game._get_class_timing_state(480, sample[0]), sample[1], "08:00 class, arrival minute %d" % sample[0])

func test_T02_advance_time_updates_only_active_player() -> void:
	var game = make_map()
	game.current_minutes = 480
	game.player_minutes[0] = 480
	game._advance_time(30)
	assert_eq(game.current_minutes, 510)
	assert_eq(game.player_minutes[0], 510)
	assert_eq(game.player_minutes[1], 360)

func test_T03_time_speed_resets_for_all_players_each_day() -> void:
	var game = make_map()
	game.player_time_speed_multipliers.assign([1.3, 1.7])
	assert_almost_eq(game._get_current_time_speed(), 1.3, 0.001)
	game._reset_daily_time_speeds()
	assert_eq(game.player_time_speed_multipliers, [1.0, 1.0])

func test_T04_missed_class_refresh_preserves_attended_classes() -> void:
	var game = make_map()
	game.current_minutes = 541
	var classes := [{"start_minutes": 480, "is_completed": false}, {"start_minutes": 480, "is_completed": true, "attendance_status": "attended"}]
	game._refresh_missed_classes(classes)
	assert_eq(classes[0]["attendance_status"], "missed")
	assert_eq(classes[1]["attendance_status"], "attended")

func test_T05_end_turn_marks_remaining_classes_missed() -> void:
	var game = make_map()
	var classes: Array = Global.player_data[0]["timetable"]["daily_subjects"]["R1"]
	classes[0]["is_completed"] = true
	classes[0]["attendance_status"] = "attended"
	game._mark_remaining_classes_missed(0, 1)
	assert_eq(classes[0]["attendance_status"], "attended")
	assert_eq(classes[1]["attendance_status"], "missed")

func test_T06_week_two_reuses_day_but_resets_attendance() -> void:
	var game = make_map()
	var classes: Array = Global.player_data[0]["timetable"]["daily_subjects"]["R1"]
	var subject: String = classes[0]["subject"]
	classes[0]["is_completed"] = true
	classes[0]["attendance_status"] = "attended"
	classes[0]["late_minutes"] = 15
	game._reset_daily_missions(6)
	assert_eq(classes[0]["subject"], subject)
	assert_false(classes[0]["is_completed"])
	assert_eq(classes[0]["attendance_status"], "pending")
	assert_false(classes[0].has("late_minutes"))

func test_M01_completed_half_of_classes_gives_fifty_mission_points() -> void:
	var game = make_map()
	Global.player_data[0]["timetable"]["daily_subjects"]["R1"][0]["is_completed"] = true
	game._finalize_round_mission_score(0, 1)
	assert_eq(Global.player_data[0]["mission_scores"]["1"], 50)
	assert_eq(Global.player_data[0]["mission_score_details"]["1"]["completed"], 1)

func test_M02_mission_completion_requires_correct_place_and_action() -> void:
	var game = make_map()
	var mission := {"id": "treatment", "places": ["Hospital"], "actions": ["เข้ารับการรักษา"]}
	game._add_event_mission(Global.player_data[0], mission)
	game._complete_event_missions("Shop", "ซื้อยา")
	assert_false(Global.player_data[0]["event_missions"][0]["is_completed"])
	game._complete_event_missions("Hospital", "เข้ารับการรักษา")
	assert_true(Global.player_data[0]["event_missions"][0]["is_completed"])
	assert_eq(Global.player_data[0]["event_missions"][0]["completed_round"], 1)

func test_M03_duplicate_pending_event_missions_are_not_added() -> void:
	var game = make_map()
	var mission := {"id": "sample", "text": "Sample"}
	game._add_event_mission(Global.player_data[0], mission)
	game._add_event_mission(Global.player_data[0], mission)
	assert_eq(Global.player_data[0]["event_missions"].size(), 1)
	assert_false(mission.has("created_round"), "Source event data stays unchanged")

func test_M04_event_missions_count_in_score_and_expire_at_end_of_round() -> void:
	var game = make_map()
	var player: Dictionary = Global.player_data[0]
	for entry in player["timetable"]["daily_subjects"]["R1"]:
		entry["is_completed"] = true
	game._add_event_mission(player, {"id": "sample"})
	game._complete_event_missions("Dorm", "นอนพัก")
	game._finalize_round_mission_score(0, 1)
	assert_eq(player["mission_scores"]["1"], 100)
	assert_eq(player["mission_score_details"]["1"]["total"], 3)
	assert_true(player["event_missions"].is_empty())
	game._finalize_round_mission_score(0, 11)
	assert_false(player["mission_scores"].has("11"), "Exam day has no daily mission score")

func test_E01_event_changes_only_target_player_and_records_history() -> void:
	var game = make_map()
	var other := canonical(Global.player_data[0])
	game._apply_random_event_effects([{"id": "test", "effects": {"stats": {"study": 10}, "money_range": [50, 50], "time_speed_bonus": 0.2}}], 1)
	assert_eq(Global.player_data[1]["stats"]["study"], 10)
	assert_eq(Global.player_data[1]["money"], 1050)
	assert_almost_eq(game.player_time_speed_multipliers[1], 1.2, 0.001)
	assert_eq(Global.player_data[1]["event_history"].size(), 1)
	assert_eq(canonical(Global.player_data[0]), other)

func test_E02_event_effects_clamp_stats_and_money() -> void:
	var game = make_map()
	game._apply_random_event_effects([{"id": "test", "effects": {"stats": {"study": 999, "hunger": -999}, "money_range": [-9999, -9999]}}], 0)
	assert_eq(Global.player_data[0]["stats"]["study"], 400)
	assert_eq(Global.player_data[0]["stats"]["hunger"], 0)
	assert_eq(Global.player_data[0]["money"], 0)

func test_E03_scenario_effects_apply_to_active_player() -> void:
	var game = make_map()
	game._apply_scenario_effects({"money": -50, "happiness": 20})
	assert_eq(Global.player_data[0]["money"], 950)
	assert_eq(Global.player_data[0]["stats"]["happiness"], 70)
	assert_eq(Global.player_data[1]["money"], 1000)

func test_E04_scenario_chance_increases_and_caps() -> void:
	var game = make_map()
	game.scenario_failed_attempts = 0
	assert_almost_eq(game._get_scenario_trigger_chance(), 0.3, 0.001)
	game.scenario_failed_attempts = 2
	assert_almost_eq(game._get_scenario_trigger_chance(), 0.5, 0.001)
	game.scenario_failed_attempts = 50
	assert_almost_eq(game._get_scenario_trigger_chance(), 0.7, 0.001)

func test_E05_event_and_scenario_database_integrity() -> void:
	var game = make_map()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/random_events.json"))
	var ids: Array = []
	for event in data["events"]:
		assert_false(ids.has(event["id"]), "Event IDs are unique")
		ids.append(event["id"])
		assert_true(ResourceLoader.exists(event["image"]), "Event image exists")
		var mission: Dictionary = event.get("effects", {}).get("mission", {})
		for place in mission.get("places", []):
			assert_has(game.activity_effects, place, "Mission location exists")
	var scenarios: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios.json"))
	for place in scenarios:
		assert_gt(scenarios[place].size(), 0, "Location has scenarios")
		for scenario in scenarios[place]:
			assert_gt(scenario.get("choices", []).size(), 0, "Scenario has choices")

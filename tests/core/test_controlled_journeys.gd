extends "res://tests/support/live_game_test.gd"

func complete_controlled_game(correct_targets: Array) -> void:
	Global.setup_players(correct_targets.size())
	for index in range(correct_targets.size()):
		Global.player_data[index]["faculty_id"] = Global.FACULTIES[index + 1]["id"]
	var game = open_game()
	game.learning_popup.set_process(false)
	# Fixed scenario: everyone ends each study day without attending classes.
	# Card interactions are tested separately; pre-mark only their draw keys.
	for day in range(2, 11):
		for player in range(correct_targets.size()):
			game.random_event_turns["%d:%d" % [day, player]] = true
	for day in range(1, 11):
		for player in range(correct_targets.size()):
			assert_eq(game.current_round, day, "No player or day skipped")
			assert_eq(game.current_player_index, player, "Ordered turn rotation")
			game.pass_turn()
	assert_eq(game.current_round, 11)
	for player in range(correct_targets.size()):
		await wait_process_frames(2)
		assert_eq(game.current_player_index, player, "Every player gets their own final exam")
		game.class_time_popup.primary_button.pressed.emit()
		var answered := 0
		for subject in range(4):
			for question in range(5):
				answer_current_question(game.learning_popup, answered < int(correct_targets[player]))
				answered += 1
			game.learning_popup.ok_button.pressed.emit()
		var result: Dictionary = Global.player_data[player]["exam_result"]
		assert_eq(result["correct"], correct_targets[player])
		assert_eq(result["total"], 20)
		assert_eq(result["score"], int(correct_targets[player]) * 50, "Each correct answer is 50/1000")
		assert_eq(Global.player_data[player]["mission_scores"].size(), 10)
		for score in Global.player_data[player]["mission_scores"].values():
			assert_eq(score, 0, "Skipping all study days earns no mission points")
		game.class_time_popup.primary_button.pressed.emit()
	await wait_process_frames(2)
	assert_true(game.endgame_ui.visible)
	assert_true(get_tree().paused)
	var scores: Array = game.endgame_ui._get_player_results()
	assert_eq(scores.size(), correct_targets.size())
	for index in range(scores.size()):
		assert_eq(scores[index]["exam"], int(correct_targets[index]) * 50)

func test_J01_two_players_complete_ten_days_and_opposite_exam_results() -> void:
	await complete_controlled_game([20, 0])

func test_J02_three_players_keep_full_half_zero_exam_scores_separate() -> void:
	await complete_controlled_game([20, 10, 0])

func test_J03_four_players_complete_game_with_four_distinct_scores() -> void:
	await complete_controlled_game([20, 15, 10, 0])

func test_J04_new_process_loads_actual_saved_map_and_player_data() -> void:
	Global.player_data[0]["faculty_id"] = "law"
	var game = open_game()
	game.current_round = 5
	game.current_player_index = 1
	game.player_minutes.assign([700, 930])
	game.player_time_speed_multipliers.assign([1.2, 1.4])
	game.random_event_turns["5:1"] = true
	game.occurred_scenarios = {"Library:probe": true}
	Global.player_data[0]["money"] = 4321
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	assert_true(SaveManager.save_checkpoint(3), "Write real slot before launching a separate process")
	var expected := canonical(Global.player_data)
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/support/load_probe.gd"]), output, true)
	assert_eq(exit_code, 0, "Fresh process must load the save successfully: " + "\n".join(output))
	assert_true(FileAccess.file_exists("user://load_probe.json"))
	if exit_code != 0 or not FileAccess.file_exists("user://load_probe.json"):
		return
	var loaded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://load_probe.json"))
	assert_eq(canonical(loaded["players"]), expected, "Actual map startup restores faculty, stats and progress")
	assert_eq(int(loaded["round"]), 5)
	assert_eq(int(loaded["player"]), 1)
	assert_eq(int(loaded["minutes"]), 930)
	assert_true(loaded["scenarios"].has("Library:probe"))
	assert_almost_eq(float(loaded["speeds"][1]), 1.4, 0.001)

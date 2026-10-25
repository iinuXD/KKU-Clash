extends "res://tests/support/game_test.gd"

const MAP_SCENE = preload("res://locations/NewMap.tscn")

func open_map():
	Global.tutorial_seen = true
	var game = add_child_autofree(MAP_SCENE.instantiate())
	game.set_process(false)
	for player in game.player_nodes:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	return game

func test_I01_map_starts_two_players_and_only_active_player_can_move() -> void:
	var game = open_map()
	assert_eq(game.player_nodes.size(), 2)
	assert_true(game.player_nodes[0].movement_enabled)
	assert_false(game.player_nodes[1].movement_enabled)
	assert_eq(game.current_minutes, 360)
	assert_true(SaveManager.has_checkpoint())

func test_I02_turn_rotates_and_day_advances_after_all_players() -> void:
	var game = open_map()
	game.pass_turn()
	assert_eq(game.current_player_index, 1)
	assert_eq(game.current_round, 1)
	assert_false(game.player_nodes[0].movement_enabled)
	assert_true(game.player_nodes[1].movement_enabled)
	# Mark next day's events already drawn to keep this test focused on turns.
	game.random_event_turns["2:0"] = true
	game.pass_turn()
	assert_eq(game.current_player_index, 0)
	assert_eq(game.current_round, 2)
	assert_eq(game.player_minutes, [360, 360])
	assert_eq(SaveManager.checkpoint["map"]["current_round"], 2)

func test_I03_pause_stops_clock_and_resume_restores_game() -> void:
	var game = open_map()
	game._pause_game()
	assert_true(get_tree().paused)

	game._process(5.0)
	assert_eq(game.current_minutes, 360)
	game._resume_game()
	assert_false(get_tree().paused)
	assert_false(game.pause_menu.visible)

func test_I04_real_clock_stops_while_timetable_is_open() -> void:
	var game = open_map()
	game.timetable_popup.open_for_player(0)
	game._process(3.0)
	assert_eq(game.current_minutes, 360)
	game.timetable_popup.hide()
	game._process(0.3)
	assert_eq(game.current_minutes, 362, "0.3 seconds advances two game minutes")

func test_I05_keyboard_movement_and_diagonal_speed() -> void:
	var game = open_map()
	var player = game.player_nodes[0]
	Input.action_press("move_right")
	player._physics_process(0.016)
	assert_gt(player.velocity.x, 0.0)
	assert_almost_eq(player.velocity.length(), player.speed, 0.01)
	Input.action_press("move_up")
	player._physics_process(0.016)
	assert_almost_eq(player.velocity.length(), player.speed, 0.01, "Diagonal movement is normalized")
	player.set_movement_enabled(false)
	assert_eq(player.velocity, Vector2.ZERO)

func test_I06_interaction_emits_only_when_enabled_and_near_a_place() -> void:
	var game = open_map()
	var player = game.player_nodes[0]
	# Observe controller output without opening the live activity popup.
	player.activity_requested.disconnect(game._on_player_activity_requested)
	var place: Node2D = add_child_autofree(Node2D.new())
	player.nearby_place = place
	watch_signals(player)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)
	assert_signal_emitted_with_parameters(player, "activity_requested", [place])
	player.set_movement_enabled(false)
	player._unhandled_input(event)
	assert_signal_emit_count(player, "activity_requested", 1)

func test_I07_three_am_forces_sleep_and_next_wake_is_ten_am() -> void:
	var game = open_map()
	game.current_minutes = 1619
	game._advance_time(1)
	assert_true(game.is_forcing_sleep)
	await wait_seconds(0.5)
	assert_eq(game.current_player_index, 1)
	assert_true(game.late_wake_players[0])
	game.random_event_turns["2:0"] = true
	game.pass_turn()
	assert_eq(game.player_minutes[0], 600)
	assert_false(game.late_wake_players[0])

func test_I08_forced_sleep_should_not_reduce_existing_energy() -> void:
	var game = open_map()
	Global.player_data[0]["stats"]["stamina"] = 150
	game.current_minutes = 1619
	game._advance_time(1)
	var actual: int = Global.player_data[0]["stats"]["stamina"]
	await wait_seconds(0.5)
	assert_eq(actual, 180, "BUG REPRO: 150 energy + 30 sleep recovery, cap 200, should be 180; actual=%d. Run run-tests.cmd -Demo forced-sleep" % actual)

func test_I09_loaded_map_state_restores_turn_clock_and_event_history() -> void:
	var game = open_map()
	game._apply_map_save_data({"current_round": 5, "current_player_index": 1, "player_minutes": [480, 900], "player_time_speed_multipliers": [1.1, 1.4], "late_wake_players": [true, false], "occurred_scenarios": {"sample": true}, "random_event_turns": {"5:1": true}})
	game.setup_current_turn()
	assert_eq(game.current_round, 5)
	assert_eq(game.current_player_index, 1)
	assert_eq(game.current_minutes, 900)
	assert_true(game.player_nodes[1].movement_enabled)
	assert_true(game.occurred_scenarios.has("sample"))
	assert_almost_eq(game._get_current_time_speed(), 1.4, 0.001)

func test_I10_scheduled_class_updates_attendance_progress_stats_and_time() -> void:
	var game = open_map()
	game.current_minutes = 480
	game.player_minutes[0] = 480
	game.learning_popup.set_process(false)
	var entry := {"subject": "ภาษาไทย", "start_minutes": 480, "end_minutes": 600, "is_completed": false}
	game._start_scheduled_class(entry, 1.0, "")
	for question in range(3):
		for index in range(4):
			if game.learning_popup.choice_buttons[index].text == game.learning_popup.current_correct_answer:
				game.learning_popup.choice_buttons[index].pressed.emit()
				break
	game.learning_popup.ok_button.pressed.emit()
	assert_true(entry["is_completed"])
	assert_eq(entry["attendance_status"], "attended")
	assert_eq(game._get_subject_level(0, "ภาษาไทย"), 2)
	assert_eq(Global.player_data[0]["stats"]["study"], 30)
	assert_eq(game.current_minutes, 600)

func test_I11_final_exam_runs_four_subjects_and_shows_endgame() -> void:
	Global.setup_players(1)
	Global.player_data[0]["faculty_id"] = "computing"
	Global.ensure_random_timetables()
	var game = open_map()
	game.current_round = 11
	game.learning_popup.set_process(false)
	game._start_final_exam_turn()
	game.class_time_popup.choice_made.emit("start_exam")
	for subject in range(4):
		assert_true(game.learning_popup.is_exam_mode)
		for question in range(5):
			for index in range(4):
				if game.learning_popup.choice_buttons[index].text == game.learning_popup.current_correct_answer:
					game.learning_popup.choice_buttons[index].pressed.emit()
					break
		game.learning_popup.ok_button.pressed.emit()
	var result: Dictionary = Global.player_data[0].get("exam_result", {})
	assert_true(result.get("completed", false))
	assert_eq(result.get("correct"), 20)
	assert_eq(result.get("total"), 20)
	assert_eq(result.get("score"), 1000)
	game.class_time_popup.choice_made.emit("finish_exam")
	assert_true(game.endgame_ui.visible)
	assert_true(get_tree().paused)


func test_R01_activity_popup_texture_uid_matches_its_file() -> void:
	var source := FileAccess.get_file_as_string("res://ui/activity_popup.tscn")
	var pattern := RegEx.new()
	pattern.compile('uid="(uid://[^" ]+)" path="res://asset/activities/pxdorm.png"')
	var found := pattern.search(source)
	assert_not_null(found, "Dorm texture reference exists")
	if found:
		var declared_uid := found.get_string(1)
		var actual_uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid("res://asset/activities/pxdorm.png"))
		assert_eq(declared_uid, actual_uid, "Scene texture UID should match the imported image; mismatches cause fallback warnings")

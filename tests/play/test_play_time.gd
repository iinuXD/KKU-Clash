extends "res://tests/support/player_flow_test.gd"

func test_PLAY_TIME_01_normal_clock() -> void:
	open_game()
	assert_eq(game.current_minutes, 360)
	tick(2)
	assert_eq(game.current_minutes, 362)

func test_PLAY_TIME_02_separate_player_clocks() -> void:
	open_game(2)
	await choose_action("Library", "ยืมหนังสือ")
	assert_eq(game.player_minutes[0], 370)
	await end_turn()
	assert_eq(game.current_player_index, 1)
	assert_eq(game.current_minutes, 360)
	tick(20)
	assert_eq(game.player_minutes[1], 380)
	assert_eq(game.player_minutes[0], 370)

func test_PLAY_TIME_03_day_after_all_players() -> void:
	for count in [2, 3, 4]:
		SaveManager.start_new_game()
		Global.setup_players(count)
		Global.tutorial_seen = true
		open_game(count)
		for player in range(count):
			assert_eq(game.current_round, 1)
			assert_eq(game.current_player_index, player)
			await end_turn()
		assert_eq(game.current_round, 2)
		assert_eq(game.current_player_index, 0)
		game.queue_free()
		await frames()

func test_PLAY_TIME_04_pause_and_resume() -> void:
	open_game()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game._unhandled_input(escape)
	assert_true(get_tree().paused)
	tick(20)
	assert_eq(game.current_minutes, 360)
	press(game.pause_menu.resume_button)
	assert_false(get_tree().paused)
	tick(1)
	assert_eq(game.current_minutes, 361)

func test_PLAY_TIME_05_clock_while_popups() -> void:
	open_game()
	press(game.timetable_button)
	tick(10)
	assert_eq(game.current_minutes, 360)
	press(game.timetable_popup.primary_button)
	await visit("Food")
	tick(10)
	assert_eq(game.current_minutes, 360)
	press(game.get_node("UILayer/ActivityPopup").close_btn)
	await frames()
	reach_class(-15)
	await visit("Learn")
	var start: int = game.current_minutes
	tick(10)
	assert_eq(game.current_minutes, start)
	press(game.class_time_popup.secondary_button)

func test_PLAY_TIME_06_midnight() -> void:
	open_game()
	tick(1439 - game.current_minutes)
	assert_eq(game.current_minutes, 1439)
	tick(1)
	assert_eq(game.current_minutes, 1440)
	assert_eq(game.current_round, 1)
	assert_true(game.player_panel.time_label.text.contains("00:00"))

func test_PLAY_TIME_07_voluntary_sleep() -> void:
	open_game()
	tick(1500 - game.current_minutes)
	await choose_action("Dorm", "นอนพัก")
	assert_eq(game.current_round, 2)
	assert_eq(game.current_minutes, 360)
	assert_false(game.late_wake_players[0])

func test_PLAY_TIME_08_forced_sleep() -> void:
	open_game()
	await choose_action("Dorm", "นอนพัก")
	await choose_action("Dorm", "นอนพัก")
	assert_eq(Global.player_data[0]["stats"]["stamina"], 150)
	tick(1620 - game.current_minutes)
	await until(func(): return not game.is_forcing_sleep, "forced sleep")
	assert_eq(game.current_round, 2)
	assert_eq(game.current_minutes, 600)
	assert_eq(Global.player_data[0]["stats"]["stamina"], 180)

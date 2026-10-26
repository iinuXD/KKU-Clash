extends GutTest

const MAP = preload("res://locations/NewMap.tscn")
var game
var observed_scenarios: Array = []

func before_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 12.0
	# Audible output is checked manually; stop the looping MP3 in headless
	# sessions so its decoder does not survive process teardown.
	AudioManager.music_player.stop()
	AudioManager.music_player.stream = null
	seed(20261026)
	SaveManager.start_new_game()
	Global.setup_players(1)
	Global.tutorial_seen = true
	LeaderboardManager._load_entries()
	observed_scenarios.clear()

func after_each() -> void:
	get_tree().paused = false
	# Finish visible card animations before GUT frees the scene. Otherwise a
	# still-awaited tween would resume after its owner was destroyed.
	if is_instance_valid(game) and game.random_event_popup.visible:
		await resolve_cards()
	Engine.time_scale = 1.0
	for action in ["move_up", "move_down", "move_left", "move_right", "interact"]:
		Input.action_release(action)

func open_game(count: int = 1):
	if Global.player_data.size() != count:
		Global.setup_players(count)
	if not Global.player_data[0].has("avatar_settings"):
		var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
		for player in range(count):
			avatar.current_player_index = player + 1
			avatar.load_current_player_data()
			avatar.save_current_player_data()
		avatar.hide()
		avatar.queue_free()
	game = add_child_autofree(MAP.instantiate())
	game.set_process(false)
	game.learning_popup.set_process(false)
	for player in game.player_nodes:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	return game

func press(button: BaseButton) -> void:
	# Signals exercise the real connected handlers. Respect visibility and
	# disabled state so this cannot press a button a player cannot use.
	if button.is_visible_in_tree() and not button.disabled:
		button.pressed.emit()

func frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func until(condition: Callable, label: String, max_ms: int = 5000) -> bool:
	var end := Time.get_ticks_msec() + max_ms
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	var done: bool = condition.call()
	assert_true(done, "Timed out: " + label)
	return done

func tick(minutes: int) -> void:
	# Drive elapsed time, not current_round/current_minutes or player stats.
	var remaining := minutes
	while remaining > 0:
		var step := mini(remaining, 10)
		var player: int = game.current_player_index
		game._process(float(step) * game.REAL_SECONDS_PER_GAME_MINUTE + 0.000001)
		remaining -= step
		if game.is_forcing_sleep or game.current_player_index != player:
			break

func card_input(index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	game.random_event_popup._card_input(event, index)

func resolve_cards() -> void:
	await frames()
	var popup = game.random_event_popup
	if not popup.visible:
		return
	if not await until(func(): return not popup.busy, "card deal"):
		return
	for index in range(popup.selected_events.size()):
		if not popup.opened[index]:
			card_input(index)
			await until(func(): return not popup.busy, "card flip")
	press(popup.close_button)
	await frames()

func visit(place: String, allow_scenario: bool = false, scenario_choice: int = 0) -> void:
	await resolve_cards()
	if not allow_scenario:
		# Isolate this case to the reachable no-scenario branch. This is a
		# random-event control only; no money, stats, clock or rounds are forged.
		game.scenario_attempt_turns["%d:%d" % [game.current_round, game.current_player_index]] = true
	var player = game.player_nodes[game.current_player_index]
	player.nearby_place = game.get_node("location/" + place)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)
	await frames()
	if game.scenario_popup.visible:
		observed_scenarios.append(game.scenario_popup.current_scenario.duplicate(true))
		press(game.scenario_popup.vbox.get_child(scenario_choice))
		await until(func(): return not game.scenario_popup.visible, "scenario choice")
	await frames()

func action_button(action: String) -> TextureButton:
	for card in game.get_node("UILayer/ActivityPopup").btn_container.get_children():
		if card.get_meta("activity_name", "") == action:
			return card.get_child(0).get_child(0) as TextureButton
	return null

func choose_action(place: String, action: String) -> void:
	await visit(place)
	var button := action_button(action)
	assert_not_null(button, place + " / " + action)
	if button == null:
		return
	press(button)
	await until(func(): return not game.get_node("UILayer/ActivityPopup").visible, "activity selection")
	await until(func(): return game.current_round >= 11 or (not game.is_forcing_sleep and not game.is_walking), "activity resolution")

func end_turn(resolve: bool = true) -> void:
	await choose_action("Dorm", "จบเทิร์น")
	if resolve and game.current_round < 11:
		await resolve_cards()

func reach_day(day: int) -> void:
	var turns := 0
	while game.current_round < day and turns < 45:
		await end_turn()
		turns += 1
	assert_gte(game.current_round, day, "Reached day through at most 45 real end-turn actions")

func class_entry() -> Dictionary:
	return Global.player_data[game.current_player_index]["timetable"]["daily_subjects"]["R1"][0]

func reach_class(offset: int = 0) -> Dictionary:
	var entry := class_entry()
	tick(int(entry["start_minutes"]) + offset - game.current_minutes)
	return entry

func answer(correctly: bool) -> void:
	var quiz = game.learning_popup
	for button in quiz.choice_buttons:
		if (button.text == quiz.current_correct_answer) == correctly:
			press(button)
			return

func finish_quiz(correct_count: int = 3) -> void:
	var index := 0
	while game.learning_popup.is_quiz_active:
		answer(index < correct_count)
		index += 1
	press(game.learning_popup.ok_button)
	await frames()

func attend(offset: int = 0, correct: int = 3) -> Dictionary:
	var entry := reach_class(offset)
	await visit("Learn")
	press(game.class_time_popup.primary_button)
	await finish_quiz(correct)
	return entry

func finish_exam(correct: int = 20) -> void:
	await frames()
	press(game.class_time_popup.primary_button)
	for subject in range(4):
		var count := clampi(correct - subject * 5, 0, 5)
		await finish_quiz(count)
	press(game.class_time_popup.primary_button)
	await frames()

func snapshot(player: int = 0) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Global.player_data[player])))

func probe(mode: String) -> Dictionary:
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/support/player_menu_probe.gd", "--", mode]), output, true)
	assert_eq(code, 0, "Menu probe: " + mode + "\n" + "\n".join(output))
	var diagnostics := "\n".join(output)
	var errors: PackedStringArray = []
	for line in diagnostics.split("\n"):
		if line.contains("SCRIPT ERROR:") or line.begins_with("ERROR:"):
			errors.append(line)
	var log_file := FileAccess.open(OS.get_environment("KKU_TEST_RESULTS").path_join("probe_" + mode + ".log"), FileAccess.WRITE)
	if log_file:
		log_file.store_string(diagnostics)
	assert_true(errors.is_empty(), "Fresh-process diagnostics: " + mode + "\n" + "\n".join(errors))
	var path := "user://play_probe_" + mode + ".json"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func event_seed(target_id: String) -> int:
	# Select a reproducible seed, using the same public RNG operations but
	# leaving the real database, event gate and effects application intact.
	for candidate in range(1, 10000):
		seed(candidate)
		var count := randi_range(1, 3)
		var candidates: Array = game.random_event_popup.events_db.duplicate(true)
		candidates.shuffle()
		for event in candidates.slice(0, count):
			if event["id"] == target_id:
				return candidate
	fail_test("No seed found for event " + target_id)
	return 1

func scenario_seed(bank: Array, scenario: Dictionary) -> int:
	for candidate in range(1, 10000):
		seed(candidate)
		if randf() <= 0.30 and bank.pick_random()["image"] == scenario["image"]:
			return candidate
	fail_test("No seed found for scenario")
	return 1

func open_save() -> void:
	if not get_tree().paused:
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		game._unhandled_input(escape)
	press(game.pause_menu.save_button)
	assert_true(game.save_slot_menu.visible)

func save_to(slot: int) -> void:
	await open_save()
	press(game.save_slot_menu.slot_buttons[slot - 1])
	if game.save_slot_menu.confirmation_layer.visible:
		press(game.save_slot_menu.confirmation_confirm_button)
	await until(func(): return not game.save_slot_menu.visible, "save menu close")
	press(game.pause_menu.resume_button)
	assert_false(get_tree().paused)

func complete_game(count: int = 1) -> void:
	open_game(count)
	await reach_day(11)
	for player in range(count):
		await finish_exam(20 - player * 5)
	assert_true(game.endgame_ui.visible)

extends SceneTree

# Separate process preserves GUT's scene during real scene changes and reloads.
var state
var saves
var game

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame

func press(button: BaseButton) -> void:
	if button.is_visible_in_tree() and not button.disabled:
		button.pressed.emit()

func wait_for(condition: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not condition.call():
		printerr("Probe timed out: " + label)
		quit(3)

func prepare_map() -> void:
	game = current_scene
	game.set_process(false)
	game.learning_popup.set_process(false)
	for player in game.player_nodes:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	await settle()
	if game.tutorial_popup.visible:
		press(game.tutorial_popup.skip_button)
	await settle()

func cards() -> void:
	await settle()
	var popup = game.random_event_popup
	if not popup.visible: return
	await wait_for(func(): return not popup.busy, "card deal")
	for index in range(popup.selected_events.size()):
		if not popup.opened[index]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			popup._card_input(event, index)
			await wait_for(func(): return not popup.busy, "card flip")
	press(popup.close_button)
	await settle()

func activity(action: String) -> void:
	await cards()
	game.scenario_attempt_turns["%d:%d" % [game.current_round, game.current_player_index]] = true
	var player = game.player_nodes[game.current_player_index]
	player.nearby_place = game.get_node("location/Dorm")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)
	await settle()
	var popup = game.get_node("UILayer/ActivityPopup")
	for card in popup.btn_container.get_children():
		if card.get_meta("activity_name", "") == action:
			press(card.get_child(0).get_child(0))
			break
	await wait_for(func(): return not popup.visible, "activity")
	await wait_for(func(): return game.current_round >= 11 or not game.is_walking, "activity resolution")
	await cards()

func exam() -> void:
	await settle()
	press(game.class_time_popup.primary_button)
	for subject in range(4):
		var quiz = game.learning_popup
		while quiz.is_quiz_active:
			for button in quiz.choice_buttons:
				if button.text == quiz.current_correct_answer:
					press(button)
					break
		press(quiz.ok_button)
		await settle()
	press(game.class_time_popup.primary_button)
	await settle()

func load_slot(slot: int) -> void:
	current_scene.get_node("VBoxContainer/optionsBtn").button_up.emit()
	press(current_scene.save_slot_menu.slot_buttons[slot - 1])
	await settle()

func midgame_load() -> void:
	game._pause_game()
	press(game.pause_menu.save_button)
	press(game.save_slot_menu.slot_buttons[0])
	if game.save_slot_menu.confirmation_layer.visible:
		press(game.save_slot_menu.confirmation_confirm_button)
	await wait_for(func(): return not game.save_slot_menu.visible, "save")
	press(game.pause_menu.resume_button)
	game._pause_game()
	press(game.pause_menu.quit_button)
	await settle()
	await load_slot(1)
	await prepare_map()

func run() -> void:
	var sandbox := OS.get_environment("KKU_TEST_SANDBOX").replace("\\", "/").to_lower()
	if sandbox.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox + "/"):
		quit(3)
		return
	create_timer(60.0, true, false, true).timeout.connect(func(): printerr("Probe watchdog timeout"); quit(3))
	Engine.time_scale = 20.0
	seed(20261026)
	root.size = Vector2i(1280, 720)
	# Stop map time before its first frame, so load assertions inspect the
	# checkpoint itself rather than the CPU-dependent elapsed startup time.
	root.child_entered_tree.connect(func(node):
		if node.scene_file_path == "res://locations/NewMap.tscn":
			node.ready.connect(func(): node.set_process(false))
	)
	state = root.get_node("Global")
	saves = root.get_node("SaveManager")
	var mode: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://ui/MainMenu.tscn")
	await settle()
	var result: Dictionary = {}
	if mode == "volume":
		press(current_scene.get_node("VBoxContainer/settingsBtn"))
		result["volumes"] = []
		result["labels"] = []
		for value in [0, 42, 100]:
			current_scene.settings_menu.volume_slider.value = value
			result["volumes"].append(root.get_node("AudioManager").get_music_volume())
			result["labels"].append(current_scene.settings_menu.volume_value.text)
		for button in current_scene.settings_menu.find_children("*", "Button", true, false):
			if button.text == "กลับ": press(button)
		await settle()
	elif mode.begins_with("load"):
		await load_slot(int(mode.trim_prefix("load")))
		await prepare_map()
	elif mode == "empty4":
		current_scene.get_node("VBoxContainer/optionsBtn").button_up.emit()
		result["empty_disabled"] = current_scene.save_slot_menu.slot_buttons[3].disabled
		press(current_scene.save_slot_menu.slot_buttons[3])
	else:
		press(current_scene.get_node("VBoxContainer/startgameBtn"))
		await settle()
		if mode == "back":
			press(current_scene.get_node("backbtn"))
			await settle()
		else:
			var count := int(mode.trim_prefix("start").trim_prefix("journey").trim_prefix("restart")) if mode != "restart" and mode != "exit" else 1
			var buttons := ["onePlayer", "twoPlayers", "treePlayers", "fourPlayers"]
			press(current_scene.get_node("VBoxContainer/" + buttons[count - 1]))
			await settle()
			for player in range(count):
				current_scene.get_node("PlayerRow/FacultySelect").select((player + 1) % 5 if mode.begins_with("restart") else player % 5)
				if mode.begins_with("restart"):
					for step in range(player + 1):
						press(current_scene.get_node("HBoxContainer2/VBoxContainer2/nexthair"))
				press(current_scene.get_node("HBoxContainer/okayBtn"))
			await create_timer(2.2).timeout
			await settle()
			if current_scene.scene_file_path == "res://ui/registration_ui.tscn":
				press(current_scene.get_node("%PrimaryButton"))
				await settle()
			await prepare_map()
			if mode.begins_with("journey") or mode.begins_with("restart") or mode == "exit":
				await activity("อ่านหนังสือ")
				await activity("จบเทิร์น")
				await midgame_load()
				result["loaded_midgame"] = current_scene.scene_file_path == "res://locations/NewMap.tscn" and saves.active_slot == 1
				var turns := 0
				while game.current_round < 11 and turns < 45:
					await activity("จบเทิร์น")
					turns += 1
				for player in range(count): await exam()
				result["end_visible"] = game.endgame_ui.visible
				result["exam_scores"] = []
				for player in state.player_data:
					result["exam_scores"].append(player.get("exam_result", {}).get("score", -1))
				if mode.begins_with("restart"):
					result["previous_players"] = state.player_data.duplicate(true)
					var saved_files: Dictionary = {}
					for slot in range(1, 5):
						var path: String = saves._slot_path(slot)
						if FileAccess.file_exists(path): saved_files[path] = FileAccess.get_file_as_string(path)
					var board := FileAccess.get_file_as_string("user://leaderboard.json")
					press(game.endgame_ui.restart_button)
					await settle()
					await prepare_map()
					result["active_slot"] = saves.active_slot
					result["has_pending_load"] = saves.has_pending_load()
					result["saved_files_unchanged"] = true
					for path in saved_files:
						if FileAccess.get_file_as_string(path) != saved_files[path]: result["saved_files_unchanged"] = false
					result["leaderboard_unchanged"] = FileAccess.get_file_as_string("user://leaderboard.json") == board
				elif mode == "exit":
					press(game.endgame_ui.exit_button)
					await settle()
	result.merge({"scene": current_scene.scene_file_path, "count": state.player_count, "players": state.player_data, "paused": paused, "volume": root.get_node("AudioManager").get_music_volume()})
	if current_scene.scene_file_path == "res://locations/NewMap.tscn":
		result.merge({"round": current_scene.current_round, "player": current_scene.current_player_index, "minutes": current_scene.current_minutes})
	var file := FileAccess.open("user://play_probe_" + mode + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	root.get_node("AudioManager").music_player.stop()
	root.get_node("AudioManager").music_player.stream = null
	await create_timer(0.15, true, false, true).timeout
	quit()

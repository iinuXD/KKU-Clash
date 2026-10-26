extends "res://tests/support/player_flow_test.gd"

func test_PLAY_SAVE_01_four_slots() -> void:
	open_game()
	for slot in range(1, 5):
		await save_to(slot)
		var info: Dictionary = SaveManager.get_slot_info(slot)
		assert_true(info["exists"])
		assert_true(info["valid"])
		assert_eq(int(info["round"]), 1)
		assert_eq(SaveManager.active_slot, slot)

func prepare_overwrite() -> void:
	open_game()
	await save_to(1)
	await save_to(2)
	await choose_action("Library", "ยืมหนังสือ")
	await end_turn()

func test_PLAY_SAVE_02_cancel_overwrite() -> void:
	await prepare_overwrite()
	var old := FileAccess.get_file_as_string(SaveManager._slot_path(1))
	await open_save()
	press(game.save_slot_menu.slot_buttons[0])
	assert_true(game.save_slot_menu.confirmation_layer.visible)
	for button in game.save_slot_menu.confirmation_layer.find_children("*", "Button", true, false):
		if button.text == "ยกเลิก": press(button)
	assert_eq(FileAccess.get_file_as_string(SaveManager._slot_path(1)), old)
	assert_eq(SaveManager.active_slot, 2)
	game.save_slot_menu._close_menu()
	press(game.pause_menu.resume_button)

func test_PLAY_SAVE_03_confirm_overwrite() -> void:
	await prepare_overwrite()
	var expected := JSON.stringify(JSON.parse_string(JSON.stringify(SaveManager.checkpoint)))
	await save_to(1)
	var saved: Dictionary = SaveManager._read_slot(1)
	assert_eq(JSON.stringify(saved["game"]), expected)
	assert_eq(SaveManager.active_slot, 1)

func test_PLAY_SAVE_04_autosave_after_turn() -> void:
	open_game()
	assert_eq(SaveManager.active_slot, -1)
	await save_to(3)
	await choose_action("Library", "ยืมหนังสือ")
	await end_turn()
	var saved: Dictionary = SaveManager._read_slot(3)
	assert_eq(int(saved["game"]["map"]["current_round"]), 2)
	assert_eq(int(saved["game"]["global"]["player_data"][0]["money"]), 980)

func test_PLAY_SAVE_05_fresh_process_load_through_menu() -> void:
	open_game(2)
	await choose_action("Library", "ยืมหนังสือ")
	await end_turn()
	for slot in range(1, 5):
		await save_to(slot)
		var expected: Dictionary = SaveManager.checkpoint.duplicate(true)
		var loaded := probe("load%d" % slot)
		assert_eq(loaded.get("scene"), "res://locations/NewMap.tscn")
		assert_eq(int(loaded.get("player", -1)), 1)
		assert_eq(int(loaded.get("minutes", -1)), 360)
		assert_eq(JSON.stringify(loaded["players"]), JSON.stringify(JSON.parse_string(JSON.stringify(expected["global"]["player_data"]))))

func test_PLAY_SAVE_06_checkpoint_not_midturn() -> void:
	open_game()
	await choose_action("Library", "ยืมหนังสือ")
	assert_eq(Global.player_data[0]["money"], 980)
	await save_to(1)
	var loaded := probe("load1")
	assert_eq(int(loaded["players"][0]["money"]), 1000)
	assert_eq(int(loaded["minutes"]), 360)

func test_PLAY_SAVE_07_empty_load_slot() -> void:
	open_game()
	# An empty slot is a reachable fresh-profile fixture, not a corrupt save.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager._slot_path(4)))
	var loaded := probe("empty4")
	assert_eq(loaded["scene"], "res://ui/MainMenu.tscn")
	assert_true(loaded["empty_disabled"])

func test_PLAY_SAVE_08_tutorial_skip_and_reopen() -> void:
	Global.tutorial_seen = false
	open_game()
	await frames()
	var tutorial = game.tutorial_popup
	assert_true(tutorial.visible)
	tick(10)
	assert_eq(game.current_minutes, 360)
	press(tutorial.next_button)
	assert_eq(tutorial.current_page, 1)
	press(tutorial.back_button)
	assert_eq(tutorial.current_page, 0)
	press(tutorial.skip_button)
	assert_true(Global.tutorial_seen)
	game._pause_game()
	press(game.pause_menu.tutorial_button)
	assert_true(tutorial.visible)
	press(tutorial.skip_button)
	assert_true(game.pause_menu.visible)
	assert_true(get_tree().paused)
	press(game.pause_menu.resume_button)

func test_PLAY_SAVE_09_volume_control_and_persistence() -> void:
	# Run the native settings UI in its own process, as for menu transitions.
	var result := probe("volume")
	for index in range(3):
		var volume: int = [0, 42, 100][index]
		assert_almost_eq(float(result["volumes"][index]), volume / 100.0, 0.001)
		assert_true(str(result["labels"][index]).contains(str(volume)))
	assert_almost_eq(float(probe("back")["volume"]), 1.0, 0.001, "Fresh process loads saved volume; audible output needs a human")

extends "res://tests/support/player_flow_test.gd"

func test_PLAY_START_01_new_game_single() -> void:
	var result := probe("start1")
	assert_eq(result.get("scene"), "res://locations/NewMap.tscn")
	assert_eq(int(result.get("count", 0)), 1)

func test_PLAY_START_02_new_game_multiple() -> void:
	for count in [2, 3, 4]:
		var result := probe("start%d" % count)
		assert_eq(result.get("scene"), "res://locations/NewMap.tscn")
		assert_eq(result.get("players", []).size(), count)

func test_PLAY_START_03_avatar_layers_wrap() -> void:
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	for config in [["hairs", "current_hair", "hair"], ["faces", "current_face", "face"], ["skins", "current_skin", "skin"], ["accessories", "current_accessory", "accessory"], ["outfits", "current_outfit", "attire"]]:
		var size: int = avatar.get(config[0]).size()
		assert_gt(size, 0)
		press(avatar.get_node("HBoxContainer2/VBoxContainer/prev" + config[2]))
		assert_eq(int(avatar.get(config[1])), size - 1)
		press(avatar.get_node("HBoxContainer2/VBoxContainer2/next" + config[2]))
		assert_eq(int(avatar.get(config[1])), 0)

func test_PLAY_START_04_four_faculties_have_required_subject() -> void:
	Global.setup_players(2)
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	for faculty in range(1, 5):
		avatar.faculty_select.select(faculty)
		press(avatar.get_node("HBoxContainer/okayBtn"))
		Global.ensure_random_timetables()
		var selected: Array = Global.player_data[0]["timetable"]["selected_subjects"]
		assert_eq(selected.size(), 4)
		assert_has(selected, Global.FACULTIES[faculty]["subject"])
		var general := 0
		for subject in selected:
			if Global.SUBJECT_POOL.has(subject): general += 1
		assert_eq(general, 3)
		press(avatar.get_node("HBoxContainer/backbtn"))

func test_PLAY_START_05_placeholder_and_none() -> void:
	Global.setup_players(2)
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	assert_eq(avatar.faculty_select.text, "เลือกคณะเรียน")
	for explicit_none in [false, true]:
		if explicit_none: avatar.faculty_select.select(0)
		press(avatar.get_node("HBoxContainer/okayBtn"))
		Global.ensure_random_timetables()
		assert_eq(Global.player_data[0]["faculty_id"], "none")
		for subject in Global.player_data[0]["timetable"]["selected_subjects"]:
			assert_has(Global.SUBJECT_POOL, subject)
		press(avatar.get_node("HBoxContainer/backbtn"))

func test_PLAY_START_06_back_restores_each_player() -> void:
	Global.setup_players(2)
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	avatar.faculty_select.select(1)
	press(avatar.get_node("HBoxContainer2/VBoxContainer2/nexthair"))
	press(avatar.get_node("HBoxContainer/okayBtn"))
	avatar.faculty_select.select(4)
	press(avatar.get_node("HBoxContainer/backbtn"))
	assert_eq(avatar.faculty_select.selected, 1)
	assert_eq(avatar.current_hair, 1)
	press(avatar.get_node("HBoxContainer/okayBtn"))
	assert_eq(avatar.faculty_select.selected, 4)
	assert_eq(avatar.current_hair, 0)

func test_PLAY_START_07_back_to_menu() -> void:
	assert_eq(probe("back").get("scene"), "res://ui/MainMenu.tscn")

func test_PLAY_START_08_movement_and_interaction() -> void:
	open_game()
	var player = game.player_nodes[0]
	# Isolate directional input from the dorm's walls. Collision/path checks
	# are part of the documented manual pass through the actual map.
	var mask: int = player.collision_mask
	player.collision_mask = 0
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_press(action)
		player._physics_process(0.016)
		assert_almost_eq(player.velocity.length(), 180.0, 0.01)
		Input.action_release(action)
	Input.action_press("move_up")
	Input.action_press("move_right")
	player._physics_process(0.016)
	# The dorm contains collision shapes; actual velocity may be clipped.
	assert_lte(player.velocity.length(), 180.01)
	assert_almost_eq(Input.get_vector("move_left", "move_right", "move_up", "move_down").length(), 1.0, 0.01)
	Input.action_release("move_up")
	Input.action_release("move_right")
	player._physics_process(0.016)
	assert_eq(player.velocity, Vector2.ZERO)
	player.collision_mask = mask
	await visit("Food")
	assert_true(game.get_node("UILayer/ActivityPopup").visible)
	press(game.get_node("UILayer/ActivityPopup").close_btn)

extends "res://tests/support/game_test.gd"

func test_P01_setup_one_to_four_independent_players() -> void:
	for count in range(1, 5):
		Global.setup_players(count)
		assert_eq(Global.player_data.size(), count, "Requested player count")
		Global.player_data[0]["subject_progress"]["ภาษาไทย"] = 3
		for index in range(1, count):
			assert_true(Global.player_data[index]["subject_progress"].is_empty(), "Progress must not leak across players")

func test_P02_avatar_has_centered_faculty_placeholder() -> void:
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	var choice: OptionButton = avatar.get_node("PlayerRow/FacultySelect")
	assert_eq(choice.item_count, 5, "Four faculties plus no faculty")
	assert_eq(choice.selected, -1, "New player has a placeholder, not a selected faculty")
	assert_eq(choice.text, "เลือกคณะเรียน")
	assert_eq(choice.alignment, HORIZONTAL_ALIGNMENT_CENTER)

func test_P03_faculty_selection_is_saved_for_each_player() -> void:
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	var choice: OptionButton = avatar.get_node("PlayerRow/FacultySelect")
	choice.select(1)
	avatar.save_current_player_data()
	avatar.current_player_index = 2
	avatar.load_current_player_data()
	assert_eq(choice.selected, -1, "Player 2 starts independently")
	choice.select(4)
	avatar.save_current_player_data()
	avatar.current_player_index = 1
	avatar.load_current_player_data()
	assert_eq(choice.selected, 1, "Returning to player 1 restores computing")
	assert_eq(Global.player_data[1]["faculty_id"], "law")

func test_P04_leaving_placeholder_uses_general_subjects() -> void:
	var avatar = add_child_autofree(load("res://ui/AvatarMenu.tscn").instantiate())
	avatar.save_current_player_data()
	assert_eq(Global.player_data[0]["faculty_id"], "none", "Confirming placeholder means no faculty")

func test_P05_every_faculty_has_exactly_one_required_and_three_general_subjects() -> void:
	for faculty in Global.FACULTIES:
		if faculty["id"] == "none":
			continue
		Global.player_data[0]["faculty_id"] = faculty["id"]
		Global.ensure_random_timetables()
		var subjects: Array = Global.player_data[0]["timetable"]["selected_subjects"]
		assert_eq(subjects.size(), 4)
		assert_has(subjects, faculty["subject"], faculty["name"] + " required subject")
		var general := 0
		for subject in subjects:
			if Global.SUBJECT_POOL.has(subject):
				general += 1
		assert_eq(general, 3, "Three general subjects for " + faculty["name"])

func test_P06_no_faculty_has_four_general_subjects() -> void:
	for subject in Global.player_data[0]["timetable"]["selected_subjects"]:
		assert_has(Global.SUBJECT_POOL, subject)
	assert_eq(Global.player_data[0]["timetable"]["selected_subjects"].size(), 4)

func test_P07_legacy_save_keeps_existing_timetable() -> void:
	Global.player_data[0].erase("faculty_id")
	Global.player_data[0]["timetable"].erase("faculty_id")
	var before := canonical(Global.player_data[0]["timetable"])
	Global.ensure_random_timetables()
	assert_eq(canonical(Global.player_data[0]["timetable"]), before)

func test_P08_balanced_timetables_with_distinct_schedules_for_four_players() -> void:
	Global.setup_players(4)
	for iteration in range(25):
		Global.ensure_random_timetables(true)
		var signatures: Array = []
		for player in Global.player_data:
			var table: Dictionary = player["timetable"]
			var signature := Global._timetable_signature(table)
			assert_false(signatures.has(signature), "Each player has a different schedule")
			signatures.append(signature)
			var counts: Array = table["counts"].values()
			counts.sort()
			assert_eq(counts, [2, 2, 3, 3], "Ten classes balanced among four subjects")
			for day in table["daily_subjects"].values():
				assert_eq(day.size(), 2)
				assert_ne(day[0]["subject"], day[1]["subject"], "No duplicate subject on the same day")
				assert_lt(int(day[0]["end_minutes"]), int(day[1]["end_minutes"]), "Periods are chronological")

func test_P09_reopening_timetable_does_not_reroll_it() -> void:
	var before := canonical(Global.player_data)
	Global.ensure_random_timetables()
	assert_eq(canonical(Global.player_data), before)

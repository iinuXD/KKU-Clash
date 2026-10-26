extends "res://tests/support/player_flow_test.gd"

func test_PLAY_CLASS_01_timetable_and_players() -> void:
	open_game(4)
	for player in range(4):
		game.timetable_popup.open_for_player(player)
		var table: Dictionary = Global.player_data[player]["timetable"]
		assert_eq(table["selected_subjects"].size(), 4)
		var total := 0
		for day in table["daily_subjects"].values():
			assert_eq(day.size(), 2)
			assert_ne(day[0]["subject"], day[1]["subject"])
			assert_lte(int(day[0]["end_minutes"]), int(day[1]["start_minutes"]))
			total += day.size()
		assert_eq(total, 10)
		await frames() # Flush rows queued for deletion when switching player.
	press(game.timetable_popup.primary_button)
	await frames()

func test_PLAY_CLASS_02_reopen_timetable() -> void:
	open_game()
	var original := snapshot()
	for repeat in range(3):
		press(game.timetable_button)
		assert_true(game.timetable_popup.visible)
		press(game.timetable_popup.primary_button)
		assert_eq(snapshot(), original)
		await frames()

func test_PLAY_CLASS_03_too_early() -> void:
	open_game()
	reach_class(-31)
	await visit("Learn")
	assert_false(game.learning_popup.visible)
	assert_true(game.class_time_popup.status_label.text.contains("ยังไม่ถึงเวลา"))
	assert_eq(Global.player_data[0]["stats"]["study"], 0)
	press(game.class_time_popup.primary_button)

func test_PLAY_CLASS_04_wait_and_attend() -> void:
	open_game()
	var entry := reach_class(-15)
	await visit("Learn")
	assert_eq(game.class_time_popup.primary_choice, "wait")
	press(game.class_time_popup.primary_button)
	await finish_quiz()
	assert_true(entry["is_completed"])
	assert_eq(game.current_minutes, int(entry["end_minutes"]))

func test_PLAY_CLASS_05_cancel_wait_and_attend() -> void:
	open_game()
	reach_class(-15)
	var before := snapshot()
	var time: int = game.current_minutes
	await visit("Learn")
	press(game.class_time_popup.secondary_button)
	assert_eq(snapshot(), before)
	assert_eq(game.current_minutes, time)
	tick(15)
	await visit("Learn")
	press(game.class_time_popup.secondary_button)
	assert_eq(Global.player_data[0]["stats"]["study"], 0)
	assert_false(class_entry()["is_completed"])

func test_PLAY_CLASS_06_on_time_learning() -> void:
	open_game()
	var entry: Dictionary = await attend()
	assert_true(entry["is_completed"])
	assert_eq(entry["attendance_status"], "attended")
	assert_eq(Global.player_data[0]["stats"], {"happiness":40,"hunger":40,"stamina":55,"study":30})
	assert_eq(game.current_minutes, int(entry["end_minutes"]))

func test_PLAY_CLASS_07_late_learning() -> void:
	open_game()
	var entry: Dictionary = await attend(31)
	assert_eq(Global.player_data[0]["stats"]["study"], 23)
	assert_eq(int(entry["late_minutes"]), 31)

func test_PLAY_CLASS_08_missed_and_completed_classes_cannot_repeat() -> void:
	open_game()
	var first := reach_class(61)
	await visit("Learn")
	assert_eq(first["attendance_status"], "missed")
	press(game.class_time_popup.secondary_button if game.class_time_popup.secondary_button.visible else game.class_time_popup.primary_button)
	var second: Dictionary = Global.player_data[0]["timetable"]["daily_subjects"]["R1"][1]
	tick(int(second["start_minutes"]) - game.current_minutes)
	await visit("Learn")
	press(game.class_time_popup.primary_button)
	await finish_quiz()
	var study: int = Global.player_data[0]["stats"]["study"]
	await visit("Learn")
	assert_false(game.learning_popup.visible)
	assert_eq(Global.player_data[0]["stats"]["study"], study)
	press(game.class_time_popup.primary_button)

func test_PLAY_CLASS_09_second_week() -> void:
	open_game()
	var entry: Dictionary = await attend()
	var subject: String = entry["subject"]
	await reach_day(6)
	assert_eq(game.current_round, 6)
	assert_eq(class_entry()["subject"], subject)
	assert_false(class_entry()["is_completed"])
	assert_true(Global.player_data[0]["mission_scores"].has("1"))

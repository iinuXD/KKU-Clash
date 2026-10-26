extends "res://tests/support/player_flow_test.gd"

func begin_lesson() -> void:
	reach_class()
	await visit("Learn")
	press(game.class_time_popup.primary_button)
	assert_true(game.learning_popup.is_quiz_active)

func test_PLAY_QUIZ_01_all_correct() -> void:
	open_game()
	await begin_lesson()
	await finish_quiz(3)
	assert_eq(Global.player_data[0]["stats"]["study"], 30)

func test_PLAY_QUIZ_02_wrong_and_partial() -> void:
	for correct in [0, 1, 2]:
		SaveManager.start_new_game()
		Global.setup_players(1)
		Global.tutorial_seen = true
		open_game()
		await begin_lesson()
		await finish_quiz(correct)
		assert_eq(Global.player_data[0]["stats"]["study"], correct * 10)
		game.queue_free()
		await frames()

func test_PLAY_QUIZ_03_timeout_after_partial_answer() -> void:
	open_game()
	await begin_lesson()
	answer(true)
	game.learning_popup._process(21.0)
	assert_false(game.learning_popup.is_quiz_active)
	assert_true(game.learning_popup.summary_panel.visible)
	press(game.learning_popup.ok_button)
	assert_eq(Global.player_data[0]["stats"]["study"], 10)

func test_PLAY_QUIZ_04_answer_and_confirmation_repeat() -> void:
	open_game()
	await begin_lesson()
	var resolved: Array = []
	game.learning_popup.quiz_finished.connect(func(value): resolved.append(value))
	answer(true)
	assert_eq(game.learning_popup.current_question_index, 1, "One accepted press advances one question")
	await finish_quiz(3)
	press(game.learning_popup.ok_button)
	press(game.learning_popup.ok_button)
	assert_eq(resolved, [30], "Hidden confirmation button cannot award again")
	assert_eq(Global.player_data[0]["stats"]["study"], 30)

func test_PLAY_QUIZ_05_progress_from_scheduled_classes() -> void:
	open_game(2)
	var target: String = Global.player_data[0]["timetable"]["selected_subjects"][0]
	var lessons := 0
	while game.current_round <= 10 and lessons < 5:
		await resolve_cards()
		var key := "R%d" % (((game.current_round - 1) % 5) + 1)
		var classes: Array = Global.player_data[0]["timetable"]["daily_subjects"][key]
		for entry in classes:
			if entry["subject"] != target: continue
			if int(Global.player_data[0]["stats"]["stamina"]) <= 15:
				await choose_action("Dorm", "นอนพัก")
			if int(Global.player_data[0]["stats"]["hunger"]) <= 10:
				await choose_action("Food", "กินข้าวจานธรรมดา")
			tick(maxi(0, int(entry["start_minutes"]) - game.current_minutes))
			await visit("Learn")
			press(game.class_time_popup.primary_button)
			if game.learning_popup.is_quiz_active:
				await finish_quiz()
				lessons += 1
		if lessons < 5:
			await end_turn()
			await end_turn()
	assert_eq(lessons, 5)
	assert_eq(Global.player_data[0]["subject_progress"].get(target), 6)
	assert_false(Global.player_data[1]["subject_progress"].has(target))

func test_PLAY_QUIZ_06_exam_subjects_from_faculty() -> void:
	Global.player_data[0]["faculty_id"] = "computing" # A valid character-creation choice.
	open_game()
	await reach_day(11)
	press(game.class_time_popup.primary_button)
	var subjects: Array = []
	for index in range(4):
		subjects.append(game.learning_popup.subject_label.text)
		assert_eq(game.learning_popup.current_quiz_set.size(), 5)
		await finish_quiz(5)
	assert_eq(Global.player_data[0]["exam_result"]["total"], 20)
	assert_true(str(subjects).contains("การเขียนโปรแกรมเบื้องต้น"))
	press(game.class_time_popup.primary_button)

func test_PLAY_QUIZ_07_exam_timeout_score() -> void:
	open_game()
	await reach_day(11)
	press(game.class_time_popup.primary_button)
	answer(true)
	game.learning_popup._process(61.0)
	press(game.learning_popup.ok_button)
	for subject in range(3): await finish_quiz(0)
	assert_eq(Global.player_data[0]["exam_result"]["correct"], 1)
	assert_eq(Global.player_data[0]["exam_result"]["score"], 50)
	press(game.class_time_popup.primary_button)

func test_PLAY_QUIZ_08_every_player_exams_before_end() -> void:
	open_game(2)
	await reach_day(11)
	assert_false(game.endgame_ui.visible)
	await finish_exam(20)
	assert_eq(game.current_player_index, 1)
	assert_false(game.endgame_ui.visible)
	await finish_exam(0)
	assert_eq(Global.player_data[0]["exam_result"]["score"], 1000)
	assert_eq(Global.player_data[1]["exam_result"]["score"], 0)
	assert_true(game.endgame_ui.visible)

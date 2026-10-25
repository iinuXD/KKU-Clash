extends "res://tests/support/game_test.gd"

func test_Q01_all_ten_subjects_have_six_valid_question_levels() -> void:
	var quiz = make_quiz()
	assert_eq(quiz.SUBJECT_FILES.size(), 10)
	for subject in quiz.SUBJECT_FILES:
		var bank: Dictionary = quiz._load_subject_database(subject)
		for level in range(1, 7):
			assert_true(bank.has(str(level)), "%s level %d exists" % [subject, level])
			var questions: Array = bank.get(str(level), [])
			assert_gte(questions.size(), 5, "At least five exam questions at every level")
			for question in questions:
				var choices: Array = question.get("choices", [])
				assert_eq(choices.size(), 4, "Four choices")
				assert_false(str(question.get("q", "")).is_empty(), "Nonempty question")
				var answer = question.get("answer")
				if answer is String:
					assert_has(choices, answer, "Correct answer is among choices")
				else:
					assert_between(int(answer), 0, 3, "Valid answer index")

func test_Q02_faculty_quizzes_and_exams_load_at_every_level() -> void:
	var quiz = make_quiz()
	for faculty in Global.FACULTIES:
		if faculty["id"] == "none":
			continue
		for level in range(1, 7):
			quiz.start_quiz(faculty["subject"], level)
			assert_true(quiz.is_quiz_active)
			assert_eq(quiz.current_quiz_set.size(), 3)
			quiz.start_exam(faculty["subject"], level, 5)
			assert_true(quiz.is_quiz_active)
			assert_eq(quiz.current_quiz_set.size(), 5)

func answer_question(quiz, correctly: bool) -> void:
	for index in range(4):
		if (quiz.choice_buttons[index].text == quiz.current_correct_answer) == correctly:
			quiz.choice_buttons[index].pressed.emit()
			return

func test_Q03_correct_answers_emit_thirty_study_points() -> void:
	var quiz = make_quiz()
	watch_signals(quiz)
	quiz.start_quiz("ภาษาไทย")
	for question in range(3):
		answer_question(quiz, true)
	assert_eq(quiz.correct_answers, 3)
	assert_false(quiz.is_quiz_active)
	quiz.ok_button.pressed.emit()
	assert_signal_emitted_with_parameters(quiz, "quiz_finished", [30])

func test_Q04_incorrect_answers_do_not_reward_study() -> void:
	var quiz = make_quiz()
	quiz.start_quiz("คณิตศาสตร์")
	for question in range(3):
		answer_question(quiz, false)
	assert_eq(quiz.correct_answers, 0)
	assert_eq(quiz._calculate_study_gained(), 0)

func test_Q05_late_attendance_multiplier_is_applied() -> void:
	var quiz = make_quiz()
	quiz.start_quiz("ภาษาไทย", 1, 0.75, "มาสาย")
	quiz.correct_answers = 3
	assert_eq(quiz._calculate_study_gained(), 23, "30 x 0.75 rounds to 23")

func test_Q06_timeout_ends_quiz_and_disables_answers() -> void:
	var quiz = make_quiz()
	quiz.start_quiz("ภาษาอังกฤษ")
	quiz.time_left = 0.01
	quiz._process(0.1)
	assert_false(quiz.is_quiz_active)
	assert_true(quiz.summary_panel.visible)
	assert_eq(quiz.time_left, 0.0)
	for button in quiz.choice_buttons:
		assert_true(button.disabled)

func test_Q07_exam_emits_correct_count_and_total_without_quiz_reward() -> void:
	var quiz = make_quiz()
	watch_signals(quiz)
	quiz.start_exam("กฎหมายเบื้องต้น", 1, 5)
	for question in range(5):
		answer_question(quiz, question < 3)
	quiz.ok_button.pressed.emit()
	assert_signal_emitted_with_parameters(quiz, "exam_finished", [{"correct": 3, "total": 5}])
	assert_signal_not_emitted(quiz, "quiz_finished")

func test_Q08_final_exam_subjects_match_faculty_timetable() -> void:
	var game = make_map()
	Global.player_data[0]["faculty_id"] = "medicine"
	Global.ensure_random_timetables()
	var subjects: Array[String] = game._get_exam_subjects(Global.player_data[0])
	assert_eq(subjects.size(), 4)
	assert_has(subjects, "กายวิภาคศาสตร์เบื้องต้น")
	assert_eq(subjects, Global.player_data[0]["timetable"]["selected_subjects"])

func test_Q09_invalid_exam_subject_aborts_and_emits_zero_result() -> void:
	var quiz = make_quiz()
	watch_signals(quiz)
	quiz.start_exam("missing_subject", 1, 5)
	await wait_process_frames(2)
	assert_false(quiz.is_quiz_active)
	assert_signal_emitted_with_parameters(quiz, "exam_finished", [{"correct": 0, "total": 5}])

extends Control

@onready var main_quest_label: Label = $EndGameWindow/MainVBox/MainQuestLabel
@onready var final_score_label: Label = $EndGameWindow/MainVBox/ScoreBox/FinalScoreLabel
@onready var study_label: Label = $EndGameWindow/MainVBox/ScoreBox/StudyLabel
@onready var money_label: Label = $EndGameWindow/MainVBox/ScoreBox/MoneyLabel
@onready var classes_label: Label = $EndGameWindow/MainVBox/ScoreBox/ClassesLabel
@onready var status_score_label: Label = $EndGameWindow/MainVBox/ScoreBox/StatusScoreLabel
@onready var mission_score_label: Label = $EndGameWindow/MainVBox/ScoreBox/MissionScoreLabel
@onready var exam_score_label: Label = $EndGameWindow/MainVBox/ScoreBox/ExamScoreLabel
@onready var rating_label: Label = $EndGameWindow/MainVBox/RatingLabel
@onready var player_scores: VBoxContainer = $EndGameWindow/MainVBox/PlayerScores
@onready var restart_button: Button = $EndGameWindow/MainVBox/ButtonRow/RestartButton
@onready var exit_button: Button = $EndGameWindow/MainVBox/ButtonRow/ExitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	hide()

func setup(_final_score: float = 0.0, exam_bonus_pct: int = 0, remaining_money: int = -1) -> void:
	var player_results := _get_player_results()
	var highest_score := 0
	var highest_rating := "ต้องปรับปรุง"
	for result in player_results:
		if result.total > highest_score:
			highest_score = result.total
			highest_rating = result.rating

	final_score_label.text = "คะแนนสูงสุด  %d / 3000" % highest_score
	rating_label.text = "ระดับสูงสุด: %s" % highest_rating
	_render_player_scores()


func _get_player_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var player_count := mini(4, Global.player_data.size())
	for player_index in range(player_count):
		results.append(_calculate_player_scores(Global.player_data[player_index]))
	return results


func _render_player_scores() -> void:
	for child in player_scores.get_children():
		child.queue_free()

	var player_count := mini(4, Global.player_data.size())
	if player_count == 0:
		_add_player_score_row(0, {})
		return

	for player_index in range(player_count):
		_add_player_score_row(player_index, Global.player_data[player_index])


func _add_player_score_row(player_index: int, player_data: Dictionary) -> void:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 50)
	row_panel.add_theme_stylebox_override("panel", _make_player_row_style())

	var row := Label.new()
	var scores := _calculate_player_scores(player_data)
	row.text = "ผู้เล่น %d   •   %d / 3000   •   %s\nเข้าเรียน %d/10   •   เงินคงเหลือ ฿%d" % [
		player_index + 1,
		scores.total,
		scores.rating,
		scores.classes,
		int(player_data.get("money", 0))
	]
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_font_size_override("font_size", 17)
	row.add_theme_color_override("font_color", Color("#471c12"))
	row_panel.add_child(row)
	player_scores.add_child(row_panel)


func _make_player_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff5df")
	style.border_color = Color("#b96a43")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _calculate_player_scores(player_data: Dictionary) -> Dictionary:
	var stats: Dictionary = player_data.get("stats", {})
	var learning := clampi(int(stats.get("study", 0)), 0, 400)
	var mental := clampi(int(stats.get("happiness", 0)), 0, 200)
	var body := clampi(int(stats.get("stamina", 0)), 0, 200)
	var nutrition := clampi(int(stats.get("hunger", 0)), 0, 200)
	var completed_rounds := 0
	var classes := 0
	var timetable: Dictionary = player_data.get("timetable", {})
	var daily_subjects: Dictionary = timetable.get("daily_subjects", {})

	for round_num in range(1, 11):
		var day_key := "R" + str(((round_num - 1) % 5) + 1)
		var round_complete := true
		var has_classes := false
		for class_entry in daily_subjects.get(day_key, []):
			has_classes = true
			if class_entry.get("is_completed", false):
				classes += 1
			else:
				round_complete = false
		if round_complete and has_classes:
			completed_rounds += 1

	var status := learning + mental + body + nutrition
	var missions := completed_rounds * 100
	var exam := int(round(float(learning) / 400.0 * 1000.0))
	var total := status + missions + exam
	var rating := "ต้องปรับปรุง"
	if total >= 2100:
		rating = "ดีมาก"
	elif total >= 1200:
		rating = "พอใช้"

	return {
		"total": total,
		"classes": mini(classes, 10),
		"rating": rating
	}

func _calculate_scores(exam_bonus_pct: int) -> Dictionary:
	var learning := clampi(Global.study_score, 0, 400)
	var mental := clampi(Global.happy, 0, 200)
	var body := clampi(Global.energy, 0, 200)
	var nutrition := clampi(Global.hunger, 0, 200)
	var status := learning + mental + body + nutrition
	var completed_rounds := 0

	for round_num in range(1, 11):
		var day_key := "R" + str(((round_num - 1) % 5) + 1)
		var round_complete := true
		var round_has_missions := false
		for player_data in Global.player_data:
			var timetable: Dictionary = player_data.get("timetable", {})
			var classes: Array = timetable.get("daily_subjects", {}).get(day_key, [])
			if classes.is_empty():
				continue
			round_has_missions = true
			for class_entry in classes:
				if not class_entry.get("is_completed", false):
					round_complete = false
		if round_complete and round_has_missions:
			completed_rounds += 1

	var missions := completed_rounds * 100
	var exam_source := learning
	var exam := mini(1000, int(round(float(exam_source) / 400.0 * 1000.0)))
	if exam_bonus_pct > 0:
		exam = mini(1000, int(round(exam * (1.0 + exam_bonus_pct / 100.0))))

	var total := status + missions + exam
	var rating := "ต้องปรับปรุง"
	var rating_detail := "ลองทำภารกิจให้ครบ ดูแลค่าสถานะ และเตรียมตัวสอบให้มากขึ้น"
	if total >= 2100:
		rating = "ดีมาก"
		rating_detail = "ผลงานยอดเยี่ยม รักษาสมดุลระหว่างเรียน ภารกิจ และการดูแลตัวเองได้ดี"
	elif total >= 1200:
		rating = "พอใช้"
		rating_detail = "ทำได้ดีในบางด้าน แต่ยังมีโอกาสพัฒนาคะแนนให้สูงขึ้น"

	return {
		"learning": learning,
		"mental": mental,
		"body": body,
		"nutrition": nutrition,
		"status": status,
		"missions": missions,
		"exam": exam,
		"total": total,
		"rating": rating,
		"rating_detail": rating_detail
	}

func _on_restart_pressed() -> void:
	get_tree().paused = false
	# Reset all global state
	Global.money = 2000
	Global.study_score = 0
	Global.happy = 40
	Global.energy = 100
	Global.hunger = 50
	Global.current_round = 1
	Global.max_rounds = 5
	Global.time_remaining = 24
	Global.max_time = 24
	Global.travel_time_cost = 2
	Global.travel_energy_cost = 0
	Global.is_injured = false
	Global.is_sick = false
	Global.sick_sleep_count = 0
	Global.has_medicine = false
	Global.lost_item_active = false
	Global.class_join_count = 0
	Global.exam_bonus_pct = 0
	Global.next_round_time_penalty_pct = 0
	Global.weather = "normal"
	Global.skip_next_activity_ui = false
	get_tree().reload_current_scene()


func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

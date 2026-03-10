extends Control

@onready var main_quest_label: Label = $EndGameWindow/MainVBox/MainQuestLabel
@onready var final_score_label: Label = $EndGameWindow/MainVBox/ScoreBox/FinalScoreLabel
@onready var study_label: Label = $EndGameWindow/MainVBox/ScoreBox/StudyLabel
@onready var money_label: Label = $EndGameWindow/MainVBox/ScoreBox/MoneyLabel
@onready var classes_label: Label = $EndGameWindow/MainVBox/ScoreBox/ClassesLabel
@onready var restart_button: Button = $EndGameWindow/MainVBox/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)

func setup(final_score: float, exam_bonus_pct: int) -> void:
	var quest_done: bool = Global.class_join_count >= 10
	main_quest_label.text = "[Main Quest] Attend 10 Classes: %s  (%d / 10)" % [
		"COMPLETE!" if quest_done else "FAILED", Global.class_join_count
	]
	final_score_label.text = "Final Score:  %.1f" % final_score
	var boosted: int = int(Global.study_score * (1.0 + exam_bonus_pct / 100.0))
	study_label.text = "Study Score: %d   (Exam Bonus: +%d%%  ->  %d)" % [
		Global.study_score, exam_bonus_pct, boosted
	]
	money_label.text = "Money Remaining:  $%d" % Global.money
	classes_label.text = "Classes Attended:  %d / 10" % Global.class_join_count

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

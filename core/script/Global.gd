extends Node

# Player Stats
var money: int = 2000
var study_score: int = 0
var happy: int = 40
var energy: int = 100
var hunger: int = 50

var current_round: int = 1
var max_rounds: int = 5

var time_remaining: int = 24 # Let's assume 24 "hours" or units per round
var max_time: int = 24

# Event Modifiers
var travel_time_cost: int = 2
var travel_energy_cost: int = 0
var is_injured: bool = false
var is_sick: bool = false

# Quests
var sick_sleep_count: int = 0
var has_medicine: bool = false
var lost_item_active: bool = false
var class_join_count: int = 0  # Main quest: join class 10 times

# Card Event modifiers
var exam_bonus_pct: int = 0
var next_round_time_penalty_pct: int = 0

# Weather state — reset to "normal" each round
# "normal" | "hot" (more energy per travel) | "heavy_rain" (more time per travel)
var weather: String = "normal"

# Set by canteen_full "eat outside" choice to skip the Food Court activity UI once
var skip_next_activity_ui: bool = false

# Helper function to keep stats between 0 and 100 (except money/study)
func update_stat(stat_name: String, amount: int):
	match stat_name:
		"happy": happy = clampi(happy + amount, 0, 200)
		"energy": energy = clampi(energy + amount, 0, 200)
		"hunger": hunger = clampi(hunger + amount, 0, 200)
		"money": money += amount
		"study_score": study_score = clampi(study_score + amount, 0, 400)
		
# Select Player
# player count
var player_count: int = 1

# Array สำหรับเก็บข้อมูล ของแต่ละคน
var player_data: Array = []

# Timetable rules shared by the pre-game viewer and the main game.
const SUBJECT_POOL: Array[String] = [
	"ภาษาไทย",
	"คณิตศาสตร์",
	"ภาษาอังกฤษ",
	"ฟิสิกส์",
	"เคมี",
	"ชีววิทยา"
]
const TIMETABLE_DAY_KEYS: Array[String] = ["R1", "R2", "R3", "R4", "R5"]
const TIMETABLE_PERIODS: Array[Dictionary] = [
	{"column": 1, "label": "08:00 - 10:00", "start_minutes": 480, "end_minutes": 600},
	{"column": 2, "label": "10:00 - 12:00", "start_minutes": 600, "end_minutes": 720},
	{"column": 4, "label": "13:00 - 15:00", "start_minutes": 780, "end_minutes": 900},
	{"column": 5, "label": "15:00 - 17:00", "start_minutes": 900, "end_minutes": 1020}
]

# ฟังก์ชันสำหรับรีเซ็ตและเตรียมข้อมูลผู้เล่น
func setup_players(count: int) -> void:
	player_count = count
	player_data.clear()
	
	for i in range(player_count):
		# เก็บระดับการเรียนแยกรายวิชา โดยไม่กระทบข้อมูลผู้เล่นส่วนอื่น
		player_data.append({"subject_progress": {}})
	print(player_count)


# Creates a separate balanced timetable for every player. Old manually-built
# timetables are replaced once because the registration system is no longer used.
func ensure_random_timetables(force_regenerate: bool = false) -> void:
	var used_signatures: Dictionary = {}

	for player_index in range(player_data.size()):
		var existing: Dictionary = player_data[player_index].get("timetable", {})
		var needs_generation: bool = force_regenerate or not bool(existing.get("generated_randomly", false))
		var signature := ""

		if not needs_generation:
			signature = _timetable_signature(existing)
			needs_generation = signature.is_empty() or used_signatures.has(signature)

		if needs_generation:
			var generated := _generate_random_timetable()
			signature = _timetable_signature(generated)
			while used_signatures.has(signature):
				generated = _generate_random_timetable()
				signature = _timetable_signature(generated)
			player_data[player_index]["timetable"] = generated

		used_signatures[signature] = true


func _generate_random_timetable() -> Dictionary:
	var selected_subjects: Array = SUBJECT_POOL.duplicate()
	selected_subjects.shuffle()
	selected_subjects.resize(4)

	# Ten weekly classes distributed as 3, 3, 2, 2.
	var target_counts := [3, 3, 2, 2]
	var session_subjects: Array[String] = []
	var subject_counts: Dictionary = {}
	for subject_index in range(selected_subjects.size()):
		var subject: String = selected_subjects[subject_index]
		var count: int = target_counts[subject_index]
		subject_counts[subject] = count
		for _class_index in range(count):
			session_subjects.append(subject)

	# Prevent both same-day duplicates and identical subjects in consecutive slots.
	var valid_order := false
	while not valid_order:
		session_subjects.shuffle()
		valid_order = true
		for class_index in range(1, session_subjects.size()):
			if session_subjects[class_index] == session_subjects[class_index - 1]:
				valid_order = false
				break

	var positions: Dictionary = {}
	var daily_subjects: Dictionary = {}
	var session_index := 0

	for day_key in TIMETABLE_DAY_KEYS:
		var available_periods: Array = TIMETABLE_PERIODS.duplicate(true)
		available_periods.shuffle()
		available_periods.resize(2)
		available_periods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["start_minutes"]) < int(b["start_minutes"])
		)

		var day_classes: Array = []
		for period in available_periods:
			var subject := session_subjects[session_index]
			var column: int = period["column"]
			var entry := {
				"subject": subject,
				"is_completed": false,
				"attendance_status": "pending",
				"col": column,
				"period": column,
				"time_label": period["label"],
				"start_minutes": period["start_minutes"],
				"end_minutes": period["end_minutes"]
			}
			day_classes.append(entry)
			positions["Cell_%sC%d" % [day_key, column]] = subject
			session_index += 1
		daily_subjects[day_key] = day_classes

	return {
		"generated_randomly": true,
		"positions": positions,
		"counts": subject_counts,
		"selected_subjects": selected_subjects,
		"daily_subjects": daily_subjects
	}


func _timetable_signature(timetable: Dictionary) -> String:
	var signature_parts: Array[String] = []
	var daily_subjects: Dictionary = timetable.get("daily_subjects", {})
	for day_key in TIMETABLE_DAY_KEYS:
		for entry in daily_subjects.get(day_key, []):
			signature_parts.append("%s:%s:%s" % [day_key, entry.get("period", entry.get("col", 0)), entry.get("subject", "")])
	return "|".join(signature_parts)

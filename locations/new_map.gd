extends Node2D

signal forced_sleep_finished

@onready var original_player: CharacterBody2D = $Player
@onready var dorm_marker: Marker2D = $waypiont/Dorm 

@onready var camera: Camera2D = $Camera
@onready var player_panel = $UILayer/PlayerPanel
@onready var night_lighting: CanvasModulate = $NightLighting
@onready var pause_menu: Control = $UILayer/PauseMenu
@onready var endgame_ui: Control = $UILayer/EndgameUI

# >>> 1. อ้างอิงหน้าต่างควิซ (ให้แน่ใจว่าลากมาวางใน UILayer แล้ว) <<<
@onready var learning_popup = $UILayer/learning_popup 
@onready var scenario_popup = $UILayer/ScenarioPopup
@onready var random_event_popup = $UILayer/RandomEventPopup

const TIMETABLE_VIEWER_SCENE = preload("res://ui/registration_ui.tscn")
const CLASS_TIME_POPUP_SCENE = preload("res://ui/class_time_popup.tscn")
const SAVE_SLOT_MENU_SCENE = preload("res://ui/save_slot_menu.tscn")

var player_nodes: Array[CharacterBody2D] = [] 
var current_player_index: int = 0     
var is_walking: bool = false
var is_turn_transitioning: bool = false
var is_forcing_sleep: bool = false
var is_random_event_active: bool = false
var random_event_turns: Dictionary = {}
var scenario_attempt_turns: Dictionary = {}
var occurred_scenarios: Dictionary = {}
var scenario_failed_attempts: int = 0
var timetable_popup: Control
var timetable_button: Button
var class_time_popup: Control
var save_slot_menu: SaveSlotMenu
var menu_button: Button

var current_round: int = 1
var max_rounds: int = 11     

const NORMAL_WAKE_MINUTES := 6 * 60
const LATE_WAKE_MINUTES := 10 * 60
const SLEEP_MINUTES := 27 * 60
const REAL_SECONDS_PER_GAME_MINUTE := 0.15
const NIGHT_START_MINUTES := 18 * 60
const NIGHT_FULL_MINUTES := 24 * 60
const NIGHT_COLOR := Color(0.48, 0.55, 0.78, 1.0)
const SCENARIO_BASE_CHANCE := 0.30
const SCENARIO_CHANCE_STEP := 0.10
const SCENARIO_MAX_CHANCE := 0.70
const CLASS_EARLY_WAIT_MINUTES := 30
const CLASS_ON_TIME_GRACE_MINUTES := 30
const CLASS_LATE_LIMIT_MINUTES := 60
const CLASS_LATE_STUDY_MULTIPLIER := 0.75
const FINAL_EXAM_ROUND := 11
const EXAM_QUESTIONS_PER_SUBJECT := 5

var player_minutes: Array[int] = []
var player_time_speed_multipliers: Array[float] = []
var late_wake_players: Array[bool] = []
var current_minutes: int = NORMAL_WAKE_MINUTES
var real_time_accumulator: float = 0.0

# เพิ่มตัวแปรสำหรับจอดำตอนสลบ
var fade_rect: ColorRect
var turn_notice: Label

var activity_effects = {
	"Dorm": {
		"นอนพัก": {"stamina": 40},
		"อ่านหนังสือ": {"study": 5, "stamina": -10, "happiness": -5},
		"จบเทิร์น": {}
	},
	"Library": {
		"อ่านหนังสือ": {"study": 8, "stamina": -10, "hunger": -5},
		"ยืมหนังสือ": {"money": -20, "study": 3, "happiness": 5},
		"นั่งเล่น": {"happiness": 15, "stamina": 5}
	},
	"Food": {
		"กินข้าวจานธรรมดา": {"money": -40, "hunger": 30},
		"กินข้าวจานพิเศษ": {"money": -60, "hunger": 45, "happiness": 10},
		"กินของทานเล่น": {"money": -25, "hunger": 15, "happiness": 15},
		"ทำ Parttime": {"money": 500, "stamina": -20, "hunger": -15}
	},
	"Shop": {
		"ซื้อกาแฟ": {"money": -40, "stamina": 15, "hunger": 5},
		"ซื้อขนม": {"money": -30, "hunger": 10, "happiness": 10},
		"ซื้อยา": {"money": -100, "stamina": 30},
		"ทำ Parttime": {"money": 500, "stamina": -20, "happiness": -5}
	},
	"Hospital": {
		"เข้ารับการรักษา": {"money": -500, "stamina": 100, "happiness": 20},
		"ซื้อยา": {"money": -150, "stamina": 30},
		"ตรวจสุขภาพ": {"money": -250, "stamina": 20, "happiness": 10}
	},
	"Sport": {
		"วิ่ง": {"happiness": 15, "stamina": -15, "hunger": -10},
		"เล่นกีฬา": {"happiness": 25, "stamina": -25, "hunger": -15},
		"ออกกำลังกาย": {"happiness": 10, "stamina": -10, "hunger": -5}
	},
	"Fun": {
		"ร้องคาราโอเกะ": {"money": -150, "happiness": 40, "stamina": -10},
		"ปาร์ตี้": {"money": -300, "happiness": 60, "stamina": -25, "study": -5},
		"ทำ Parttime": {"money": 500, "stamina": -30, "hunger": -20}
	}
} 

var activity_time_costs = {
	"Dorm": {"นอนพัก": 120, "เล่นเกม": 120, "อ่านหนังสือ": 120, "จบเทิร์น": 0},
	"Food": {"กินข้าวจานธรรมดา": 30, "กินข้าวจานพิเศษ": 30, "กินของทานเล่น": 30, "ทำ Parttime": 240},
	"Library": {"อ่านหนังสือ": 120, "ยืมหนังสือ": 10, "นั่งเล่น": 60},
	"Shop": {"ซื้อกาแฟ": 10, "ซื้อขนม": 10, "ซื้อยา": 10, "ทำ Parttime": 240},
	"Hospital": {"เข้ารับการรักษา": 60, "ซื้อยา": 10, "ตรวจสุขภาพ": 60},
	"Sport": {"วิ่ง": 120, "เล่นกีฬา": 180, "ออกกำลังกาย": 120},
	"Fun": {"ร้องคาราโอเกะ": 180, "ปาร์ตี้": 240, "ทำ Parttime": 240}
}

func _process(delta: float) -> void:
	if get_tree().paused or is_walking or is_forcing_sleep or current_round == FINAL_EXAM_ROUND:
		return

	var activity_popup = $UILayer/ActivityPopup
	if activity_popup.visible or learning_popup.visible or scenario_popup.visible or is_random_event_active or random_event_popup.visible or (timetable_popup and timetable_popup.visible) or (class_time_popup and class_time_popup.visible) or (save_slot_menu and save_slot_menu.visible):
		return

	real_time_accumulator += delta * _get_current_time_speed()
	var minutes_to_advance = int(real_time_accumulator / REAL_SECONDS_PER_GAME_MINUTE)
	if minutes_to_advance <= 0:
		return

	real_time_accumulator -= minutes_to_advance * REAL_SECONDS_PER_GAME_MINUTE
	_advance_time(minutes_to_advance)

# ==========================================
# ส่วนเริ่มต้นเกม
# ==========================================
func _ready() -> void:
	var loaded_checkpoint := SaveManager.take_pending_load()
	if not loaded_checkpoint.is_empty():
		var global_state = loaded_checkpoint.get("global", {})
		if global_state is Dictionary:
			Global.import_save_data(global_state)

	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_mock_data()
	Global.ensure_random_timetables()
	_setup_fade() # เรียกใช้ระบบจอดำตอนสลบ
	_update_night_lighting()
	_setup_turn_notice()
	_setup_timetable_ui()
	_setup_class_time_ui()
	_setup_save_ui()
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.save_requested.connect(_on_pause_save_requested)
	pause_menu.quit_requested.connect(_return_to_main_menu)
	
	if player_panel:
		player_panel.setup_players_ui()
		
	var players = max(1, Global.player_data.size())
	for i in range(players):
		var p_node: CharacterBody2D = original_player if i == 0 else original_player.duplicate()
		if i != 0: add_child(p_node)
		
		setup_player(i, p_node)
		p_node.activity_requested.connect(_on_player_activity_requested)
		player_nodes.append(p_node)
		play_animation(p_node, "idle")
		player_minutes.append(NORMAL_WAKE_MINUTES)
		player_time_speed_multipliers.append(1.0)
		late_wake_players.append(false)

	if not loaded_checkpoint.is_empty():
		var map_state = loaded_checkpoint.get("map", {})
		if map_state is Dictionary:
			_apply_map_save_data(map_state)

	SaveManager.set_checkpoint(_build_checkpoint_state())
	setup_current_turn()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()

func _pause_game() -> void:
	get_tree().paused = true
	pause_menu.open_menu()

func _resume_game() -> void:
	pause_menu.close_menu()
	get_tree().paused = false

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")


func _setup_timetable_ui() -> void:
	if not has_node("UILayer"):
		return

	timetable_popup = TIMETABLE_VIEWER_SCENE.instantiate()
	timetable_popup.in_game_mode = true
	$UILayer.add_child(timetable_popup)

	timetable_button = Button.new()
	timetable_button.text = "ตารางเรียน"
	timetable_button.z_index = 50
	timetable_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# วางต่อจากแถบวันที่/เวลาให้เป็นแถวเดียวกัน และคืนพื้นที่ด้านล่างให้ป้ายสถานที่
	timetable_button.offset_left = 160.0
	timetable_button.offset_top = 8.0
	timetable_button.offset_right = 300.0
	timetable_button.offset_bottom = 48.0
	timetable_button.add_theme_font_size_override("font_size", 22)
	timetable_button.add_theme_color_override("font_color", Color("#471c12"))
	timetable_button.add_theme_color_override("font_hover_color", Color("#471c12"))
	timetable_button.add_theme_color_override("font_pressed_color", Color("#471c12"))
	timetable_button.add_theme_stylebox_override("normal", _make_timetable_button_style(Color("#f7e8cd"), Color("#8f371f")))
	timetable_button.add_theme_stylebox_override("hover", _make_timetable_button_style(Color("#ffe0a2"), Color("#b34b28")))
	timetable_button.add_theme_stylebox_override("pressed", _make_timetable_button_style(Color("#ebc98f"), Color("#6f2919")))
	timetable_button.pressed.connect(_on_timetable_button_pressed)
	$UILayer.add_child(timetable_button)


func _setup_class_time_ui() -> void:
	if not has_node("UILayer"):
		return
	class_time_popup = CLASS_TIME_POPUP_SCENE.instantiate()
	$UILayer.add_child(class_time_popup)


func _setup_save_ui() -> void:
	if not has_node("UILayer"):
		return

	save_slot_menu = SAVE_SLOT_MENU_SCENE.instantiate() as SaveSlotMenu
	$UILayer.add_child(save_slot_menu)

	menu_button = Button.new()
	menu_button.text = "☰"
	menu_button.tooltip_text = "เมนู"
	menu_button.z_index = 50
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -60.0
	menu_button.offset_top = 10.0
	menu_button.offset_right = -10.0
	menu_button.offset_bottom = 58.0
	menu_button.add_theme_font_size_override("font_size", 25)
	menu_button.add_theme_color_override("font_color", Color("#fff0cf"))
	menu_button.add_theme_color_override("font_hover_color", Color.WHITE)
	menu_button.add_theme_stylebox_override("normal", _make_timetable_button_style(Color("#8f371f"), Color("#d99a43")))
	menu_button.add_theme_stylebox_override("hover", _make_timetable_button_style(Color("#b34b28"), Color("#ffc866")))
	menu_button.add_theme_stylebox_override("pressed", _make_timetable_button_style(Color("#6f2919"), Color("#d99a43")))
	menu_button.pressed.connect(_pause_game)
	$UILayer.add_child(menu_button)


func _get_current_player_money() -> int:
	if current_player_index >= 0 and current_player_index < Global.player_data.size():
		return int(Global.player_data[current_player_index].get("money", 0))
	return Global.money


func _show_endgame() -> void:
	if timetable_button:
		timetable_button.hide()
	endgame_ui.show()
	endgame_ui.setup(0.0, Global.exam_bonus_pct, _get_current_player_money())


func _on_pause_save_requested() -> void:
	if is_walking or is_forcing_sleep or is_random_event_active:
		return
	var activity_popup = $UILayer/ActivityPopup
	if activity_popup.visible or learning_popup.visible or scenario_popup.visible or random_event_popup.visible or (timetable_popup and timetable_popup.visible) or (class_time_popup and class_time_popup.visible):
		return

	is_walking = true
	player_nodes[current_player_index].set_movement_enabled(false)
	save_slot_menu.open_menu(SaveSlotMenu.MenuMode.SAVE)
	await save_slot_menu.closed

	if not is_forcing_sleep and current_player_index < player_nodes.size():
		player_nodes[current_player_index].set_movement_enabled(true)
	is_walking = false

func _make_timetable_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	return style


func _on_timetable_button_pressed() -> void:
	var activity_popup = $UILayer/ActivityPopup
	if is_walking or is_forcing_sleep or is_random_event_active:
		return
	if activity_popup.visible or learning_popup.visible or scenario_popup.visible or random_event_popup.visible or (class_time_popup and class_time_popup.visible):
		return

	is_walking = true
	player_nodes[current_player_index].set_movement_enabled(false)
	timetable_popup.open_for_player(current_player_index)
	await timetable_popup.closed

	if not is_forcing_sleep and current_player_index < player_nodes.size():
		player_nodes[current_player_index].set_movement_enabled(true)
	is_walking = false

func _setup_fade() -> void:
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) 
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT) 
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	fade_rect.z_index = 100 
	if has_node("UILayer"): $UILayer.add_child(fade_rect)
	else: add_child(fade_rect)
	
func _setup_mock_data() -> void:
	if Global.player_data.size() == 0:
		Global.player_data = [{}, {}]
	
	for i in range(Global.player_data.size()):
		if not Global.player_data[i].has("money"): Global.player_data[i]["money"] = 1000
		if not Global.player_data[i].has("stats"):
			Global.player_data[i]["stats"] = {"happiness": 50, "hunger": 50, "stamina": 70, "study": 0}
		if not Global.player_data[i].has("event_missions"):
			Global.player_data[i]["event_missions"] = []
		if not Global.player_data[i].has("event_history"):
			Global.player_data[i]["event_history"] = []

# ==========================================
# ระบบเทิร์น (Turn Management)
# ==========================================
func setup_current_turn() -> void:
	current_minutes = player_minutes[current_player_index]
	real_time_accumulator = 0.0
	var active_player = player_nodes[current_player_index]
	var is_exam_round: bool = current_round == FINAL_EXAM_ROUND
	var should_draw_events: bool = _should_draw_random_events()
	
	for i in range(player_nodes.size()):
		if i == current_player_index:
			player_nodes[i].show()
			player_nodes[i].global_position = dorm_marker.global_position
			player_nodes[i].set_movement_enabled(not should_draw_events and not is_exam_round)
		else:
			player_nodes[i].hide()  
			player_nodes[i].set_movement_enabled(false)
	camera.target = active_player

	if player_panel:
		player_panel.update_turn_ui(current_player_index)
		player_panel.update_time_ui(current_minutes, NORMAL_WAKE_MINUTES, SLEEP_MINUTES, _get_current_time_speed())
		player_panel.update_round_ui(current_round, max_rounds)

	if is_exam_round:
		if timetable_button:
			timetable_button.hide()
		if player_panel and player_panel.has_method("update_mission"):
			player_panel.update_mission("สอบปลายภาค 4 วิชา\nวิชาละ 5 ข้อ")
		_start_final_exam_turn.call_deferred()
	else:
		if timetable_button:
			timetable_button.show()
		render_mission_text(current_player_index, current_round)
	if should_draw_events and not is_exam_round:
		_start_turn_random_events.call_deferred()


func _should_draw_random_events() -> bool:
	# รอบแรกให้ผู้เล่นทำความคุ้นเคยกับเกมก่อน เริ่ม Event ตั้งแต่รอบที่ 2
	if current_round <= 1 or current_round >= FINAL_EXAM_ROUND or current_round > max_rounds or not random_event_popup:
		return false
	var turn_key := "%d:%d" % [current_round, current_player_index]
	return not random_event_turns.has(turn_key)


func _start_turn_random_events() -> void:
	var event_player_index := current_player_index
	var turn_key := "%d:%d" % [current_round, event_player_index]
	if random_event_turns.has(turn_key):
		return
	if not random_event_popup or not random_event_popup.can_show_events():
		player_nodes[event_player_index].set_movement_enabled(true)
		return

	random_event_turns[turn_key] = true
	is_random_event_active = true
	player_nodes[event_player_index].set_movement_enabled(false)
	if turn_notice:
		turn_notice.hide()

	var card_count := randi_range(1, 3)
	random_event_popup.show_random_events(card_count)
	var resolved_events: Array = await random_event_popup.events_resolved
	_apply_random_event_effects(resolved_events, event_player_index)

	is_random_event_active = false
	if event_player_index == current_player_index and not is_forcing_sleep:
		player_nodes[event_player_index].set_movement_enabled(true)


func _start_final_exam_turn() -> void:
	if current_round != FINAL_EXAM_ROUND:
		return
	var exam_player_index := current_player_index
	if exam_player_index < 0 or exam_player_index >= Global.player_data.size():
		return

	var player_data: Dictionary = Global.player_data[exam_player_index]
	var existing_result: Dictionary = player_data.get("exam_result", {})
	if bool(existing_result.get("completed", false)):
		pass_turn()
		return

	is_walking = true
	player_nodes[exam_player_index].set_movement_enabled(false)
	var exam_subjects: Array[String] = _get_exam_subjects(player_data)
	var expected_total := exam_subjects.size() * EXAM_QUESTIONS_PER_SUBJECT

	class_time_popup.open_class_info(
		"สอบปลายภาค",
		"%d วิชา • %d ข้อ" % [exam_subjects.size(), expected_total],
		"คะแนนสอบคิดจากจำนวนข้อที่ตอบถูกทั้งหมด",
		"เริ่มสอบ",
		"start_exam",
		false,
		Color("#78301f")
	)
	await class_time_popup.choice_made
	if current_round != FINAL_EXAM_ROUND or current_player_index != exam_player_index:
		return

	var total_correct := 0
	var total_questions := 0
	var subject_results: Array[Dictionary] = []
	for subject_name: String in exam_subjects:
		var subject_level := _get_subject_level(exam_player_index, subject_name)
		learning_popup.start_exam(subject_name, subject_level, EXAM_QUESTIONS_PER_SUBJECT)
		var subject_result: Dictionary = await learning_popup.exam_finished
		var subject_correct := maxi(0, int(subject_result.get("correct", 0)))
		var subject_total := maxi(0, int(subject_result.get("total", EXAM_QUESTIONS_PER_SUBJECT)))
		total_correct += subject_correct
		total_questions += subject_total
		subject_results.append({
			"subject": subject_name,
			"correct": subject_correct,
			"total": subject_total
		})

	var exam_score := clampi(
		roundi(float(total_correct) / float(maxi(1, total_questions)) * 1000.0),
		0,
		1000
	)
	player_data["exam_result"] = {
		"completed": true,
		"correct": total_correct,
		"total": total_questions,
		"score": exam_score,
		"subjects": subject_results
	}

	class_time_popup.open_class_info(
		"สอบเสร็จแล้ว",
		"ตอบถูก %d / %d ข้อ" % [total_correct, total_questions],
		"คะแนนสอบรวม %d / 1000" % exam_score,
		"ดูผลสรุป",
		"finish_exam",
		false,
		Color("#246b3d")
	)
	await class_time_popup.choice_made

	is_walking = false
	pass_turn()


func _get_exam_subjects(player_data: Dictionary) -> Array[String]:
	var subjects: Array[String] = []
	var timetable: Dictionary = player_data.get("timetable", {})
	var selected_subjects: Array = timetable.get("selected_subjects", [])
	for subject_value in selected_subjects:
		var subject_name := str(subject_value)
		if not subject_name.is_empty() and not subjects.has(subject_name):
			subjects.append(subject_name)

	if subjects.size() < 4:
		var daily_subjects: Dictionary = timetable.get("daily_subjects", {})
		for day_key: String in Global.TIMETABLE_DAY_KEYS:
			for class_entry in daily_subjects.get(day_key, []):
				var subject_name := str(class_entry.get("subject", ""))
				if not subject_name.is_empty() and not subjects.has(subject_name):
					subjects.append(subject_name)
					if subjects.size() >= 4:
						break
			if subjects.size() >= 4:
				break

	if subjects.size() < 4:
		for fallback_subject: String in Global.SUBJECT_POOL:
			if not subjects.has(fallback_subject):
				subjects.append(fallback_subject)
			if subjects.size() >= 4:
				break

	if subjects.size() > 4:
		subjects.resize(4)
	return subjects


func pass_turn() -> void:
	if is_turn_transitioning:
		return
	is_turn_transitioning = true
	var previous_player = current_player_index
	if current_round < FINAL_EXAM_ROUND:
		_mark_remaining_classes_missed(previous_player, current_round)
	current_player_index += 1
	
	if current_player_index >= player_nodes.size():
		current_player_index = 0
		current_round += 1
		print("--- จบรอบของทุกคน! เริ่มรอบที่ ", current_round, " ---")
		
		if current_round > max_rounds:
			print("จบเกม!!!")
			get_tree().paused = true
			_show_endgame()
			return
			
		if current_round < FINAL_EXAM_ROUND:
			_reset_daily_missions(current_round)
		_reset_daily_time_speeds()
		for i in range(player_minutes.size()):
			player_minutes[i] = LATE_WAKE_MINUTES if late_wake_players[i] else NORMAL_WAKE_MINUTES
			late_wake_players[i] = false
		_show_turn_notice("รอบใหม่เริ่มแล้ว\nผู้เล่นที่ 1 ถึงตาคุณ")
	else:
		_show_turn_notice("ผู้เล่นที่ %d จบเทิร์น\nผู้เล่นที่ %d ถึงตาคุณ" % [previous_player + 1, current_player_index + 1])

	print("--- เปลี่ยนเทิร์น! ตาของผู้เล่นคนที่ ", current_player_index + 1, " ---")
	_capture_completed_turn_checkpoint()
	setup_current_turn()
	is_turn_transitioning = false


func _capture_completed_turn_checkpoint() -> void:
	SaveManager.set_checkpoint(_build_checkpoint_state())
	if SaveManager.active_slot >= 1 and not SaveManager.autosave_checkpoint():
		push_warning("บันทึกอัตโนมัติไม่สำเร็จ: " + SaveManager.last_error)


func _build_checkpoint_state() -> Dictionary:
	return {
		"global": Global.export_save_data(),
		"map": {
			"current_player_index": current_player_index,
			"current_round": current_round,
			"max_rounds": max_rounds,
			"player_minutes": player_minutes.duplicate(),
			"player_time_speed_multipliers": player_time_speed_multipliers.duplicate(),
			"late_wake_players": late_wake_players.duplicate(),
			"random_event_turns": random_event_turns.duplicate(true),
			"scenario_attempt_turns": scenario_attempt_turns.duplicate(true),
			"occurred_scenarios": occurred_scenarios.duplicate(true),
			"scenario_failed_attempts": scenario_failed_attempts
		}
	}


func _apply_map_save_data(data: Dictionary) -> void:
	max_rounds = maxi(1, int(data.get("max_rounds", max_rounds)))
	current_round = clampi(int(data.get("current_round", 1)), 1, max_rounds)
	current_player_index = clampi(
		int(data.get("current_player_index", 0)),
		0,
		maxi(0, player_nodes.size() - 1)
	)

	_copy_int_array(data.get("player_minutes", []), player_minutes, NORMAL_WAKE_MINUTES)
	_copy_float_array(data.get("player_time_speed_multipliers", []), player_time_speed_multipliers, 1.0)
	_copy_bool_array(data.get("late_wake_players", []), late_wake_players, false)

	random_event_turns = _copy_dictionary(data.get("random_event_turns", {}))
	scenario_attempt_turns = _copy_dictionary(data.get("scenario_attempt_turns", {}))
	occurred_scenarios = _copy_dictionary(data.get("occurred_scenarios", {}))
	scenario_failed_attempts = maxi(0, int(data.get("scenario_failed_attempts", 0)))


func _copy_int_array(source_value, target: Array[int], fallback: int) -> void:
	var source: Array = source_value if source_value is Array else []
	for index in range(target.size()):
		target[index] = int(source[index]) if index < source.size() else fallback


func _copy_float_array(source_value, target: Array[float], fallback: float) -> void:
	var source: Array = source_value if source_value is Array else []
	for index in range(target.size()):
		target[index] = float(source[index]) if index < source.size() else fallback


func _copy_bool_array(source_value, target: Array[bool], fallback: bool) -> void:
	var source: Array = source_value if source_value is Array else []
	for index in range(target.size()):
		target[index] = bool(source[index]) if index < source.size() else fallback


func _copy_dictionary(source_value) -> Dictionary:
	return source_value.duplicate(true) if source_value is Dictionary else {}

func _setup_turn_notice() -> void:
	turn_notice = Label.new()
	turn_notice.visible = false
	turn_notice.z_index = 200
	turn_notice.position = Vector2(440, 80)
	turn_notice.size = Vector2(400, 70)
	turn_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_notice.add_theme_font_size_override("font_size", 24)
	turn_notice.add_theme_color_override("font_color", Color("#4b1d13"))
	turn_notice.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.87, 1.0))
	turn_notice.add_theme_constant_override("outline_size", 2)
	var notice_style = StyleBoxFlat.new()
	notice_style.bg_color = Color("#f7e8cd")
	notice_style.border_color = Color("#78301f")
	notice_style.set_border_width_all(2)
	notice_style.set_corner_radius_all(8)
	turn_notice.add_theme_stylebox_override("normal", notice_style)
	$UILayer.add_child(turn_notice)

func _show_turn_notice(message: String) -> void:
	if not turn_notice:
		return
	turn_notice.text = message
	turn_notice.modulate = Color.WHITE
	turn_notice.show()
	var tween = create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(turn_notice, "modulate:a", 0.0, 0.35)
	tween.tween_callback(turn_notice.hide)

func _advance_time(minutes: int) -> void:
	current_minutes = min(current_minutes + minutes, SLEEP_MINUTES)
	player_minutes[current_player_index] = current_minutes
	_update_night_lighting()
	if player_panel:
		player_panel.update_time_ui(current_minutes, NORMAL_WAKE_MINUTES, SLEEP_MINUTES, _get_current_time_speed())

	if current_minutes >= SLEEP_MINUTES:
		_force_sleep()


func _get_current_time_speed() -> float:
	if current_player_index < 0 or current_player_index >= player_time_speed_multipliers.size():
		return 1.0
	return maxf(1.0, player_time_speed_multipliers[current_player_index])


func _reset_daily_time_speeds() -> void:
	for player_index in range(player_time_speed_multipliers.size()):
		player_time_speed_multipliers[player_index] = 1.0

func _update_night_lighting() -> void:
	if not night_lighting:
		return

	if current_minutes <= NIGHT_START_MINUTES:
		night_lighting.color = Color.WHITE
		return

	var darkness = clampf(
		float(current_minutes - NIGHT_START_MINUTES) / float(NIGHT_FULL_MINUTES - NIGHT_START_MINUTES),
		0.0,
		1.0
	)
	night_lighting.color = Color.WHITE.lerp(NIGHT_COLOR, darkness)

func _force_sleep() -> void:
	if is_forcing_sleep:
		return

	is_forcing_sleep = true
	is_walking = true
	var active_player = player_nodes[current_player_index]
	active_player.set_movement_enabled(false)
	var stats = Global.player_data[current_player_index]["stats"]
	stats["stamina"] = clamp(stats.get("stamina", 0) + 30, 0, 100)
	if player_panel:
		player_panel.setup_players_ui()

	active_player.global_position = dorm_marker.global_position
	camera.global_position = dorm_marker.global_position
	late_wake_players[current_player_index] = true
	await get_tree().create_timer(0.4).timeout

	is_walking = false
	is_forcing_sleep = false
	pass_turn()
	forced_sleep_finished.emit()

func _on_player_activity_requested(target_place: Node2D) -> void:
	if is_walking or target_place == null:
		return

	is_walking = true
	player_nodes[current_player_index].set_movement_enabled(false)
	var scenario_turn_key := "%d:%d" % [current_round, current_player_index]
	var can_attempt_scenario := not scenario_attempt_turns.has(scenario_turn_key)
	if can_attempt_scenario:
		# ผู้เล่นแต่ละคนทอย Scenario ได้เพียงหนึ่งครั้งต่อรอบ ป้องกันการกด E รัว
		scenario_attempt_turns[scenario_turn_key] = true

	if can_attempt_scenario:
		var trigger_chance := _get_scenario_trigger_chance()
		var has_event := false
		if randf() <= trigger_chance and scenario_popup:
			has_event = scenario_popup.try_start_scenario(target_place.name, occurred_scenarios)

		if has_event:
			scenario_failed_attempts = 0
			var scenario_key: String = scenario_popup.get_current_scenario_key()
			if not scenario_key.is_empty():
				# แต่ละ Scenario เกิดได้เพียงครั้งเดียวต่อเกม แต่ Scenario อื่นยังเกิดได้
				occurred_scenarios[scenario_key] = true
			var effects = await scenario_popup.scenario_resolved
			_apply_scenario_effects(effects)
		else:
			scenario_failed_attempts += 1

	await _handle_activity_popup(target_place)
	player_nodes[current_player_index].set_movement_enabled(true)
	is_walking = false


func _get_scenario_trigger_chance() -> float:
	return minf(
		SCENARIO_BASE_CHANCE + SCENARIO_CHANCE_STEP * scenario_failed_attempts,
		SCENARIO_MAX_CHANCE
	)

# ==========================================
# ระบบกิจกรรม และ Popup (แยกระหว่างเรียนกับกิจกรรมปกติ)
# ==========================================
func _handle_activity_popup(target_place: Node2D) -> void:
	# 1. เช็คว่าเป็นสถานที่ "Learn" หรือไม่ ถ้าใช่ให้ข้ามไปเปิดหน้าเรียนเลย
	if target_place.name == "Learn":
		await _handle_direct_learning()
		return
		
	# 2. กรณีเป็นสถานที่อื่นๆ ให้เปิดหน้าต่างกิจกรรมตามปกติ
	var popup = $UILayer/ActivityPopup
	if not popup: return
		
	var place_effects = activity_effects.get(target_place.name, {}).duplicate()
	popup.open_popup(target_place.name, current_player_index, place_effects)
	var chosen_action = await popup.activity_chosen 
	
	if chosen_action != "ยกเลิก (ไม่ทำกิจกรรม)":
		if chosen_action == "จบเทิร์น":
			pass_turn()
			return
		if not _can_afford_activity(chosen_action, target_place.name):
			_show_turn_notice("เงินไม่พอ\nไม่เสียเงินและเวลา")
			return

		var is_fainted = false
		var activity_minutes = _get_activity_time_cost(chosen_action, target_place.name)
		var ends_turn_by_sleep: bool = (
			target_place.name == "Dorm"
			and chosen_action == "นอนพัก"
			and current_minutes + activity_minutes >= SLEEP_MINUTES
		)
		
		# >>> ตรวจสอบว่ากิจกรรมที่กด คือ "เรียน" หรือ "กิจกรรมปกติ" <<<
		if chosen_action.begins_with("เรียน ") and learning_popup:
			var subject_name = chosen_action.replace("เรียน ", "")
			var subject_level = _get_subject_level(current_player_index, subject_name)
			
			# เปิดหน้าควิซตาม Level ปัจจุบัน รอผลคะแนน และคำนวณสเตตัส
			learning_popup.start_quiz(subject_name, subject_level)
			var study_gained = await learning_popup.quiz_finished
			_advance_subject_level(current_player_index, subject_name)
			is_fainted = _apply_learning_effects(study_gained)
			_mark_mission_completed(chosen_action)
			
		else:
			# หากเป็นกิจกรรมปกติ (หอพัก, โรงอาหาร ฯลฯ) ให้ทำงานตามปกติ
			is_fainted = apply_activity_effects(chosen_action, target_place.name)
			_complete_event_missions(target_place.name, chosen_action)

		if not is_fainted:
			if ends_turn_by_sleep:
				_finish_turn_by_sleep()
				return
			_advance_time(activity_minutes)
			if is_forcing_sleep:
				await forced_sleep_finished
		
		# --- จัดการการสลบ (จอจะมืดแล้วเด้งไปหอพัก) ---
		if is_fainted:
			var active_player = player_nodes[current_player_index]
			
			if fade_rect:
				fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
				var fade_in = create_tween()
				fade_in.tween_property(fade_rect, "color:a", 1.0, 0.5)
				await fade_in.finished
				
				active_player.global_position = dorm_marker.global_position
				camera.global_position = dorm_marker.global_position
				
				await get_tree().create_timer(1.0).timeout 
				
				var fade_out = create_tween()
				fade_out.tween_property(fade_rect, "color:a", 0.0, 0.5)
				await fade_out.finished
				fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				active_player.global_position = dorm_marker.global_position
				camera.global_position = dorm_marker.global_position
			
		if is_fainted:
			player_minutes[current_player_index] = current_minutes
			_force_sleep()
			await forced_sleep_finished

# ------------------------------------------
# ระบบเปิดหน้าควิซเรียนแบบตรงๆ (Direct Learning)
# ------------------------------------------
func _handle_direct_learning() -> void:
	var p_data: Dictionary = Global.player_data[current_player_index]

	if not p_data.has("timetable") or not p_data["timetable"].has("daily_subjects"):
		await _show_class_time_message("ไม่มีตารางเรียน", "", "ไม่พบข้อมูลตารางเรียนของผู้เล่น")
		return

	var day_key := "R" + str(((current_round - 1) % 5) + 1)
	var classes: Array = p_data["timetable"]["daily_subjects"].get(day_key, [])
	if classes.is_empty():
		await _show_class_time_message("ไม่มีคาบเรียน", "", "วันนี้ไม่มีคาบเรียน")
		return

	_refresh_missed_classes(classes)
	var selected_class: Dictionary = {}
	for class_entry in classes:
		if class_entry.get("is_completed", false):
			continue
		if class_entry.get("attendance_status", "pending") == "missed":
			continue
		selected_class = class_entry
		break

	if selected_class.is_empty():
		var all_completed := true
		var missed_class: Dictionary = {}
		for class_entry in classes:
			if not class_entry.get("is_completed", false):
				all_completed = false
				if missed_class.is_empty() and class_entry.get("attendance_status", "pending") == "missed":
					missed_class = class_entry
		if all_completed:
			await _show_class_time_message("ตารางวันนี้", "", "เรียนครบทุกวิชาแล้วสำหรับวันนี้")
		elif not missed_class.is_empty():
			await _show_class_time_message(
				missed_class.get("subject", "คาบเรียน"),
				missed_class.get("time_label", ""),
				"เลยเวลาเรียนแล้ว\nไม่สามารถเข้าเรียนคาบนี้ได้"
			)
		else:
			await _show_class_time_message("ตารางวันนี้", "", "ไม่มีคาบที่สามารถเข้าเรียนได้แล้ววันนี้")
		return

	var subject_name: String = selected_class.get("subject", "")
	var class_time: String = selected_class.get("time_label", "")
	var start_minutes: int = int(selected_class.get("start_minutes", 0))
	var minutes_until_start := start_minutes - current_minutes
	var timing_state := _get_class_timing_state(start_minutes, current_minutes)

	if timing_state == "too_early":
		await _show_class_time_message(
			subject_name,
			class_time,
			"ยังไม่ถึงเวลาเรียน\nเริ่มอีก %d นาที" % minutes_until_start
		)
		return

	var reward_multiplier := 1.0
	var result_note := ""
	var choice := ""
	if timing_state == "wait":
		class_time_popup.open_class_info(
			subject_name,
			class_time,
			"เริ่มเรียนในอีก %d นาที" % minutes_until_start,
			"รอเข้าเรียน",
			"wait",
			true,
			Color("#8a5a00")
		)
		choice = await class_time_popup.choice_made
		if choice != "wait":
			return
		_advance_time(minutes_until_start)
	else:
		var late_minutes := current_minutes - start_minutes
		if timing_state == "on_time":
			var status_text := "ตรงเวลา" if late_minutes <= 0 else "ยังอยู่ในช่วงผ่อนผัน %d นาที" % late_minutes
			class_time_popup.open_class_info(
				subject_name, class_time, status_text, "เข้าเรียน", "attend", true, Color("#246b3d")
			)
		elif timing_state == "late":
			reward_multiplier = CLASS_LATE_STUDY_MULTIPLIER
			result_note = "เข้าสาย: ความรู้ลดลง 25%"
			class_time_popup.open_class_info(
				subject_name,
				class_time,
				"สาย %d นาที — ความรู้ลดลง 25%%" % late_minutes,
				"เข้าเรียน",
				"attend",
				true,
				Color("#a33f23")
			)
		choice = await class_time_popup.choice_made
		if choice != "attend":
			return

	await _start_scheduled_class(selected_class, reward_multiplier, result_note)


func _start_scheduled_class(class_entry: Dictionary, reward_multiplier: float, result_note: String) -> void:
	if not learning_popup:
		return
	var subject_name: String = class_entry.get("subject", "")
	var subject_level := _get_subject_level(current_player_index, subject_name)
	learning_popup.start_quiz(subject_name, subject_level, reward_multiplier, result_note)
	var study_gained: int = await learning_popup.quiz_finished
	_advance_subject_level(current_player_index, subject_name)
	var is_fainted := _apply_learning_effects(study_gained)

	class_entry["is_completed"] = true
	class_entry["attendance_status"] = "attended"
	class_entry["late_minutes"] = maxi(0, current_minutes - int(class_entry.get("start_minutes", current_minutes)))
	render_mission_text(current_player_index, current_round)

	if not is_fainted:
		var end_minutes: int = int(class_entry.get("end_minutes", current_minutes))
		_advance_time(maxi(0, end_minutes - current_minutes))
		if is_forcing_sleep:
			await forced_sleep_finished
	else:
		_force_sleep()
		await forced_sleep_finished


func _refresh_missed_classes(classes: Array) -> void:
	var changed := false
	for class_entry in classes:
		if class_entry.get("is_completed", false):
			continue
		if class_entry.get("attendance_status", "pending") == "missed":
			continue
		var start_minutes: int = int(class_entry.get("start_minutes", 0))
		if _get_class_timing_state(start_minutes, current_minutes) == "missed":
			class_entry["attendance_status"] = "missed"
			changed = true
	if changed:
		render_mission_text(current_player_index, current_round)


func _get_class_timing_state(start_minutes: int, now_minutes: int) -> String:
	var difference := now_minutes - start_minutes
	if difference < -CLASS_EARLY_WAIT_MINUTES:
		return "too_early"
	if difference < 0:
		return "wait"
	if difference <= CLASS_ON_TIME_GRACE_MINUTES:
		return "on_time"
	if difference <= CLASS_LATE_LIMIT_MINUTES:
		return "late"
	return "missed"


func _show_class_time_message(subject_name: String, class_time: String, message: String) -> void:
	class_time_popup.open_class_info(
		subject_name,
		class_time,
		message,
		"ตกลง",
		"close",
		false,
		Color("#78301f")
	)
	await class_time_popup.choice_made

# ------------------------------------------
# ระบบ Level รายวิชา
# ------------------------------------------
func _get_subject_level(player_index: int, subject_name: String) -> int:
	if player_index < 0 or player_index >= Global.player_data.size():
		return 1

	if not Global.player_data[player_index].has("subject_progress"):
		Global.player_data[player_index]["subject_progress"] = {}

	var progress: Dictionary = Global.player_data[player_index]["subject_progress"]
	if not progress.has(subject_name):
		progress[subject_name] = 1

	var level := clampi(int(progress.get(subject_name, 1)), 1, 6)
	print("📖 LOAD LEVEL | P", player_index + 1, " | ", subject_name, " = ", level)
	return level


func _advance_subject_level(player_index: int, subject_name: String) -> void:
	if player_index < 0 or player_index >= Global.player_data.size():
		return

	if not Global.player_data[player_index].has("subject_progress"):
		Global.player_data[player_index]["subject_progress"] = {}

	var progress: Dictionary = Global.player_data[player_index]["subject_progress"]
	var current_level := clampi(int(progress.get(subject_name, 1)), 1, 6)
	var next_level := mini(current_level + 1, 6)
	progress[subject_name] = next_level
	Global.player_data[player_index]["subject_progress"] = progress

	print("📚 SAVE LEVEL | P", player_index + 1, " | ", subject_name, " : ", current_level, " -> ", next_level)
	print("📚 SUBJECT PROGRESS = ", Global.player_data[player_index]["subject_progress"])


func _get_activity_time_cost(action_name: String, place_name: String) -> int:
	if action_name.begins_with("เรียน "):
		return 120
	return activity_time_costs.get(place_name, {}).get(action_name, 60)


func _can_afford_activity(action_name: String, place_name: String) -> bool:
	var effects: Dictionary = activity_effects.get(place_name, {}).get(action_name, {})
	var money_change := int(effects.get("money", 0))
	if money_change >= 0:
		return true
	var current_money := int(Global.player_data[current_player_index].get("money", 0))
	return current_money >= -money_change


func _finish_turn_by_sleep() -> void:
	# การเลือกนอนเมื่อเวลานอนพาไปถึงเวลาปิดวัน ถือเป็นการจบเทิร์นโดยสมัครใจ
	# จึงตื่น 06:00 ตามปกติ ไม่รับโทษตื่นสายแบบการถูกบังคับให้นอน
	current_minutes = SLEEP_MINUTES
	player_minutes[current_player_index] = current_minutes
	late_wake_players[current_player_index] = false
	pass_turn()
		
func _apply_learning_effects(study_gained: int) -> bool:
	var p_data = Global.player_data[current_player_index]
	var is_fainted = false 
	var stats = p_data["stats"]
	
	stats["study"] = clamp(stats.get("study", 0) + study_gained, 0, 400)
	print("ระบบทำงาน! บวกความรู้เพิ่ม: ", study_gained, " | ตอนนี้รวมเป็น: ", stats["study"])
	stats["stamina"] = clamp(stats.get("stamina", 0) - 15, 0, 200)
	stats["hunger"] = clamp(stats.get("hunger", 0) - 10, 0, 200)
	stats["happiness"] = clamp(stats.get("happiness", 0) - 10, 0, 200)
	
	if stats["stamina"] <= 0 or stats["hunger"] <= 0:
		is_fainted = true
		stats["stamina"] = max(20, stats["stamina"]) 
		stats["hunger"] = max(20, stats["hunger"])
		
	if player_panel: player_panel.setup_players_ui()
	return is_fainted

func apply_activity_effects(action_name: String, place_name: String) -> bool:
	var p_data = Global.player_data[current_player_index]
	var effects = {}
	var is_fainted = false 
	
	if activity_effects.has(place_name) and activity_effects[place_name].has(action_name):
		effects = activity_effects[place_name][action_name]
		
	for key in effects:
		var change_val = effects[key]
		if key == "money":
			p_data["money"] = max(0, p_data.get("money", 0) + change_val)
		else:
			var current_stat = p_data["stats"].get(key, 0)
			
			var max_limit = 400 if key == "study" else 200
			var new_stat = clamp(current_stat + change_val, 0, max_limit)
			p_data["stats"][key] = new_stat
			
			if (key == "hunger" or key == "stamina") and new_stat <= 0:
				is_fainted = true
				p_data["stats"][key] = 20
			
	if player_panel: player_panel.setup_players_ui()
	return is_fainted


func _apply_random_event_effects(events: Array, player_index: int) -> void:
	if player_index < 0 or player_index >= Global.player_data.size():
		return

	var p_data: Dictionary = Global.player_data[player_index]
	var stats_data: Dictionary = p_data.get("stats", {})
	var total_time_speed_bonus := 0.0

	for event_data in events:
		if not event_data is Dictionary:
			continue
		var effects: Dictionary = event_data.get("effects", {})
		var applied_effects := {}

		var stat_effects: Dictionary = effects.get("stats", {})
		for stat_name: String in stat_effects:
			var max_value := 400 if stat_name == "study" else 200
			var delta := int(stat_effects[stat_name])
			stats_data[stat_name] = clampi(int(stats_data.get(stat_name, 0)) + delta, 0, max_value)
			applied_effects[stat_name] = delta

		var money_range: Array = effects.get("money_range", [])
		if money_range.size() >= 2:
			var money_delta := randi_range(int(money_range[0]), int(money_range[1]))
			p_data["money"] = maxi(0, int(p_data.get("money", 0)) + money_delta)
			applied_effects["money"] = money_delta

		var time_speed_bonus := maxf(0.0, float(effects.get("time_speed_bonus", 0.0)))
		total_time_speed_bonus += time_speed_bonus
		if time_speed_bonus > 0.0:
			applied_effects["time_speed_bonus"] = time_speed_bonus

		var mission: Dictionary = effects.get("mission", {})
		if not mission.is_empty():
			_add_event_mission(p_data, mission)
			applied_effects["mission"] = mission.get("id", "")

		p_data["event_history"].append({
			"event_id": event_data.get("id", ""),
			"round": current_round,
			"effects": applied_effects,
		})

	p_data["stats"] = stats_data
	if total_time_speed_bonus > 0.0 and player_index < player_time_speed_multipliers.size():
		player_time_speed_multipliers[player_index] += total_time_speed_bonus
	if player_panel:
		player_panel.setup_players_ui()
		if player_index == current_player_index:
			player_panel.update_time_ui(current_minutes, NORMAL_WAKE_MINUTES, SLEEP_MINUTES, _get_current_time_speed())
	render_mission_text(player_index, current_round)


func _add_event_mission(p_data: Dictionary, mission_data: Dictionary) -> void:
	var missions: Array = p_data.get("event_missions", [])
	var mission_id: String = mission_data.get("id", "event_mission")
	for existing in missions:
		if existing.get("id", "") == mission_id and not existing.get("is_completed", false):
			return

	var new_mission := mission_data.duplicate(true)
	new_mission["is_completed"] = false
	new_mission["created_round"] = current_round
	new_mission["completed_round"] = 0
	missions.append(new_mission)
	p_data["event_missions"] = missions


func _complete_event_missions(place_name: String, action_name: String) -> void:
	var p_data: Dictionary = Global.player_data[current_player_index]
	var missions: Array = p_data.get("event_missions", [])
	var changed := false

	for mission in missions:
		if mission.get("is_completed", false):
			continue
		var valid_places: Array = mission.get("places", [])
		var valid_actions: Array = mission.get("actions", [])
		if (valid_places.is_empty() or place_name in valid_places) and (valid_actions.is_empty() or action_name in valid_actions):
			mission["is_completed"] = true
			mission["completed_round"] = current_round
			changed = true

	if changed:
		p_data["event_missions"] = missions
		render_mission_text(current_player_index, current_round)

# ==========================================
# ระบบภารกิจ (Missions)
# ==========================================
func render_mission_text(player_index: int, round_num: int) -> void:
	if player_index < 0 or player_index >= Global.player_data.size():
		return
	var p_data: Dictionary = Global.player_data[player_index]
	var display_lines: Array[String] = []

	if p_data.has("timetable"):
		var day_key := "R" + str(((round_num - 1) % 5) + 1)
		var study_missions: Array = p_data["timetable"].get("daily_subjects", {}).get(day_key, [])
		for mission in study_missions:
			var subject := str(mission.get("subject", ""))
			var class_time := _get_mission_class_time(mission)
			var mission_label := "%s (เวลา %s)" % [subject, class_time] if not class_time.is_empty() else subject
			if mission.get("is_completed", false):
				display_lines.append("☑ เรียน " + mission_label)
			elif mission.get("attendance_status", "pending") == "missed":
				display_lines.append("✕ พลาด " + mission_label)
			else:
				display_lines.append("☐ เรียน " + mission_label)

	for event_mission in p_data.get("event_missions", []):
		var is_completed: bool = event_mission.get("is_completed", false)
		if is_completed and int(event_mission.get("completed_round", 0)) != round_num:
			continue
		var prefix := "☑" if is_completed else "⚠"
		display_lines.append("%s %s" % [prefix, event_mission.get("text", "ภารกิจเหตุการณ์")])

	var display_text := "\n".join(display_lines)
	if display_text.is_empty():
		display_text = "ไม่มีภารกิจในขณะนี้"

	if player_panel and player_panel.has_method("update_mission"):
		player_panel.update_mission(display_text)

func _get_mission_class_time(mission: Dictionary) -> String:
	var time_label := str(mission.get("time_label", ""))
	if not time_label.is_empty():
		return time_label

	var start_minutes := int(mission.get("start_minutes", -1))
	var end_minutes := int(mission.get("end_minutes", -1))
	if start_minutes < 0 or end_minutes < 0:
		return ""

	return "%s - %s" % [_format_mission_time(start_minutes), _format_mission_time(end_minutes)]

func _format_mission_time(total_minutes: int) -> String:
	var hour := int(total_minutes / 60) % 24
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]

func _mark_mission_completed(action_name: String) -> void:
	var subject_name = action_name.replace("เรียน ", "")
	var day_key = "R" + str(((current_round - 1) % 5) + 1)
	var missions = Global.player_data[current_player_index]["timetable"].get("daily_subjects", {}).get(day_key, [])
	
	for m in missions:
		if m["subject"] == subject_name and not m["is_completed"]:
			m["is_completed"] = true
			m["attendance_status"] = "attended"
			break 
			
	render_mission_text(current_player_index, current_round)

func _reset_daily_missions(new_round: int) -> void:
	var day_key = "R" + str(((new_round - 1) % 5) + 1)
	for p_data in Global.player_data:
		if p_data.has("timetable") and p_data["timetable"].has("daily_subjects"):
			var missions = p_data["timetable"]["daily_subjects"].get(day_key, [])
			for m in missions:
				m["is_completed"] = false
				m["attendance_status"] = "pending"
				m.erase("late_minutes")


func _mark_remaining_classes_missed(player_index: int, round_num: int) -> void:
	if player_index < 0 or player_index >= Global.player_data.size():
		return
	var p_data: Dictionary = Global.player_data[player_index]
	if not p_data.has("timetable"):
		return
	var day_key := "R" + str(((round_num - 1) % 5) + 1)
	var classes: Array = p_data["timetable"].get("daily_subjects", {}).get(day_key, [])
	for class_entry in classes:
		if not class_entry.get("is_completed", false):
			class_entry["attendance_status"] = "missed"

# ==========================================
# การตั้งค่าตัวละครเบื้องต้น
# ==========================================
func play_animation(player_node: CharacterBody2D, anim_name: String) -> void:
	var anim_player = player_node.get_node_or_null("Panel/CenterPoint/AnimationPlayer")
	if anim_player: anim_player.play(anim_name)

func setup_player(player_index: int, player_character: CharacterBody2D) -> void:
	var my_data = Global.player_data[player_index] if Global.player_data.size() > player_index else {}
	if not my_data.has("avatar_settings"): return
	
	var s = my_data["avatar_settings"]
	var cp = player_character.get_node("Panel/CenterPoint")
	
	if s.get("skin_path", "") != "": cp.get_node("BodySprite").texture = load(s["skin_path"])
	if s.get("face_path", "") != "": cp.get_node("EyeSprite").texture = load(s["face_path"])
	if s.get("outfit_path", "") != "": cp.get_node("OutfitSprite").texture = load(s["outfit_path"])
	if s.get("hair_path", "") != "": cp.get_node("HairSprite").texture = load(s["hair_path"])
	if s.get("accessory_path", "") != "": cp.get_node("AccessorySprite").texture = load(s["accessory_path"])
	
func _apply_scenario_effects(effects: Dictionary) -> void:
	var p_data = Global.player_data[current_player_index]
	var stats = p_data["stats"]
	
	for key in effects:
		if key == "money":
			p_data["money"] = max(0, p_data.get("money", 0) + effects[key])
		else:
			var max_limit = 400 if key == "study" else 200
			stats[key] = clamp(stats.get(key, 0) + effects[key], 0, max_limit)
			
	if player_panel: player_panel.setup_players_ui()

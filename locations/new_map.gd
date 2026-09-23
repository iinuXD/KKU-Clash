extends Node2D

signal forced_sleep_finished

@onready var original_player: CharacterBody2D = $Player
@onready var locations_node: Node2D = $location
@onready var waypoints_node: Node2D = $waypiont
@onready var dorm_marker: Marker2D = $waypiont/Dorm 

@onready var camera: Camera2D = $Camera
@onready var player_panel = $UILayer/PlayerPanel
@onready var night_lighting: CanvasModulate = $NightLighting

# >>> 1. อ้างอิงหน้าต่างควิซ (ให้แน่ใจว่าลากมาวางใน UILayer แล้ว) <<<
@onready var learning_popup = $UILayer/learning_popup 
@onready var scenario_popup = $UILayer/ScenarioPopup

var astar: AStar2D
var all_markers: Array[Marker2D] = []

var player_nodes: Array[CharacterBody2D] = [] 
var current_player_index: int = 0     
var is_walking: bool = false
var is_forcing_sleep: bool = false

var current_round: int = 1
var max_rounds: int = 11     

const NORMAL_WAKE_MINUTES := 6 * 60
const LATE_WAKE_MINUTES := 10 * 60
const SLEEP_MINUTES := 27 * 60
const REAL_SECONDS_PER_GAME_MINUTE := 0.1
const NIGHT_START_MINUTES := 18 * 60
const NIGHT_FULL_MINUTES := 24 * 60
const NIGHT_COLOR := Color(0.48, 0.55, 0.78, 1.0)

var player_minutes: Array[int] = []
var late_wake_players: Array[bool] = []
var current_minutes: int = NORMAL_WAKE_MINUTES
var real_time_accumulator: float = 0.0

# เพิ่มตัวแปรสำหรับจอดำตอนสลบ
var fade_rect: ColorRect
var turn_notice: Label

const CUSTOM_LINKS := [
	["Dorm", "Round1"], ["Round1", "Sport"], ["Sport", "Shop"], ["Shop", "Cross1"],
	["Cross1", "Library"], ["Library", "Cross5"], ["Cross1", "Food"], ["Food", "Round2"],
	["Round2", "Cross2"], ["Cross2", "Learn"], ["Learn", "Cross5"], ["Cross5", "Cross6"],
	["Cross6", "Round1"], ["Cross6", "Round3"], ["Round3", "End4"], ["Round3", "Cross4"],
	["Cross3", "Cross4"], ["Cross3", "Hospital"], ["Cross3", "Cross7"], ["Cross8", "Cross4"],
	["Cross8", "Fun"], ["Cross7", "Fun"], ["Cross3", "Cross2"], ["End4", "Park"]
] 

var activity_effects = {
	"Dorm": {
		"นอนพัก": {"stamina": 30},
		"เล่นเกม": {"happiness": 20, "stamina": -5},
		"อ่านหนังสือ": {"study": 10, "stamina": -10, "happiness": -15},
		"จบเทิร์น": {}
	},
	"Food": {
		"กินข้าวจานธรรมดา": {"money": -40, "hunger": 25},
		"กินข้าวจานพิเศษ": {"money": -50, "hunger": 35, "happiness": 5},
		"กินของทานเล่น": {"money": -20, "hunger": 10, "happiness": 15},
		"ทำ Parttime": {"money": 120, "stamina": -25, "hunger": -20}
	},
	"Library": {
		"อ่านหนังสือ": {"study": 15, "stamina": -10, "hunger": -5},
		"ค้นคว้า": {"study": 20, "stamina": -15, "hunger": -10},
		"ยืมหนังสือ": {"money": -20, "study": 5},
		"ทำ Parttime": {"money": 100, "stamina": -10}
	},
	"Shop": {
		"ซื้ออาหารตุน 2 สัปดาห์": {"money": -300, "hunger": 40, "happiness": 10},
		"ซื้ออาหารตุน 3 สัปดาห์": {"money": -450, "hunger": 70, "happiness": 20},
		"ทำ Parttime": {"money": 130, "stamina": -15, "happiness": -5}
	},
	"Hospital": {
		"เข้ารับการรักษา": {"money": -500, "stamina": 50, "happiness": 20},
		"ซื้อยา": {"money": -150, "stamina": 25},
		"ตรวจสุขภาพ": {"money": -250, "stamina": 15, "happiness": 15}
	},
	"Park": {
		"เดินเล่น": {"happiness": 20, "stamina": -5},
		"ซื้อของกิน": {"money": -40, "hunger": 15, "happiness": 15},
		"ขายของ": {"money": 150, "stamina": -20, "hunger": -10}
	},
	"Sport": {
		"วิ่ง": {"happiness": 15, "stamina": -15},
		"เล่นกีฬา": {"happiness": 25, "stamina": -25},
		"ทำกิจกรรม": {"happiness": 15, "study": 5, "stamina": -20}
	},
	"Fun": {
		"ดูหนัง": {"money": -120, "happiness": 30},
		"ปาร์ตี้": {"money": -300, "happiness": 50, "stamina": -20, "study": -10},
		"ทำ Parttime": {"money": 200, "stamina": -25, "hunger": -15}
	}
} 

var activity_time_costs = {
	"Dorm": {"นอนพัก": 8, "เล่นเกม": 2, "อ่านหนังสือ": 2, "จบเทิร์น": 0},
	"Food": {"กินข้าวจานธรรมดา": 1, "กินข้าวจานพิเศษ": 1, "กินของทานเล่น": 1, "ทำ Parttime": 4},
	"Library": {"อ่านหนังสือ": 2, "ค้นคว้า": 3, "ยืมหนังสือ": 1, "ทำ Parttime": 4},
	"Shop": {"ซื้ออาหารตุน 2 สัปดาห์": 2, "ซื้ออาหารตุน 3 สัปดาห์": 2, "ทำ Parttime": 4},
	"Hospital": {"เข้ารับการรักษา": 3, "ซื้อยา": 1, "ตรวจสุขภาพ": 2},
	"Park": {"เดินเล่น": 2, "ซื้อของกิน": 1, "ขายของ": 3},
	"Sport": {"วิ่ง": 2, "เล่นกีฬา": 3, "ทำกิจกรรม": 2},
	"Fun": {"ดูหนัง": 3, "ปาร์ตี้": 4, "ทำ Parttime": 4}
}

func _process(delta: float) -> void:
	if is_walking or is_forcing_sleep:
		return

	var activity_popup = $UILayer/ActivityPopup
	if activity_popup.visible or learning_popup.visible or scenario_popup.visible:
		return

	real_time_accumulator += delta
	var minutes_to_advance = int(real_time_accumulator / REAL_SECONDS_PER_GAME_MINUTE)
	if minutes_to_advance <= 0:
		return

	real_time_accumulator -= minutes_to_advance * REAL_SECONDS_PER_GAME_MINUTE
	_advance_time(minutes_to_advance)

# ==========================================
# ส่วนเริ่มต้นเกม
# ==========================================
func _ready() -> void:
	_setup_mock_data()
	_setup_fade() # เรียกใช้ระบบจอดำตอนสลบ
	_update_night_lighting()
	_setup_turn_notice()
	
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
		late_wake_players.append(false)
			
	setup_current_turn()

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

# ==========================================
# ระบบเทิร์น (Turn Management)
# ==========================================
func setup_current_turn() -> void:
	current_minutes = player_minutes[current_player_index]
	real_time_accumulator = 0.0
	var active_player = player_nodes[current_player_index]
	
	for i in range(player_nodes.size()):
		if i == current_player_index:
			player_nodes[i].show()
			player_nodes[i].global_position = dorm_marker.global_position
			player_nodes[i].set_movement_enabled(true)
		else:
			player_nodes[i].hide()  
			player_nodes[i].set_movement_enabled(false)

	if player_panel:
		player_panel.update_turn_ui(current_player_index)
		player_panel.update_time_ui(current_minutes, NORMAL_WAKE_MINUTES, SLEEP_MINUTES)
		player_panel.update_round_ui(current_round, max_rounds)

	var tween = create_tween()
	tween.tween_property(camera, "global_position", active_player.global_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	render_mission_text(current_player_index, current_round)

func pass_turn() -> void:
	var previous_player = current_player_index
	current_player_index += 1
	
	if current_player_index >= player_nodes.size():
		current_player_index = 0
		current_round += 1
		print("--- จบรอบของทุกคน! เริ่มรอบที่ ", current_round, " ---")
		
		if current_round > max_rounds:
			print("จบเกม!!!")
			return
			
		_reset_daily_missions(current_round)
		for i in range(player_minutes.size()):
			player_minutes[i] = LATE_WAKE_MINUTES if late_wake_players[i] else NORMAL_WAKE_MINUTES
			late_wake_players[i] = false
		_show_turn_notice("รอบใหม่เริ่มแล้ว\nผู้เล่นที่ 1 ถึงตาคุณ")
	else:
		_show_turn_notice("ผู้เล่นที่ %d จบเทิร์น\nผู้เล่นที่ %d ถึงตาคุณ" % [previous_player + 1, current_player_index + 1])

	print("--- เปลี่ยนเทิร์น! ตาของผู้เล่นคนที่ ", current_player_index + 1, " ---")
	setup_current_turn()

func _setup_turn_notice() -> void:
	turn_notice = Label.new()
	turn_notice.visible = false
	turn_notice.z_index = 200
	turn_notice.position = Vector2(440, 80)
	turn_notice.size = Vector2(400, 70)
	turn_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_notice.add_theme_font_size_override("font_size", 20)
	turn_notice.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
	turn_notice.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	turn_notice.add_theme_constant_override("outline_size", 5)
	var notice_style = StyleBoxFlat.new()
	notice_style.bg_color = Color(0.06, 0.08, 0.14, 0.94)
	notice_style.border_color = Color(1.0, 0.72, 0.28, 0.95)
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
		player_panel.update_time_ui(current_minutes, NORMAL_WAKE_MINUTES, SLEEP_MINUTES)

	if current_minutes >= SLEEP_MINUTES:
		_force_sleep()

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

# ==========================================
# ระบบ A* (การเดิน)
# ==========================================
func setup_astar() -> void:
	astar = AStar2D.new()
	all_markers.clear()
	var marker_id_by_name: Dictionary = {}
	
	if waypoints_node:
		for w in waypoints_node.get_children():
			if w is Marker2D: all_markers.append(w)
			
	for i in range(all_markers.size()):
		astar.add_point(i, all_markers[i].global_position)
		marker_id_by_name[all_markers[i].name] = i

	for link in CUSTOM_LINKS:
		if link.size() < 2: continue
		var from_id = marker_id_by_name.get(str(link[0]), -1)
		var to_id = marker_id_by_name.get(str(link[1]), -1)
		
		if from_id != -1 and to_id != -1 and not astar.are_points_connected(from_id, to_id):
			astar.connect_points(from_id, to_id, true)

func _on_place_clicked(viewport: Node, event: InputEvent, shape_idx: int, clicked_place: Node2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_walking:
			walk_to_place(clicked_place)

func _on_player_activity_requested(target_place: Node2D) -> void:
	if is_walking or target_place == null:
		return

	is_walking = true
	player_nodes[current_player_index].set_movement_enabled(false)
	var trigger_chance = 0.20
	if randf() <= trigger_chance and scenario_popup:
		var has_event = scenario_popup.try_start_scenario(target_place.name)
		if has_event:
			var effects = await scenario_popup.scenario_resolved
			_apply_scenario_effects(effects)

	await _handle_activity_popup(target_place)
	player_nodes[current_player_index].set_movement_enabled(true)
	is_walking = false

func walk_to_place(target_place: Node2D) -> void:
	var target_marker = target_place.get_node_or_null("Marker2D")
	if target_marker == null:
		target_marker = waypoints_node.get_node_or_null(NodePath(str(target_place.name)))
		
	if target_marker == null: return
	
	var active_player = player_nodes[current_player_index]
	var path = astar.get_point_path(astar.get_closest_point(active_player.global_position), astar.get_closest_point(target_marker.global_position))
	if path.is_empty(): return
		
	is_walking = true 
	var walk_speed = 300.0 
	var tween = create_tween()
	var current = active_player.global_position
	
	for pt in path:
		var diff_x = pt.x - current.x
		var diff_y = pt.y - current.y
		var dist_x = abs(diff_x)
		var dist_y = abs(diff_y)
		
		if dist_x > dist_y:
			if dist_x > 0: 
				tween.tween_callback(play_animation.bind(active_player, "walk_right" if diff_x > 0 else "walk_left"))
				tween.tween_property(active_player, "global_position:x", pt.x, dist_x / walk_speed)
			if dist_y > 0: 
				tween.tween_callback(play_animation.bind(active_player, "walk_down" if diff_y > 0 else "walk_up"))
				tween.tween_property(active_player, "global_position:y", pt.y, dist_y / walk_speed)
		else:
			if dist_y > 0: 
				tween.tween_callback(play_animation.bind(active_player, "walk_down" if diff_y > 0 else "walk_up"))
				tween.tween_property(active_player, "global_position:y", pt.y, dist_y / walk_speed)
			if dist_x > 0: 
				tween.tween_callback(play_animation.bind(active_player, "walk_right" if diff_x > 0 else "walk_left"))
				tween.tween_property(active_player, "global_position:x", pt.x, dist_x / walk_speed)
		current = pt

	tween.tween_callback(play_animation.bind(active_player, "idle"))
	await tween.finished
	is_walking = false
	
	var trigger_chance = 0.20
	if randf() <= trigger_chance and scenario_popup:
		var has_event = scenario_popup.try_start_scenario(target_place.name)
		if has_event:
			# รอจนกว่าผู้เล่นจะเลือกทางเลือกเสร็จ
			var effects = await scenario_popup.scenario_resolved
			_apply_scenario_effects(effects)
			
	# จบเหตุการณ์แล้ว ค่อยเปิดหน้าต่างกิจกรรมตามปกติ
	_handle_activity_popup(target_place)

# ==========================================
# ระบบกิจกรรม และ Popup (แยกระหว่างเรียนกับกิจกรรมปกติ)
# ==========================================
func _handle_activity_popup(target_place: Node2D) -> void:
	var popup = $UILayer/ActivityPopup
	if not popup: return
		
	var place_effects = activity_effects.get(target_place.name, {}).duplicate()
	
	# โชว์รายวิชาบนตึก Learn
	if target_place.name == "Learn":
		var t_data = Global.player_data[current_player_index].get("timetable", {})
		if t_data.has("counts"):
			var registered_subjects = t_data["counts"].keys()
			for sub_name in registered_subjects:
				var action_name = "เรียน " + str(sub_name)
				# Hover ของวิชาเรียน จะไม่แสดงค่าความรู้แล้ว เพราะความรู้ได้จากควิซ
				place_effects[action_name] = {"stamina": -15, "hunger": -10, "happiness": -10}
	
	popup.open_popup(target_place.name, current_player_index, place_effects)
	var chosen_action = await popup.activity_chosen 
	
	if chosen_action != "ยกเลิก (ไม่ทำกิจกรรม)":
		if chosen_action == "จบเทิร์น":
			pass_turn()
			return

		var is_fainted = false
		
		# >>> ตรวจสอบว่ากิจกรรมที่กด คือ "เรียน" หรือ "กิจกรรมปกติ" <<<
		if chosen_action.begins_with("เรียน ") and learning_popup:
			var subject_name = chosen_action.replace("เรียน ", "")
			
			# เปิดหน้าควิซ รอผลคะแนน และคำนวณสเตตัส
			learning_popup.start_quiz(subject_name)
			var study_gained = await learning_popup.quiz_finished
			is_fainted = _apply_learning_effects(study_gained)
			_mark_mission_completed(chosen_action)
			
		else:
			# หากเป็นกิจกรรมปกติ (หอพัก, โรงอาหาร ฯลฯ) ให้ทำงานตามปกติ
			is_fainted = apply_activity_effects(chosen_action, target_place.name)

		var activity_minutes = _get_activity_time_cost(chosen_action, target_place.name)
		if not is_fainted:
			_advance_time(activity_minutes * 60)
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

	if player_panel:
		player_panel.update_time_ui(current_minutes, NORMAL_WAKE_MINUTES, SLEEP_MINUTES)

func _get_activity_time_cost(action_name: String, place_name: String) -> int:
	if action_name.begins_with("เรียน "):
		return 2
	return activity_time_costs.get(place_name, {}).get(action_name, 1)
		
func _apply_learning_effects(study_gained: int) -> bool:
	var p_data = Global.player_data[current_player_index]
	var is_fainted = false 
	var stats = p_data["stats"]
	
	stats["study"] = clamp(stats.get("study", 0) + study_gained, 0, 100)
	stats["stamina"] = clamp(stats.get("stamina", 0) - 15, 0, 100)
	stats["hunger"] = clamp(stats.get("hunger", 0) - 10, 0, 100)
	stats["happiness"] = clamp(stats.get("happiness", 0) - 10, 0, 100)
	
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
	
	# ดึงข้อมูลผลกระทบของกิจกรรมปกติ (ไม่มีการเช็คตึก Learn ตรงนี้แล้ว)
	if activity_effects.has(place_name) and activity_effects[place_name].has(action_name):
		effects = activity_effects[place_name][action_name]
		
	for key in effects:
		var change_val = effects[key]
		if key == "money":
			p_data["money"] = max(0, p_data.get("money", 0) + change_val)
		else:
			var current_stat = p_data["stats"].get(key, 0)
			var new_stat = clamp(current_stat + change_val, 0, 100)
			p_data["stats"][key] = new_stat
			
			if (key == "hunger" or key == "stamina") and new_stat <= 0:
				is_fainted = true
				p_data["stats"][key] = 20
			
	if player_panel: player_panel.setup_players_ui()
	return is_fainted

# ==========================================
# ระบบภารกิจ (Missions)
# ==========================================
func render_mission_text(player_index: int, round_num: int) -> void:
	if not Global.player_data[player_index].has("timetable"): return
		
	var day_key = "R" + str(((round_num - 1) % 5) + 1) 
	var missions = Global.player_data[player_index]["timetable"].get("daily_subjects", {}).get(day_key, [])
	var display_text = ""
	
	for m in missions:
		if m["is_completed"]:
			display_text += "[color=green]☑[/color] [s]เรียน " + m["subject"] + "[/s]\n"
		else:
			display_text += "☐ เรียน " + m["subject"] + "\n"
			
	if player_panel and player_panel.has_method("update_mission"):
		player_panel.update_mission(display_text)

func _mark_mission_completed(action_name: String) -> void:
	var subject_name = action_name.replace("เรียน ", "")
	var day_key = "R" + str(((current_round - 1) % 5) + 1)
	var missions = Global.player_data[current_player_index]["timetable"].get("daily_subjects", {}).get(day_key, [])
	
	for m in missions:
		if m["subject"] == subject_name and not m["is_completed"]:
			m["is_completed"] = true
			break 
			
	render_mission_text(current_player_index, current_round)

func _reset_daily_missions(new_round: int) -> void:
	var day_key = "R" + str(((new_round - 1) % 5) + 1)
	for p_data in Global.player_data:
		if p_data.has("timetable") and p_data["timetable"].has("daily_subjects"):
			var missions = p_data["timetable"]["daily_subjects"].get(day_key, [])
			for m in missions:
				m["is_completed"] = false

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
			stats[key] = clamp(stats.get(key, 0) + effects[key], 0, 100)
			
	if player_panel: player_panel.setup_players_ui()

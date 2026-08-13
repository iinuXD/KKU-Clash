extends Node2D

@onready var original_player: Control = $Player
@onready var locations_node: Node2D = $location
@onready var waypoints_node: Node2D = $waypiont
@onready var dorm_marker: Marker2D = $waypiont/Dorm # จุดเกิดที่หอพัก

@onready var camera: Camera2D = $Camera
@onready var player_panel = $UILayer/PlayerPanel

var astar: AStar2D
var all_markers: Array[Marker2D] = []

var player_nodes: Array[Control] = [] 
var current_player_index: int = 0     
var current_player_walks: int = 0     
var max_walks_per_turn: int = 5       
var is_walking: bool = false

var current_round: int = 1
var max_rounds: int = 20     

const CUSTOM_LINKS := [
	["Dorm", "Round1"],
	["Round1", "Sport"],
	["Sport", "Shop"],
	["Shop", "Cross1"],
	["Cross1", "Library"],
	["Library", "Cross5"],
	["Cross1", "Food"],
	["Food", "Round2"],
	["Round2", "Cross2"],
	["Cross2", "Learn"],
	["Learn", "Cross5"],
	["Cross5", "Cross6"],
	["Cross6", "Round1"],
	["Cross6", "Round3"],
	["Round3", "End4"],
	["Round3", "Cross4"],
	["Cross3", "Cross4"],
	["Cross3", "Hospital"],
	["Cross3", "Cross7"],
	["Cross8", "Cross4"],
	["Cross8", "Fun"],
	["Cross7", "Fun"],
	["Cross3", "Cross2"],
	["End4", "Park"]
] 

var activity_effects = {
	"Dorm": {
		"นอนพัก": {"stamina": 30},
		"เล่นเกม": {"happiness": 20, "stamina": -5},
		"อ่านหนังสือ": {"study": 10, "stamina": -10, "happiness": -5},
		"จ่ายค่าห้อง": {"money": -800, "happiness": 10}
	},
	"Food": {
		"กินข้าวจานธรรมดา": {"money": -40, "hunger": 25},
		"กินข้าวจานพิเศษ": {"money": -50, "hunger": 35, "happiness": 5},
		"กินของทานเล่น": {"money": -20, "hunger": 10, "happiness": 15},
		"ทำ Parttime": {"money": 120, "stamina": -15, "hunger": -10}
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

func _ready() -> void:
	
	_setup_mock_data()
	
	if player_panel:
		player_panel.setup_players_ui()
		
	setup_astar()
	
	var players = Global.player_data.size() if Global.player_data.size() > 0 else 1
	for i in range(players):
		var p_node: Control
		if i == 0:
			p_node = original_player
		else:
			p_node = original_player.duplicate()
			add_child(p_node)
		
		setup_player(i, p_node)
		player_nodes.append(p_node)
		play_animation(p_node, "idle")
		
	# --- แก้ไขการเชื่อมต่อสถานที่ (Area2D) ตรงนี้ ---
	for place in locations_node.get_children():
		if place is Area2D:
			# Area2D จะใช้สัญญาณที่ชื่อ input_event แทน gui_input
			place.input_event.connect(_on_place_clicked.bind(place))
			
	setup_current_turn()
	
func _setup_mock_data() -> void:
	print("--- โหลดข้อมูล Mock Data ---")
	
	# ถ้าอาร์เรย์ว่างเปล่า (เกิดจากรันเทสต์ฉากนี้ตรงๆ) ให้จำลองผู้เล่นขึ้นมา 2 คน
	if Global.player_data.size() == 0:
		Global.player_data = [{}, {}]
		print("จำลองผู้เล่นขึ้นมาใหม่ 2 คน เพราะ Global ว่างเปล่า")
	
	for i in range(Global.player_data.size()):
		# เซ็ตเงิน 5555 บาท
		if not Global.player_data[i].has("money"):
			Global.player_data[i]["money"] = 1000
			
		# เซ็ตสเตตัส 50 ทุกอัน
		if not Global.player_data[i].has("stats"):
			Global.player_data[i]["stats"] = {
				"happiness": 50,
				"hunger": 70,
				"stamina": 70,
				"study": 0
			}
	
func setup_current_turn() -> void:
	# 1. รีเซ็ตจำนวนก้าว
	current_player_walks = 0
	
	var active_player = player_nodes[current_player_index]
	
	# 2. จัดการตัวละครบนแผนที่ (ซ่อนคนอื่น, แสดงคนปัจจุบัน, วาร์ปไปจุดเกิดหอพัก)
	for i in range(player_nodes.size()):
		if i == current_player_index:
			player_nodes[i].show()
			player_nodes[i].global_position = dorm_marker.global_position
		else:
			player_nodes[i].hide()	

	# 3. ส่งสัญญาณไปบอก PlayerPanel ให้สลับกรอบรูปและรีเซ็ตเลข AP
	if player_panel:
		player_panel.update_turn_ui(current_player_index)
		player_panel.update_ap_ui(current_player_walks, max_walks_per_turn)
		player_panel.update_round_ui(current_round, max_rounds)

	# 4. เลื่อนกล้อง (Pan) ไปหาตัวละครคนปัจจุบันอัตโนมัติ
	var tween = create_tween()
	# เลื่อนไปแบบสมูทๆ ใช้เวลา 0.6 วินาที
	tween.tween_property(camera, "global_position", active_player.global_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func pass_turn() -> void:
	current_player_index += 1
	
	if current_player_index >= player_nodes.size():
		current_player_index = 0
		current_round += 1
		print("--- จบรอบของทุกคน! เริ่มรอบที่ ", current_round, " ---")
		
		if current_round > max_rounds:
			print("จบเกม!!!")
			# get_tree().change_scene_to_file("res://scene/EndGame.tscn")
			return
		
	print("--- เปลี่ยนเทิร์น! ตาของผู้เล่นคนที่ ", current_player_index + 1, " ---")
	setup_current_turn()

# ==========================================
# ระบบ A* และการเดิน
# ==========================================
func setup_astar() -> void:
	astar = AStar2D.new()
	all_markers.clear()
	var marker_id_by_name: Dictionary = {}
	
	# ดึงหมุดทั้งหมดจากโหนด waypiont
	if waypoints_node:
		for w in waypoints_node.get_children():
			if w is Marker2D: all_markers.append(w)
			
	for i in range(all_markers.size()):
		astar.add_point(i, all_markers[i].global_position)
		marker_id_by_name[all_markers[i].name] = i

	for link in CUSTOM_LINKS:
		if link.size() < 2:
			push_warning("Invalid CUSTOM_LINKS entry: " + str(link))
			continue

		var from_name := str(link[0])
		var to_name := str(link[1])

		if not marker_id_by_name.has(from_name):
			push_warning("CUSTOM_LINKS missing waypoint marker: " + from_name)
			continue
		if not marker_id_by_name.has(to_name):
			push_warning("CUSTOM_LINKS missing waypoint marker: " + to_name)
			continue

		var from_id: int = marker_id_by_name[from_name]
		var to_id: int = marker_id_by_name[to_name]

		if not astar.are_points_connected(from_id, to_id):
			astar.connect_points(from_id, to_id, true)


func _on_place_clicked(viewport: Node, event: InputEvent, shape_idx: int, clicked_place: Node2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print(">>> 1. ตรวจจับการคลิกได้ที่สถานที่: ", clicked_place.name)
		if not is_walking:
			walk_to_place(clicked_place)

# เปลี่ยนตรง target_place: Control เป็นเป้าหมายแบบ Node2D ครับ
func walk_to_place(target_place: Node2D) -> void:
	var target_marker = target_place.get_node_or_null("Marker2D")
	if target_marker == null:
		var path_name = NodePath(str(target_place.name))
		target_marker = waypoints_node.get_node_or_null(path_name)
		
	if target_marker == null: 
		print(">>> 2. หา Marker ไม่เจอ! ยกเลิกการเดิน")
		return
	
	var active_player = player_nodes[current_player_index]
	var start_pos = active_player.global_position
	var target_pos = target_marker.global_position
	
	var start_id = astar.get_closest_point(start_pos)
	var target_id = astar.get_closest_point(target_pos)
	var path = astar.get_point_path(start_id, target_id)
	
	if path.is_empty(): 
		print(">>> 3. สร้างเส้นทางไม่ได้ (A* ไปไม่ถึง) หมุดอาจจะเยื้องกันเกินไป!")
		return
		
	var walk_speed = 300.0 
	var tween = create_tween()
	var current = start_pos
	
	is_walking = true 
	
	for pt in path:
		var diff_x = pt.x - current.x
		var diff_y = pt.y - current.y
		var dist_x = abs(diff_x)
		var dist_y = abs(diff_y)
		
		if dist_x > dist_y:
			if dist_x > 0: 
				var anim = "walk_right" if diff_x > 0 else "walk_left"
				tween.tween_callback(play_animation.bind(active_player, anim))
				tween.tween_property(active_player, "global_position:x", pt.x, dist_x / walk_speed)
			if dist_y > 0: 
				var anim = "walk_down" if diff_y > 0 else "walk_up"
				tween.tween_callback(play_animation.bind(active_player, anim))
				tween.tween_property(active_player, "global_position:y", pt.y, dist_y / walk_speed)
		else:
			if dist_y > 0: 
				var anim = "walk_down" if diff_y > 0 else "walk_up"
				tween.tween_callback(play_animation.bind(active_player, anim))
				tween.tween_property(active_player, "global_position:y", pt.y, dist_y / walk_speed)
			if dist_x > 0: 
				var anim = "walk_right" if diff_x > 0 else "walk_left"
				tween.tween_callback(play_animation.bind(active_player, anim))
				tween.tween_property(active_player, "global_position:x", pt.x, dist_x / walk_speed)
			
		current = pt

	tween.tween_callback(play_animation.bind(active_player, "idle"))
	await tween.finished
	is_walking = false
	print(">>> 4. เดินถึงที่หมายแล้ว!")
	
	var popup = $UILayer/ActivityPopup
	if popup:
		# ดึงข้อมูลสเตตัสเฉพาะของตึกที่ยืนอยู่ (ถ้าไม่มีให้คืนค่าว่าง)
		var place_effects = activity_effects.get(target_place.name, {})
		
		# ส่ง place_effects เข้าไปในวงเล็บด้วย
		popup.open_popup(target_place.name, current_player_index, place_effects)
		
		# สั่งให้โค้ด "หยุดรอ" จนกว่าผู้เล่นจะกดปุ่มใดปุ่มหนึ่งใน Popup
		var chosen_action = await popup.activity_chosen 
		print("ผู้เล่นคนที่ ", current_player_index + 1, " เลือกทำกิจกรรม: ", chosen_action)
		
		# ถ้าผู้เล่นไม่ได้กดปิดหน้าต่าง (ทำกิจกรรมจริง)
		if chosen_action != "ยกเลิก (ไม่ทำกิจกรรม)":
			# คำนวณบวกลบสเตตัส พร้อมรับค่าว่า "สลบหรือไม่" 
			var is_fainted = apply_activity_effects(chosen_action, target_place.name)
			
			if is_fainted:
				# บทลงโทษ 1: โดนริบ AP ทั้งหมดที่มีในเทิร์นนั้น
				current_player_walks = max_walks_per_turn
				# บทลงโทษ 2: วาร์ปตัวละครกลับหอพักทันที
				active_player.global_position = dorm_marker.global_position
				
				# ให้กล้องสไลด์ตามกลับไปที่หอพักด้วย จะได้ไม่หลง
				var cam_tween = create_tween()
				cam_tween.tween_property(camera, "global_position", active_player.global_position, 0.4).set_trans(Tween.TRANS_SINE)
			else:
				# ถ้าไม่สลบ หัก AP 1 แต้มปกติ
				current_player_walks += 1
		else:
			# ถ้ากดยกเลิก (CloseButton) ก็หัก 1 AP เหมือนกัน เพราะเสียเวลาเดินมาแล้ว
			current_player_walks += 1
			
		# อัปเดต UI และตรวจสอบการเปลี่ยนเทิร์น (เขียนไว้รอบเดียวพอ)
		if player_panel:
			player_panel.update_ap_ui(current_player_walks, max_walks_per_turn)
		
		if current_player_walks >= max_walks_per_turn:
			pass_turn()

func play_animation(player_node: Control, anim_name: String) -> void:
	var anim_player = player_node.get_node_or_null("Panel/CenterPoint/AnimationPlayer")
	if anim_player:
		anim_player.play(anim_name)

func setup_player(player_index: int, player_character: Control) -> void:
	var my_data = Global.player_data[player_index] if Global.player_data.size() > player_index else {}
	if not my_data.has("avatar_settings"): return
	
	var settings = my_data["avatar_settings"]
	var body_sprite = player_character.get_node("Panel/CenterPoint/BodySprite")
	var face_sprite = player_character.get_node("Panel/CenterPoint/EyeSprite")
	var outfit_sprite = player_character.get_node("Panel/CenterPoint/OutfitSprite")
	var hair_sprite = player_character.get_node("Panel/CenterPoint/HairSprite")
	var accessory_sprite = player_character.get_node("Panel/CenterPoint/AccessorySprite")
	
	if settings.has("skin_path") and settings["skin_path"] != "": body_sprite.texture = load(settings["skin_path"])
	if settings.has("face_path") and settings["face_path"] != "": face_sprite.texture = load(settings["face_path"])
	if settings.has("outfit_path") and settings["outfit_path"] != "": outfit_sprite.texture = load(settings["outfit_path"])
	if settings.has("hair_path") and settings["hair_path"] != "": hair_sprite.texture = load(settings["hair_path"])
	if settings.has("accessory_path") and settings["accessory_path"] != "": accessory_sprite.texture = load(settings["accessory_path"])

func apply_activity_effects(action_name: String, place_name: String) -> bool:
	var p_data = Global.player_data[current_player_index]
	var effects = {}
	var is_fainted = false # ตัวแปรดักจับว่าสลบไหม
	
	if place_name == "Learn" and action_name.begins_with("เรียน "):
		effects = {"study": 20, "stamina": -15, "hunger": -10, "happiness": -10}
		
	# ดึงค่าจากตารางกิจกรรม โดยอิงตามตึกที่ยืนอยู่
	elif activity_effects.has(place_name) and activity_effects[place_name].has(action_name):
		effects = activity_effects[place_name][action_name]
		
	# คำนวณการเปลี่ยนแปลง
	print("--- ประมวลผลกิจกรรม: ", action_name, " ที่ ", place_name, " ---")
	for key in effects:
		var change_val = effects[key]
		
		if key == "money":
			p_data["money"] = max(0, p_data.get("money", 0) + change_val)
		else:
			var current_stat = p_data["stats"].get(key, 0)
			var new_stat = clamp(current_stat + change_val, 0, 100)
			p_data["stats"][key] = new_stat
			
			# --- ตรวจจับสถานะ 0 (ความหิว หรือ พลังงาน) ---
			if (key == "hunger" or key == "stamina") and new_stat <= 0:
				is_fainted = true
				print("!!! แจ้งเตือน: ผู้เล่นสลบเพราะ ", key, " เหลือ 0 !!!")
				
				# บทลงโทษ: โดนบังคับให้รอบหน้าฟื้นมาแค่ขีดแดง (20)
				p_data["stats"][key] = 20
			
	if player_panel:
		player_panel.setup_players_ui()
		
	return is_fainted

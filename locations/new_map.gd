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

func _ready() -> void:
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

	# 4. เลื่อนกล้อง (Pan) ไปหาตัวละครคนปัจจุบันอัตโนมัติ
	var tween = create_tween()
	# เลื่อนไปแบบสมูทๆ ใช้เวลา 0.6 วินาที
	tween.tween_property(camera, "global_position", active_player.global_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func pass_turn() -> void:
	current_player_index += 1
	
	if current_player_index >= player_nodes.size():
		current_player_index = 0
		print("--- จบรอบของทุกคน! เริ่มรอบใหม่ ---")
		
	print("--- เปลี่ยนเทิร์น! ตาของผู้เล่นคนที่ ", current_player_index + 1, " ---")
	setup_current_turn()

# ==========================================
# ระบบ A* และการเดิน
# ==========================================
func setup_astar() -> void:
	astar = AStar2D.new()
	all_markers.clear()
	
	# ดึงหมุดทั้งหมดจากโหนด waypiont
	if waypoints_node:
		for w in waypoints_node.get_children():
			if w is Marker2D: all_markers.append(w)
			
	for i in range(all_markers.size()):
		astar.add_point(i, all_markers[i].global_position)
		
	var margin = 15.0
	for i in range(all_markers.size()):
		var p1 = all_markers[i].global_position
		
		var closest_up = -1; var dist_up = 999999.0
		var closest_down = -1; var dist_down = 999999.0
		var closest_left = -1; var dist_left = 999999.0
		var closest_right = -1; var dist_right = 999999.0
		
		for j in range(all_markers.size()):
			if i == j: continue
			var p2 = all_markers[j].global_position
			var dist = p1.distance_to(p2)
			
			if abs(p1.y - p2.y) < margin:
				if p2.x < p1.x and dist < dist_left: dist_left = dist; closest_left = j
				elif p2.x > p1.x and dist < dist_right: dist_right = dist; closest_right = j
					
			if abs(p1.x - p2.x) < margin:
				if p2.y < p1.y and dist < dist_up: dist_up = dist; closest_up = j
				elif p2.y > p1.y and dist < dist_down: dist_down = dist; closest_down = j
					
		if closest_up != -1: astar.connect_points(i, closest_up)
		if closest_down != -1: astar.connect_points(i, closest_down)
		if closest_left != -1: astar.connect_points(i, closest_left)
		if closest_right != -1: astar.connect_points(i, closest_right)


func _on_place_clicked(viewport: Node, event: InputEvent, shape_idx: int, clicked_place: Node2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print(">>> 1. ตรวจจับการคลิกได้ที่สถานที่: ", clicked_place.name)
		if not is_walking:
			walk_to_place(clicked_place)

# เปลี่ยนตรง target_place: Control เป็นเป้าหมายแบบ Node2D ครับ
func walk_to_place(target_place: Node2D) -> void:
	# ค้นหา Marker2D ในสถานที่ที่ถูกคลิก หรือดึงจาก waypiont โดยเทียบชื่อ
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
	else:
		print(">>> 3. สร้างเส้นทางสำเร็จ! จำนวนจุด: ", path.size())
		
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
	
	# โค้ดส่วนจัดการ AP หลังเดินจบตา
	current_player_walks += 1
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

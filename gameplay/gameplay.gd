extends Node2D

@onready var original_player: Control = $Player
@onready var locations: Node2D = $Locations

# --- เปลี่ยนจาก AStarGrid2D เป็น AStar2D (ระบบจุดแวะพัก) ---
var astar: AStar2D
var all_markers: Array[Marker2D] = []

var player_nodes: Array[Control] = [] # เก็บโหนดตัวละครของทุกคน
var current_player_index: int = 0     # บอกว่าตอนนี้ตาใคร (0 = คนแรก)
var current_player_walks: int = 0     # นับว่าคนปัจจุบันเดินไปกี่ครั้งแล้ว
var max_walks_per_turn: int = 5       # จำนวนครั้งที่เดินได้ต่อเทิร์น
var is_walking: bool = false          # ล็อคไม่ให้กดเดินซ้ำตอนกำลังเดินอยู่

func _ready() -> void:
	setup_astar()
	
	var players = Global.player_count
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
		
	for place in locations.get_children():
		if place is Control:
			place.gui_input.connect(_on_place_clicked.bind(place))
	
	setup_current_turn()
	
func setup_current_turn() -> void:
	for i in range(player_nodes.size()):
		if i == current_player_index:
			player_nodes[i].show()
			player_nodes[i].global_position = $Locations/Place1/Marker2D.global_position
		else:
			player_nodes[i].hide()	

func pass_turn() -> void:
	current_player_walks = 0
	current_player_index += 1
	
	if current_player_index >= player_nodes.size():
		current_player_index = 0
		
	print("--- เปลี่ยนเทิร์น! ตาของผู้เล่นคนที่ ", current_player_index + 1, " ---")
	setup_current_turn()

# ==========================================
# ระบบ A* แบบปักหมุด (Waypoint Network)
# ==========================================
func setup_astar() -> void:
	astar = AStar2D.new()
	all_markers.clear()
	
	# 1. รวบรวมหมุดจากสถานที่ (Place 1-4)
	for place in locations.get_children():
		var m = place.get_node_or_null("Marker2D")
		if m: all_markers.append(m)
			
	# 2. รวบรวมหมุดจาก "ทางแยก" (ที่คุณสร้างใหม่ในโหนด Waypoints)
	var waypoints_node = get_node_or_null("Waypoints")
	if waypoints_node:
		for w in waypoints_node.get_children():
			if w is Marker2D: all_markers.append(w)
			
	# 3. นำหมุดทั้งหมดปักลงในระบบ A*
	for i in range(all_markers.size()):
		astar.add_point(i, all_markers[i].global_position)
		
	# 4. วงจร AI: เชื่อมต่อถนนอัตโนมัติ (ซ้าย-ขวา-บน-ล่าง)
	var margin = 15.0 # ยอมให้จุดเยื้องกันได้ 15 พิกเซล (ไม่ต้องวางเป๊ะ 100% ก็เดินได้)
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
			
			# หาจุดที่อยู่แนวเดียวกันในแกน Y (ซ้าย/ขวา)
			if abs(p1.y - p2.y) < margin:
				if p2.x < p1.x and dist < dist_left: dist_left = dist; closest_left = j
				elif p2.x > p1.x and dist < dist_right: dist_right = dist; closest_right = j
					
			# หาจุดที่อยู่แนวเดียวกันในแกน X (บน/ล่าง)
			if abs(p1.x - p2.x) < margin:
				if p2.y < p1.y and dist < dist_up: dist_up = dist; closest_up = j
				elif p2.y > p1.y and dist < dist_down: dist_down = dist; closest_down = j
					
		# สั่งโยงเส้นถนน
		if closest_up != -1: astar.connect_points(i, closest_up)
		if closest_down != -1: astar.connect_points(i, closest_down)
		if closest_left != -1: astar.connect_points(i, closest_left)
		if closest_right != -1: astar.connect_points(i, closest_right)

func _on_place_clicked(event: InputEvent, clicked_place: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_walking:
			walk_to_place(clicked_place)

func walk_to_place(target_place: Control) -> void:
	var target_marker = target_place.get_node_or_null("Marker2D")
	if target_marker == null: return
	
	var active_player = player_nodes[current_player_index]
	var start_pos = active_player.global_position
	var target_pos = target_marker.global_position
	
	# หา ID ของหมุดที่ใกล้ตัวละครที่สุด และใกล้เป้าหมายที่สุด
	var start_id = astar.get_closest_point(start_pos)
	var target_id = astar.get_closest_point(target_pos)
	
	# ขอเส้นทางแบบจุดต่อจุด (ไม่ต้องสนใจขนาดตารางอีกต่อไป)
	var path = astar.get_point_path(start_id, target_id)
	
	if path.is_empty():
		print("ไม่มีเส้นทาง! (ลองเช็คว่าวาง Marker ตรงทางแยกครบไหม)")
		return
		
	var walk_speed = 300.0 
	var tween = create_tween()
	var current = start_pos
	
	is_walking = true 
	
	# เดินไต่ไปตามหมุดทีละจุด หักมุมฉากแบบเป๊ะๆ
	for pt in path:
		# คำนวณระยะทางแบบมีค่าติดลบเพื่อหาทิศทาง
		var diff_x = pt.x - current.x
		var diff_y = pt.y - current.y
		
		var dist_x = abs(diff_x)
		var dist_y = abs(diff_y)
		
		# เลือกว่าจะเดินแกนไหนก่อน
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

	# --- เพิ่มคำสั่งหยุดเล่น Animation เมื่อเดินถึงที่หมายแล้ว ---
	tween.tween_callback(play_animation.bind(active_player, "idle"))
	
	await tween.finished
	is_walking = false
	
	current_player_walks += 1
	print("ผู้เล่นคนที่ ", current_player_index + 1, " เดินไปแล้ว ", current_player_walks, "/", max_walks_per_turn, " ครั้ง")
	
	if current_player_walks >= max_walks_per_turn:
		pass_turn()

# ฟังก์ชันสั่งเล่น Animation
func play_animation(player_node: Control, anim_name: String) -> void:
	var anim_player = player_node.get_node_or_null("Panel/CenterPoint/AnimationPlayer")
	if anim_player:
		anim_player.play(anim_name)

# (ฟังก์ชัน setup_player โหลดรูปภาพเหมือนเดิมทุกประการ)
func setup_player(player_index: int, player_character: Control) -> void:
	var my_data = Global.player_data[player_index]
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

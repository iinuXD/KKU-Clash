extends Control

@onready var stats = [
	$playerstat1,
	$playerstat2,
	$playerstat3,
	$playerstat4
]
@onready var ap_label = $ActionPoint 
@onready var week_label = $WeekReportLabel 

var border_normal = preload("res://asset/playerpanel/border.png")
var border_active = preload("res://asset/playerpanel/border2.png")

# --- ตัวแปรสำหรับป้ายโชว์ตัวเลข (ลอยตามเมาส์) ---
var hover_label: Label

func _ready() -> void:
	# สร้างป้าย Label ขึ้นมาด้วยโค้ด พร้อมตกแต่งกรอบสีดำโปร่งแสง
	hover_label = Label.new()
	var style = StyleBoxFlat.new()

	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)

	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	hover_label.add_theme_stylebox_override("normal", style)
	hover_label.add_theme_font_size_override("font_size", 14)
	hover_label.z_index = 100 # ดันให้อยู่บนสุด ไม่โดนอะไรบัง
	hover_label.hide() # ซ่อนไว้ก่อน
	add_child(hover_label)

# ฟังก์ชันนี้จะสั่งให้ป้ายวิ่งตามปลายเมาส์ตลอดเวลา (เมื่อถูกเปิดให้มองเห็น)
func _process(delta: float) -> void:
	if hover_label and hover_label.visible:
		hover_label.global_position = get_global_mouse_position() + Vector2(15, 15)

func setup_players_ui() -> void:
	var player_count = Global.player_data.size() if Global.player_data.size() > 0 else 1
	
	for i in range(stats.size()):
		var stat_panel = stats[i]
		if i < player_count:
			stat_panel.visible = true
			_update_avatar(stat_panel, i)
			_update_stats_ui(stat_panel, i)
		else:
			stat_panel.visible = false

func update_turn_ui(active_index: int) -> void:
	for i in range(stats.size()):
		if not stats[i].visible: continue
		var portrait = stats[i].get_node_or_null("HBoxContainer/PortraitBackground1")
		if portrait:
			if i == active_index:
				portrait.texture = border_active
			else:
				portrait.texture = border_normal

func update_ap_ui(current_walks: int, max_walks: int) -> void:
	if ap_label:
		var ap_left = max_walks - current_walks
		ap_label.text = "AP " + str(ap_left) + "/" + str(max_walks)

func update_round_ui(current_round: int, max_rounds: int) -> void:
	if week_label:
		week_label.text = "WEEK " + str(current_round) + "/" + str(max_rounds)

func _update_avatar(stat_panel: Node, player_index: int) -> void:
	var p_data = Global.player_data[player_index] if Global.player_data.size() > player_index else {}
	if not p_data.has("avatar_settings"): return
		
	var settings = p_data["avatar_settings"]
	var center_point = stat_panel.get_node_or_null("HBoxContainer/PortraitBackground1/CenterPoint")
	
	if center_point:
		if settings.has("skin_path") and settings["skin_path"] != "": center_point.get_node("BodySprite").texture = load(settings["skin_path"])
		if settings.has("face_path") and settings["face_path"] != "": center_point.get_node("EyeSprite").texture = load(settings["face_path"])
		if settings.has("outfit_path") and settings["outfit_path"] != "": center_point.get_node("OutfitSprite").texture = load(settings["outfit_path"])
		if settings.has("hair_path") and settings["hair_path"] != "": center_point.get_node("HairSprite").texture = load(settings["hair_path"])
		if settings.has("accessory_path") and settings["accessory_path"] != "": center_point.get_node("AccessorySprite").texture = load(settings["accessory_path"])

func _update_stats_ui(stat_panel: Node, player_index: int) -> void:
	var p_data = Global.player_data[player_index] if Global.player_data.size() > player_index else {}
	
	var money_val = p_data.get("money", 0)
	var money_label = stat_panel.find_child("money", true, false)
	if money_label:
		money_label.text = str(money_val)
		
	var stats_data = p_data.get("stats", {})
	var stat_nodes = {
		"happiness": "happinessstat",
		"hunger": "hungerstat",
		"stamina": "staminastat",
		"study": "studystat"
	}
	
	for stat_name in stat_nodes:
		var target_name = stat_nodes[stat_name]
		var texture_rect = stat_panel.find_child(target_name, true, false)
		
		if texture_rect == null: continue
			
		var val = stats_data.get(stat_name, 0)
		var level = int(val / 10) * 10
		level = clamp(level, 0, 100)
		
		var tex_path = "res://asset/playerpanel/%s/%s%d.png" % [stat_name, stat_name, level]
		if ResourceLoader.exists(tex_path):
			texture_rect.texture = load(tex_path)
			
		# --- ระบบฝังข้อมูลสำหรับป้าย Hover ---
		texture_rect.set_meta("stat_val", val) # ฝังตัวเลขจริงไว้ในรูป
		texture_rect.set_meta("stat_name", stat_name) # ฝังชื่อสถานะไว้ในรูป
		
		texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS # เปิดให้รูปรับเมาส์ได้
		
		# เชื่อมต่อสัญญาณเมาส์เข้า-ออก (ทำครั้งเดียว)
		if not texture_rect.mouse_entered.is_connected(_on_icon_mouse_entered):
			texture_rect.mouse_entered.connect(_on_icon_mouse_entered.bind(texture_rect))
			texture_rect.mouse_exited.connect(_on_icon_mouse_exited)

# ==========================================
# ระบบเอาเมาส์ชี้เพื่อโชว์ตัวเลข (Hover)
# ==========================================
func _on_icon_mouse_entered(rect: TextureRect) -> void:
	# ดึงข้อมูลที่เราฝังไว้ตอนเซ็ตอัปออกมา
	var val = rect.get_meta("stat_val", 0)
	var s_name = rect.get_meta("stat_name", "")
	
	# พจนานุกรมแปลภาษา เพื่อความสวยงามตอนโชว์
	var th_names = {
		"happiness": "ความสุข", 
		"hunger": "ความอิ่ม", 
		"stamina": "พลังงาน", 
		"study": "ความรู้"
	}
	var display_name = th_names.get(s_name, s_name)
	
	# ตั้งค่าข้อความ และแสดงป้ายขึ้นมา
	hover_label.text = "  " + display_name + " : " + str(val) + "%  "
	hover_label.show()

func _on_icon_mouse_exited() -> void:
	# พอเมาส์ออกจากรูป ก็ซ่อนป้ายไป
	hover_label.hide()

extends Control

@onready var stats = [
	$playerstat1,
	$playerstat2,
	$playerstat3,
	$playerstat4
]
@onready var ap_label = $ActionPoint # โหนด Label ที่คุณเพิ่งสร้าง

# โหลดรูปกรอบเตรียมไว้ (อย่าลืมเช็คว่าไฟล์เป็น .png หรือสกุลอื่นนะครับ)
var border_normal = preload("res://asset/playerpanel/border.png")
var border_active = preload("res://asset/playerpanel/border2.png")

func _ready() -> void:
	setup_players_ui()

func setup_players_ui() -> void:
	var player_count = Global.player_data.size() if Global.player_data.size() > 0 else 1
	
	for i in range(stats.size()):
		var stat_panel = stats[i]
		if i < player_count:
			stat_panel.visible = true
			_update_avatar(stat_panel, i)
		else:
			stat_panel.visible = false

# ฟังก์ชันสำหรับให้แผนที่สั่งเปลี่ยนสีกรอบ UI ของคนที่เป็นเทิร์นปัจจุบัน
func update_turn_ui(active_index: int) -> void:
	for i in range(stats.size()):
		if not stats[i].visible: continue
		
		# ดึงโหนดกรอบรูป (อิงชื่อตามที่คุณบอกมา)
		var portrait = stats[i].get_node_or_null("HBoxContainer/PortraitBackground1")
		if portrait:
			if i == active_index:
				portrait.texture = border_active # ตาคนนี้ -> กรอบสว่าง
			else:
				portrait.texture = border_normal # ไม่ใช่ตาคนนี้ -> กรอบธรรมดา

# ฟังก์ชันสำหรับให้แผนที่สั่งอัปเดตตัวเลข AP
func update_ap_ui(current_walks: int, max_walks: int) -> void:
	var ap_left = max_walks - current_walks
	ap_label.text = "AP " + str(ap_left) + "/" + str(max_walks)

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

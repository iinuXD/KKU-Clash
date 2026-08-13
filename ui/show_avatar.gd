extends Control

# อ้างอิงถึงช่องใส่ตัวละครทั้ง 4 ช่อง
@onready var slots: Array = [
	$HBoxContainer/PlayerSlot1,
	$HBoxContainer/PlayerSlot2,
	$HBoxContainer/PlayerSlot3,
	$HBoxContainer/PlayerSlot4
]

@onready var loading_label: Label = $LoadingLabel
var loading_texts: Array = ["loading.", "loading..", "loading..."]
var current_text_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# เริ่มต้นด้วยการซ่อนทุกช่องไว้
	for slot in slots:
		slot.hide()
		
	#ดึงค่าจำนวนผู้เล่น
	var players = Global.player_count
	
	#แสงดข้อมูล
	for i in range(players):
		slots[i].show()
		setup_avatar(slots[i], i)
		
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://locations/NewMap.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
# ฟังก์ชันสำหรับสร้างตัวละคร
func setup_avatar(slot: VBoxContainer, player_index: int) -> void:
	var my_data = Global.player_data[player_index]
	
	# กัน error
	if not my_data.has("avatar_settings"):
		print("ผู้เล่นคนที่ ", player_index + 1, " ยังไม่มีข้อมูจ้า")
		
	var settings = my_data["avatar_settings"]
	
	# อ้างอิง Node Sprite2D ที่อยู่ข้างใน Slot นี้
	var body_sprite = slot.get_node("Panel/CenterPoint/BodySprite")
	var face_sprite = slot.get_node("Panel/CenterPoint/EyeSprite")
	var outfit_sprite = slot.get_node("Panel/CenterPoint/OutfitSprite")
	var hair_sprite = slot.get_node("Panel/CenterPoint/HairSprite")
	var accessory_sprite = slot.get_node("Panel/CenterPoint/AccessorySprite")

# โหลดรูปภาพจาก Path ที่บันทึกไว้มาใส่
	if settings.has("skin_path") and settings["skin_path"] != "":
		body_sprite.texture = load(settings["skin_path"])
	if settings.has("face_path") and settings["face_path"] != "":
		face_sprite.texture = load(settings["face_path"])
	if settings.has("outfit_path") and settings["outfit_path"] != "":
		outfit_sprite.texture = load(settings["outfit_path"])
	if settings.has("hair_path") and settings["hair_path"] != "":
		hair_sprite.texture = load(settings["hair_path"])
	if settings.has("accessory_path") and settings["accessory_path"] != "":
		accessory_sprite.texture = load(settings["accessory_path"])

# ฟังก์ชันที่ทำงานทุกๆ 0.5 วินาที ตามที่ Timer สั่ง
func _on_loading_timer_timeout() -> void:
	# แสดงข้อความตาม index ปัจจุบัน
	loading_label.text = loading_texts[current_text_index]
	
	# บวกค่า index เพิ่มทีละ 1
	current_text_index += 1
	
	# ถ้า index มากกว่าหรือเท่ากับจำนวนของใน Array (3) ให้วนกลับไปเริ่มที่ 0
	if current_text_index >= loading_texts.size():
		current_text_index = 0

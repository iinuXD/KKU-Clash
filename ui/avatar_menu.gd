extends Control

# ตัวแปรสำหรับนับว่าตอนนี้กำลังตั้งค่าของผู้เล่นคนที่เท่าไหร่ เริ่มต้นที่ 1
var current_player_index: int = 1

# จำนวนผู้เล่นทั้งหมด ดึงมาจาก Global
var total_players: int = 1

# Array เก็บที่อยู่ไฟล์
var hairs: Array = []
var faces: Array = []
var skins: Array = []
var accessories: Array = []
var outfits: Array = []

# ตัวแปรจำค่า index
var current_hair: int = 0
var current_face: int = 0
var current_skin: int = 2
var current_accessory: int = 12
var current_outfit: int = 10

# อ้างอิง Node Sprite2D
@onready var skin_sprite: Sprite2D = $HBoxContainer2/Panel/CenterPoint/BodySprite
@onready var face_sprite: Sprite2D = $HBoxContainer2/Panel/CenterPoint/EyeSprite
@onready var outfit_sprite: Sprite2D = $HBoxContainer2/Panel/CenterPoint/OutfitSprite
@onready var hair_sprite: Sprite2D = $HBoxContainer2/Panel/CenterPoint/HairSprite
@onready var accessory_sprite: Sprite2D = $HBoxContainer2/Panel/CenterPoint/AccessorySprite

#อ้างอิงไปยัง Label ที่ใช้แสดงข้อความ
@onready var player_label: Label = $PlayerRow/Label_current_player
@onready var faculty_select: OptionButton = $PlayerRow/FacultySelect
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#ดึงค่าจำนวนผู้เล่นที่เบือกไว้จาก Global
	if Global.player_count:
		total_players = Global.player_count
	else:
		total_players = 1
		
	hairs = load_asset_from_Folder("res://asset/Character/Hairstyles/32x32")
	faces = load_asset_from_Folder("res://asset/Character/Eyes/32x32")
	skins = load_asset_from_Folder("res://asset/Character/Bodies/32x32")
	accessories = load_asset_from_Folder("res://asset/Character/Accessories/32x32")
	outfits = load_asset_from_Folder("res://asset/Character/Outfits/32x32")
	
	for faculty in Global.FACULTIES:
		faculty_select.add_item(faculty["name"])
	update_ui()
	load_current_player_data()


# ฟังก์ชันสำหรับการอัปเดตหน้า ui 
func update_ui() -> void:
	player_label.text = "ผู้เล่น " + str(current_player_index)
	
	#อาจจะมีการดึง avatar ที่เลือกไว้
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# ฟังก์ชันการทำงานของปุ่ม back
func _on_backbtn_pressed() -> void:
	save_current_player_data()
	
	if current_player_index > 1:
		current_player_index -= 1
		update_ui()
		load_current_player_data()
	else:
		get_tree().change_scene_to_file("res://ui/PlayerMenu.tscn")
	
# ฟังก์ชันการทำงานของปุ่ม Okay
func _on_okay_btn_pressed() -> void:
		#โค้ดบันทึกค่า Avatar
	save_current_player_data()
	
	if current_player_index < total_players:
		current_player_index += 1
		update_ui()
		load_current_player_data()
	else:
		get_tree().change_scene_to_file("res://ui/showAvatar.tscn")

func update_avatar_preview() -> void:
	# เช็คก่อนว่าในโฟลเดอร์มีไฟล์ไหม
	if skins.size() > 0:
		skin_sprite.texture = load(skins[current_skin])
	if faces.size() > 0:
		face_sprite.texture = load(faces[current_face])
	if outfits.size() > 0:
		outfit_sprite.texture = load(outfits[current_outfit])
	if hairs.size() > 0:
		hair_sprite.texture = load(hairs[current_hair])
	if accessories.size() > 0:
		accessory_sprite.texture = load(accessories[current_accessory])
	
func load_asset_from_Folder(path: String) -> Array:
	var file_paths: Array = []

	# ResourceLoader คืนชื่อทรัพยากรเดิมทั้งใน Editor และไฟล์ .pck หลัง Export
	# จึงไม่ต้องพึ่งไฟล์ .import/.remap ที่อาจแสดงผลต่างกันในแต่ละระบบ
	for file_name in ResourceLoader.list_directory(path):
		if file_name.ends_with("/") or not file_name.to_lower().ends_with(".png"):
			continue
		var resource_path := path.path_join(file_name)
		if ResourceLoader.exists(resource_path, "Texture2D"):
			file_paths.append(resource_path)

	# ลำดับต้องคงที่ เพื่อให้ index ของตัวละครในไฟล์เซฟตรงกันทุกเครื่อง
	file_paths.sort()
	return file_paths
	
func _on_nexthair_pressed() -> void:
	if hairs.size() == 0: return
	
	current_hair += 1
	if current_hair >= hairs.size():
		current_hair = 0
	update_avatar_preview()


func _on_prevhair_pressed() -> void:
	if hairs.size() == 0: return
	
	current_hair -= 1
	if current_hair < 0:
		current_hair = hairs.size() - 1
	update_avatar_preview()

func _on_nextface_pressed() -> void:
	if faces.size() == 0: return
	
	current_face += 1
	if current_face >= faces.size():
		current_face = 0
	update_avatar_preview()

func _on_prevface_pressed() -> void:
	if faces.size() == 0: return
	
	current_face -= 1
	if current_face < 0:
		current_face = faces.size() - 1
	update_avatar_preview()

func _on_nextskin_pressed() -> void:
	if skins.size() == 0: return
	
	current_skin += 1
	if current_skin >= skins.size():
		current_skin = 0
	update_avatar_preview()

func _on_prevskin_pressed() -> void:
	if skins.size() == 0: return
	
	current_skin -= 1
	if current_skin < 0:
		current_skin = skins.size() -1
	update_avatar_preview()

func _on_nextaccessory_pressed() -> void:
	if accessories.size() == 0: return
	
	current_accessory += 1
	if current_accessory >= accessories.size():
		current_accessory = 0
	update_avatar_preview()

func _on_prevaccessory_pressed() -> void:
	if accessories.size() == 0: return
	
	current_accessory -= 1
	if current_accessory < 0:
		current_accessory = accessories.size() - 1
	update_avatar_preview()


func _on_nextattire_pressed() -> void:
	if outfits.size() == 0: return
	
	current_outfit += 1
	if current_outfit >= outfits.size():
		current_outfit = 0
	update_avatar_preview()

func _on_prevattire_pressed() -> void:
	if outfits.size() == 0: return
	
	current_outfit -= 1
	if current_outfit < 0:
		current_outfit = outfits.size() - 1
	update_avatar_preview()

# บันทึกข้อมูลการแต่งตัว
func save_current_player_data() -> void:
	var p_index = current_player_index - 1
	Global.player_data[p_index]["faculty_id"] = Global.FACULTIES[maxi(0, faculty_select.selected)]["id"]
	
	#เก็บค่า Index ลงใน Directory ย่อยช่อ avatar_settings
	Global.player_data[p_index]["avatar_settings"] = {
		"hair": current_hair,
		"face": current_face,
		"skin": current_skin,
		"accessory": current_accessory,
		"outfit": current_outfit,
		
		"hair_path": hairs[current_hair] if hairs.size() > 0 else "",
		"face_path": faces[current_face] if faces.size() > 0 else "",
		"skin_path": skins[current_skin] if skins.size() > 0 else "",
		"accessory_path": accessories[current_accessory] if accessories.size() > 0 else "",
		"outfit_path": outfits[current_outfit] if outfits.size() > 0 else ""
	}
	
# โหลดข้อมูลการแต่งตัวชองผู้เล่นคนนั้น กลับมาแสดงผล
func load_current_player_data() -> void:
	var p_index = current_player_index - 1
	var faculty_id: String = str(Global.player_data[p_index].get("faculty_id", "none"))
	faculty_select.select(-1)
	faculty_select.text = "เลือกคณะเรียน"
	if Global.player_data[p_index].has("avatar_settings") or faculty_id != "none":
		for index in range(Global.FACULTIES.size()):
			if Global.FACULTIES[index]["id"] == faculty_id:
				faculty_select.select(index)
				break
	
	#เช็คว่าผู้เล่นคนนี้เคยแต่งตัวและเซฟค่าไว้หรือยัง
	if Global.player_data[p_index].has("avatar_settings"):
		var saved_data = Global.player_data[p_index]["avatar_settings"]
		current_hair = saved_data["hair"]
		current_face = saved_data["face"]
		current_skin = saved_data["skin"]
		current_accessory = saved_data["accessory"]
		current_outfit = saved_data["outfit"]
	else: 
		# ถ้าเพิ่งเข้ามาหน้าคนนี้ครั้งแรก ให้ตั้งค่าเป็น Default
		current_hair = 0
		current_face = 0
		current_skin = 0
		current_accessory = 0
		current_outfit = 0
	update_avatar_preview()

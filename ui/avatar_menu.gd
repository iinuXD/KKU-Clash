extends Control

# ตัวแปรสำหรับนับว่าตอนนี้กำลังตั้งค่าของผู้เล่นคนที่เท่าไหร่ เริ่มต้นที่ 1
var current_player_index: int = 1

# จำนวนผู้เล่นทั้งหมด ดึงมาจาก Global
var total_players: int = 1

#อ้างอิงไปยัง Label ที่ใช้แสดงข้อความ
@onready var player_label: Label = $Label_current_player
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#ดึงค่าจำนวนผู้เล่นที่เบือกไว้จาก Global
	if Global.player_count:
		total_players = Global.player_count
	else:
		total_players = 1
	update_ui()

# ฟังก์ชันสำหรับการอัปเดตหน้า ui 
func update_ui() -> void:
	player_label.text = "Player " + str(current_player_index)
	
	#อาจจะมีการดึง avatar ที่เลือกไว้
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# ฟังก์ชันการทำงานของปุ่ม back
func _on_backbtn_pressed() -> void:
	if current_player_index > 1:
		current_player_index -= 1
		update_ui()
	else:
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
	
# ฟังก์ชันการทำงานของปุ่ม Okay
func _on_okay_btn_pressed() -> void:
		#โค้ดบันทึกค่า Avatar
	
	if current_player_index < total_players:
		current_player_index += 1
		update_ui()
	else:
		get_tree().change_scene_to_file("res://ui/AddbotMenu.tscn")

extends Control

# อ้างอิงไปยังปุ่มที่ต้องการปรับค่า
@onready var add_two_btn: Button = $VBoxContainer/addTwo
@onready var add_three_btn: Button = $VBoxContainer/addThree

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# ดึงค่าจำนวนผู้เล่นมาจาก Global
	var players = Global.player_count
	if players == 2:
		add_three_btn.hide()
	
	if players == 3:
		add_three_btn.hide()
		add_two_btn.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_no_add_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/ShowAvatar.tscn")


func _on_add_one_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/ShowAvatar.tscn")


func _on_add_two_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/ShowAvatar.tscn")


func _on_add_three_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/ShowAvatar.tscn")


func _on_backbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/AvatarMenu.tscn")

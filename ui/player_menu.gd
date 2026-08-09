extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_one_player_pressed() -> void:
	Global.setup_players(1)
	get_tree().change_scene_to_file("res://ui/AvatarMenu.tscn")


func _on_two_players_pressed() -> void:
	Global.setup_players(2)
	get_tree().change_scene_to_file("res://ui/AvatarMenu.tscn")


func _on_tree_players_pressed() -> void:
	Global.setup_players(3)
	get_tree().change_scene_to_file("res://ui/AvatarMenu.tscn")


func _on_four_players_pressed() -> void:
	Global.setup_players(4)
	get_tree().change_scene_to_file("res://ui/AvatarMenu.tscn")


func _on_backbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

extends Control

const SAVE_SLOT_MENU_SCENE = preload("res://ui/save_slot_menu.tscn")
const SETTINGS_MENU_SCENE = preload("res://ui/settings_menu.tscn")

@onready var main_buttons: VBoxContainer = $VBoxContainer

var save_slot_menu: SaveSlotMenu
var settings_menu: SettingsMenu

func _ready() -> void:
	save_slot_menu = SAVE_SLOT_MENU_SCENE.instantiate() as SaveSlotMenu
	add_child(save_slot_menu)
	save_slot_menu.closed.connect(_on_save_menu_closed)
	save_slot_menu.load_requested.connect(_on_load_requested)
	settings_menu = SETTINGS_MENU_SCENE.instantiate() as SettingsMenu
	add_child(settings_menu)
	settings_menu.closed.connect(_on_settings_closed)


func _on_startgame_btn_pressed() -> void:
	SaveManager.start_new_game()
	get_tree().change_scene_to_file("res://ui/PlayerMenu.tscn")


func _on_options_btn_button_up() -> void:
	main_buttons.hide()
	save_slot_menu.open_menu(SaveSlotMenu.MenuMode.LOAD)

func _on_settings_btn_pressed() -> void:
	main_buttons.hide()
	settings_menu.open_menu()


func _on_save_menu_closed() -> void:
	main_buttons.show()

func _on_settings_closed() -> void:
	main_buttons.show()


func _on_load_requested(_slot: int) -> void:
	get_tree().change_scene_to_file("res://locations/NewMap.tscn")


func _on_exit_btn_pressed() -> void:
	get_tree().quit()

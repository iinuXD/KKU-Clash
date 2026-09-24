extends Control

signal resume_requested
signal main_menu_requested

@onready var resume_button: Button = $Panel/Buttons/ResumeButton
@onready var main_menu_button: Button = $Panel/Buttons/MainMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	hide()

func open_menu() -> void:
	show()
	resume_button.grab_focus()

func close_menu() -> void:
	hide()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

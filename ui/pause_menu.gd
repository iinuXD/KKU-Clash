extends Control

signal resume_requested
signal settings_requested
signal save_requested
signal quit_requested

@onready var resume_button: Button = $Panel/Buttons/ResumeButton
@onready var settings_button: Button = $Panel/Buttons/SettingsButton
@onready var save_button: Button = $Panel/Buttons/SaveButton
@onready var quit_button: Button = $Panel/Buttons/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_button.pressed.connect(_on_save_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	hide()

func open_menu() -> void:
	show()
	resume_button.grab_focus()

func close_menu() -> void:
	hide()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()

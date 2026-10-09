extends Control

signal choice_made(choice: String)

@onready var subject_label: Label = %SubjectLabel
@onready var time_label: Label = %TimeLabel
@onready var status_label: Label = %StatusLabel
@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton

var primary_choice: String = "close"


func _ready() -> void:
	hide()
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)


func open_class_info(
	subject_name: String,
	class_time: String,
	status_text: String,
	primary_text: String,
	choice: String,
	show_cancel: bool = true,
	status_color: Color = Color("#78301f")
) -> void:
	subject_label.text = subject_name
	time_label.text = class_time
	status_label.text = status_text
	status_label.add_theme_color_override("font_color", status_color)
	primary_button.text = primary_text
	primary_choice = choice
	secondary_button.visible = show_cancel
	show()
	primary_button.grab_focus()


func _on_primary_pressed() -> void:
	hide()
	choice_made.emit(primary_choice)


func _on_secondary_pressed() -> void:
	hide()
	choice_made.emit("cancel")

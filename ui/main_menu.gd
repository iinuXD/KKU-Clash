extends Control

const SAVE_SLOT_MENU_SCENE = preload("res://ui/save_slot_menu.tscn")
const SETTINGS_MENU_SCENE = preload("res://ui/settings_menu.tscn")

@onready var main_buttons: VBoxContainer = $VBoxContainer

var save_slot_menu: SaveSlotMenu
var settings_menu: SettingsMenu
var leaderboard_overlay: Control

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

func _on_leaderboard_btn_pressed() -> void:
	main_buttons.hide()
	_build_leaderboard_overlay()

func _build_leaderboard_overlay() -> void:
	if leaderboard_overlay:
		leaderboard_overlay.queue_free()

	leaderboard_overlay = Control.new()
	leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leaderboard_overlay.z_index = 1100
	add_child(leaderboard_overlay)

	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.06, 0.84)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leaderboard_overlay.add_child(background)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300.0
	panel.offset_top = -250.0
	panel.offset_right = 300.0
	panel.offset_bottom = 250.0
	panel.add_theme_stylebox_override("panel", _make_leaderboard_panel_style())
	leaderboard_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var title := Label.new()
	title.text = "TOP 10 HIGHEST SCORES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffd77a"))
	title.add_theme_font_size_override("font_size", 25)
	content.add_child(title)

	var entries := LeaderboardManager.get_entries()
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "ยังไม่มีคะแนน"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("#e6e8ef"))
		content.add_child(empty_label)
	else:
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			var score_label := Label.new()
			score_label.text = "%2d. %-12s %4d / 3000" % [
				index + 1,
				str(entry.get("name", "ผู้เล่น")),
				int(entry.get("score", 0))
			]
			score_label.add_theme_color_override("font_color", Color("#e6e8ef"))
			score_label.add_theme_font_size_override("font_size", 17)
			content.add_child(score_label)

	var close_button := Button.new()
	close_button.text = "BACK"
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.pressed.connect(_close_leaderboard)
	content.add_child(close_button)
	close_button.grab_focus()

func _close_leaderboard() -> void:
	if leaderboard_overlay:
		leaderboard_overlay.queue_free()
		leaderboard_overlay = null
	main_buttons.show()

func _make_leaderboard_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#141a29")
	style.border_color = Color("#d99a43")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	return style


func _on_load_requested(_slot: int) -> void:
	get_tree().change_scene_to_file("res://locations/NewMap.tscn")


func _on_exit_btn_pressed() -> void:
	get_tree().quit()

extends Control
class_name SettingsMenu

signal closed

const DISPLAY_SETTINGS_PATH := "user://display_settings.cfg"
const DISPLAY_MODE_WINDOWED := 0
const DISPLAY_MODE_FULLSCREEN := 1
const DISPLAY_MODE_BORDERLESS := 2

var volume_slider: HSlider
var volume_value: Label
var display_mode_option: OptionButton
var load_saved_display_settings := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1100
	if load_saved_display_settings:
		_load_display_settings()
	_build_interface()
	hide()

func open_menu() -> void:
	volume_slider.value = AudioManager.get_music_volume() * 100.0
	_update_volume_label(volume_slider.value)
	display_mode_option.select(_get_current_display_mode())
	show()
	volume_slider.grab_focus()

func close_menu() -> void:
	hide()
	closed.emit()

func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.12, 0.055, 0.025, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260.0
	panel.offset_top = -220.0
	panel.offset_right = 260.0
	panel.offset_bottom = 220.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	for setting in [
		["margin_left", 28],
		["margin_top", 24],
		["margin_right", 28],
		["margin_bottom", 24]
	]:
		margin.add_theme_constant_override(setting[0], setting[1])
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := Label.new()
	title.text = "ตั้งค่า"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#5f2418"))
	title.add_theme_font_size_override("font_size", 34)
	content.add_child(title)

	var music_label := Label.new()
	music_label.text = "เสียงเพลง"
	music_label.add_theme_color_override("font_color", Color("#4b2418"))
	music_label.add_theme_font_size_override("font_size", 22)
	content.add_child(music_label)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	content.add_child(volume_row)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(volume_slider)

	volume_value = Label.new()
	volume_value.custom_minimum_size = Vector2(52, 0)
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_value.add_theme_color_override("font_color", Color("#a33f23"))
	volume_value.add_theme_font_size_override("font_size", 20)
	volume_row.add_child(volume_value)

	var display_label := Label.new()
	display_label.text = "รูปแบบหน้าจอ"
	display_label.add_theme_color_override("font_color", Color("#4b2418"))
	display_label.add_theme_font_size_override("font_size", 22)
	content.add_child(display_label)

	display_mode_option = OptionButton.new()
	display_mode_option.add_item("หน้าต่าง", DISPLAY_MODE_WINDOWED)
	display_mode_option.add_item("เต็มจอ", DISPLAY_MODE_FULLSCREEN)
	display_mode_option.add_item("ไร้ขอบ", DISPLAY_MODE_BORDERLESS)
	display_mode_option.custom_minimum_size = Vector2(0, 42)
	display_mode_option.item_selected.connect(_on_display_mode_selected)
	content.add_child(display_mode_option)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var music_credit := Label.new()
	music_credit.text = "เพลงประกอบโดย Dmitrii Kolesnikov จาก Pixabay"
	music_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	music_credit.add_theme_color_override("font_color", Color("#6f5e50"))
	music_credit.add_theme_font_size_override("font_size", 15)
	content.add_child(music_credit)

	var close_button := Button.new()
	close_button.text = "กลับ"
	close_button.custom_minimum_size = Vector2(0, 50)
	close_button.add_theme_font_size_override("font_size", 21)
	close_button.add_theme_color_override("font_color", Color("#451a10"))
	close_button.add_theme_color_override("font_hover_color", Color("#451a10"))
	close_button.add_theme_stylebox_override("normal", _make_button_style(Color("#d98b63"), Color("#78301f")))
	close_button.add_theme_stylebox_override("hover", _make_button_style(Color("#f0aa79"), Color("#8f371f")))
	close_button.add_theme_stylebox_override("pressed", _make_button_style(Color("#c87550"), Color("#672619")))
	close_button.pressed.connect(close_menu)
	content.add_child(close_button)

func _on_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)
	_update_volume_label(value)

func _update_volume_label(value: float) -> void:
	if volume_value:
		volume_value.text = "%d%%" % int(value)

func _on_display_mode_selected(mode: int) -> void:
	_apply_display_mode(mode)
	_save_display_settings(mode)

func _get_current_display_mode() -> int:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return DISPLAY_MODE_BORDERLESS
	return DISPLAY_MODE_WINDOWED

func _apply_display_mode(mode: int) -> void:
	var is_borderless := mode == DISPLAY_MODE_BORDERLESS
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, is_borderless)
	if mode == DISPLAY_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _load_display_settings() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	var config := ConfigFile.new()
	if config.load(DISPLAY_SETTINGS_PATH) != OK:
		return
	var mode := clampi(int(config.get_value("display", "mode", DISPLAY_MODE_WINDOWED)), DISPLAY_MODE_WINDOWED, DISPLAY_MODE_BORDERLESS)
	_apply_display_mode(mode)

func _save_display_settings(mode: int) -> void:
	var config := ConfigFile.new()
	config.set_value("display", "mode", mode)
	var error := config.save(DISPLAY_SETTINGS_PATH)
	if error != OK:
		push_error("Unable to save display settings: %s" % error)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f7e8cd")
	style.border_color = Color("#78301f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.18, 0.07, 0.035, 0.34)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style

func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	return style

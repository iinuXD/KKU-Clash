extends Control
class_name SaveSlotMenu

signal closed
signal load_requested(slot: int)
signal save_completed(slot: int)

enum MenuMode { LOAD, SAVE }

var current_mode: MenuMode = MenuMode.LOAD
var pending_overwrite_slot: int = -1
var slot_buttons: Array[Button] = []
var title_label: Label
var subtitle_label: Label
var status_label: Label
var confirmation_layer: Control
var confirmation_message: Label
var confirmation_confirm_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	hide()


func open_menu(mode: MenuMode) -> void:
	current_mode = mode
	pending_overwrite_slot = -1
	if confirmation_layer:
		confirmation_layer.hide()
	title_label.text = "โหลดเกม" if mode == MenuMode.LOAD else "บันทึกเกม"
	subtitle_label.text = (
		"เลือกช่องเซฟที่ต้องการเล่นต่อ"
		if mode == MenuMode.LOAD
		else "บันทึกจากจุดสิ้นสุดเทิร์นล่าสุด"
	)
	status_label.text = ""
	_refresh_slots()
	show()
	if not slot_buttons.is_empty():
		slot_buttons[0].grab_focus()


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330.0
	panel.offset_top = -300.0
	panel.offset_right = 330.0
	panel.offset_bottom = 300.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("#ffd77a"))
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_color_override("font_color", Color("#c7cad4"))
	content.add_child(subtitle_label)

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 78)
		button.add_theme_font_size_override("font_size", 16)
		_apply_slot_button_style(button, false)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		content.add_child(button)
		slot_buttons.append(button)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#ffb38a"))
	content.add_child(status_label)

	var back_button := Button.new()
	back_button.text = "กลับ"
	back_button.custom_minimum_size = Vector2(0, 44)
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.add_theme_color_override("font_color", Color("#fff0cf"))
	back_button.add_theme_color_override("font_hover_color", Color.WHITE)
	back_button.add_theme_stylebox_override("normal", _make_button_style(Color("#562219"), Color("#d99a43")))
	back_button.add_theme_stylebox_override("hover", _make_button_style(Color("#7c301e"), Color("#ffc866")))
	back_button.add_theme_stylebox_override("pressed", _make_button_style(Color("#42170f"), Color("#d99a43")))
	back_button.pressed.connect(_close_menu)
	content.add_child(back_button)

	_build_overwrite_confirmation()


func _refresh_slots() -> void:
	var infos := SaveManager.get_all_slot_info()
	for index in range(slot_buttons.size()):
		var button := slot_buttons[index]
		var info: Dictionary = infos[index]
		var slot := index + 1
		var exists := bool(info.get("exists", false))
		var valid := bool(info.get("valid", true))
		button.disabled = current_mode == MenuMode.LOAD and (not exists or not valid)
		_apply_slot_button_style(button, SaveManager.active_slot == slot)

		if not exists:
			button.text = "ช่อง %d\n— ว่าง —" % slot
		elif not valid:
			button.text = "ช่อง %d\nไฟล์เซฟอ่านไม่ได้" % slot
		else:
			var active_text := "  •  ช่องปัจจุบัน" if SaveManager.active_slot == slot else ""
			button.text = "ช่อง %d%s\nวันที่ %d/%d  •  ผู้เล่น %d/%d  •  %s\nบันทึกล่าสุด %s" % [
				slot,
				active_text,
				int(info.get("round", 1)),
				int(info.get("max_rounds", 11)),
				int(info.get("current_player", 1)),
				int(info.get("player_count", 1)),
				_format_game_time(int(info.get("minutes", 360))),
				_format_saved_at(str(info.get("saved_at", "")))
			]


func _on_slot_pressed(slot: int) -> void:
	status_label.text = ""
	var info := SaveManager.get_slot_info(slot)
	if current_mode == MenuMode.LOAD:
		if not info.get("exists", false) or not info.get("valid", false):
			status_label.text = str(info.get("error", "ไม่สามารถโหลดช่องนี้ได้"))
			return
		if SaveManager.prepare_load(slot):
			load_requested.emit(slot)
		else:
			status_label.text = SaveManager.last_error
		return

	if info.get("exists", false) and slot != SaveManager.active_slot:
		pending_overwrite_slot = slot
		confirmation_message.text = "ช่อง %d มีข้อมูลอยู่แล้ว\nต้องการเขียนทับไฟล์นี้หรือไม่?" % slot
		confirmation_layer.show()
		confirmation_confirm_button.grab_focus()
		return
	_perform_save(slot)


func _on_overwrite_confirmed() -> void:
	if pending_overwrite_slot < 1:
		return
	confirmation_layer.hide()
	var slot := pending_overwrite_slot
	pending_overwrite_slot = -1
	_perform_save(slot)


func _on_overwrite_canceled() -> void:
	pending_overwrite_slot = -1
	confirmation_layer.hide()


func _perform_save(slot: int) -> void:
	if SaveManager.save_checkpoint(slot):
		status_label.text = "บันทึกช่อง %d เรียบร้อย" % slot
		_refresh_slots()
		save_completed.emit(slot)
		await get_tree().create_timer(0.45).timeout
		_close_menu()
	else:
		status_label.text = SaveManager.last_error


func _close_menu() -> void:
	if confirmation_layer:
		confirmation_layer.hide()
	pending_overwrite_slot = -1
	hide()
	closed.emit()


func _format_game_time(total_minutes: int) -> String:
	var hour := int(total_minutes / 60) % 24
	var minute := total_minutes % 60
	var meridiem := "AM" if hour < 12 else "PM"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, meridiem]


func _format_saved_at(value: String) -> String:
	if value.is_empty():
		return "ไม่ทราบเวลา"
	return value.replace("T", "  ")


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#141a29")
	style.border_color = Color("#d99a43")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	return style


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _apply_slot_button_style(button: Button, is_active: bool) -> void:
	if is_active:
		button.add_theme_color_override("font_color", Color("#fff0cf"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _make_button_style(Color("#6f2b1d"), Color("#d99a43")))
		button.add_theme_stylebox_override("hover", _make_button_style(Color("#913b25"), Color("#ffc866")))
		button.add_theme_stylebox_override("pressed", _make_button_style(Color("#542116"), Color("#d99a43")))
	else:
		button.add_theme_color_override("font_color", Color("#e6e8ef"))
		button.add_theme_color_override("font_hover_color", Color("#fff0cf"))
		button.add_theme_stylebox_override("normal", _make_button_style(Color("#20283b"), Color("#58647d")))
		button.add_theme_stylebox_override("hover", _make_button_style(Color("#2d3851"), Color("#d99a43")))
		button.add_theme_stylebox_override("pressed", _make_button_style(Color("#182033"), Color("#ffc866")))
	button.add_theme_color_override("font_disabled_color", Color("#8991a3"))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color("#252b38"), Color("#454d60")))


func _build_overwrite_confirmation() -> void:
	confirmation_layer = Control.new()
	confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.z_index = 20
	confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirmation_layer)

	var blocker := ColorRect.new()
	blocker.color = Color(0.02, 0.03, 0.06, 0.62)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_layer.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -270.0
	panel.offset_top = -145.0
	panel.offset_right = 270.0
	panel.offset_bottom = 145.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	confirmation_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = "ยืนยันการเขียนทับ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("#ffd77a"))
	heading.add_theme_font_size_override("font_size", 25)
	content.add_child(heading)

	var divider := HSeparator.new()
	divider.modulate = Color("#d99a43")
	content.add_child(divider)

	confirmation_message = Label.new()
	confirmation_message.custom_minimum_size = Vector2(0, 92)
	confirmation_message.text = "ช่องนี้มีข้อมูลอยู่แล้ว\nต้องการเขียนทับไฟล์นี้หรือไม่?"
	confirmation_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirmation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_message.add_theme_color_override("font_color", Color("#e6e8ef"))
	confirmation_message.add_theme_font_size_override("font_size", 18)
	content.add_child(confirmation_message)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	content.add_child(buttons)

	var cancel_button := Button.new()
	cancel_button.text = "ยกเลิก"
	cancel_button.custom_minimum_size = Vector2(170, 50)
	_apply_confirmation_button_style(cancel_button, false)
	cancel_button.pressed.connect(_on_overwrite_canceled)
	buttons.add_child(cancel_button)

	confirmation_confirm_button = Button.new()
	confirmation_confirm_button.text = "เขียนทับ"
	confirmation_confirm_button.custom_minimum_size = Vector2(170, 50)
	_apply_confirmation_button_style(confirmation_confirm_button, true)
	confirmation_confirm_button.pressed.connect(_on_overwrite_confirmed)
	buttons.add_child(confirmation_confirm_button)

	confirmation_layer.hide()


func _apply_confirmation_button_style(button: Button, primary: bool) -> void:
	var text_color := Color("#fff0cf")
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, text_color)
	if primary:
		button.add_theme_stylebox_override("normal", _make_button_style(Color("#6f2b1d"), Color("#d99a43")))
		button.add_theme_stylebox_override("hover", _make_button_style(Color("#913b25"), Color("#ffc866")))
		button.add_theme_stylebox_override("pressed", _make_button_style(Color("#542116"), Color("#d99a43")))
	else:
		button.add_theme_stylebox_override("normal", _make_button_style(Color("#20283b"), Color("#58647d")))
		button.add_theme_stylebox_override("hover", _make_button_style(Color("#2d3851"), Color("#d99a43")))
		button.add_theme_stylebox_override("pressed", _make_button_style(Color("#182033"), Color("#ffc866")))

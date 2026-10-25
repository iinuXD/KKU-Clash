extends Control

signal activity_chosen(activity_name)

@onready var title_label: Label = $BgFrame/TitleLabel
@onready var btn_container: GridContainer = $BgFrame/ButtonsCenter/GridContainer
@onready var close_btn: Button = $BgFrame/CloseButton
@onready var place_image: TextureRect = $BgFrame/LeftImage
@onready var bg_frame: Panel = $BgFrame

var hover_label: Label
var idle_tweens: Array[Tween] = []
var current_place := ""
var is_resolving := false
var choice_emitted := false
var selection_tween: Tween

var activity_data = {
	"Dorm": {"title": "หอพัก", "img": "pxdorm.png"},
	"Food": {"title": "โรงอาหาร", "img": "pxfood.png"},
	"Library": {"title": "หอสมุด", "img": "pxlibrary.png"},
	"Shop": {"title": "ร้านค้า", "img": "pxshop.png"},
	"Hospital": {"title": "โรงพยาบาล", "img": "pxhospital.png"},
	"Sport": {"title": "สนามกีฬา", "img": "pxsport.png"},
	"Fun": {"title": "สถานบันเทิง", "img": "pxfun.png"},
	"Learn": {"title": "ตึกเรียน", "img": "pxlearn.png"}
}

# จับคู่ชื่อกิจกรรมจริงใน new_map.gd กับไฟล์ไอคอน
var activity_icons = {
	"Dorm": {
		"นอนพัก": "sleep.png", "อ่านหนังสือ": "read.png", "จบเทิร์น": "finish.png"
	},
	"Library": {
		"อ่านหนังสือ": "read.png", "ยืมหนังสือ": "borrow.png", "นั่งเล่น": "relax.png"
	},
	"Food": {
		"กินข้าวจานธรรมดา": "normal.png", "กินข้าวจานพิเศษ": "special.png",
		"กินของทานเล่น": "snack.png", "ทำ Parttime": "parttime.png"
	},
	"Shop": {
		"ซื้อกาแฟ": "coffee.png", "ซื้อขนม": "snack.png", "ซื้อยา": "medicine.png",
		"ทำ Parttime": "parttime.png"
	},
	"Hospital": {
		"เข้ารับการรักษา": "treatment.png", "ซื้อยา": "medicine.png", "ตรวจสุขภาพ": "health.png"
	},
	"Sport": {
		"วิ่ง": "run.png", "เล่นกีฬา": "sport.png", "ออกกำลังกาย": "exercise.png"
	},
	"Fun": {
		"ร้องคาราโอเกะ": "sing.png", "ปาร์ตี้": "party.png", "ทำ Parttime": "parttime.png"
	}
}

func _ready() -> void:
	hide()
	_setup_hover_label()
	close_btn.pressed.connect(_on_close_pressed)

func _process(_delta: float) -> void:
	if hover_label and hover_label.visible:
		hover_label.global_position = get_global_mouse_position() + Vector2(15, 15)

func open_popup(place_name: String, _player_index: int, place_effects: Dictionary = {}) -> void:
	if selection_tween and selection_tween.is_valid():
		selection_tween.kill()
	is_resolving = false
	choice_emitted = false
	close_btn.disabled = false
	current_place = place_name
	var data = activity_data.get(place_name, {"title": "สถานที่", "img": "pxdorm.png"})
	title_label.text = data.get("title", "สถานที่")

	var image_path = "res://asset/activities/" + data.get("img", "pxdorm.png")
	if ResourceLoader.exists(image_path):
		place_image.texture = load(image_path)
	elif ResourceLoader.exists("res://asset/activities/pxdorm.png"):
		place_image.texture = load("res://asset/activities/pxdorm.png")

	_clear_activity_cards()
	var options = place_effects.keys()
	for i in range(options.size()):
		var action_name: String = str(options[i])
		_create_activity_card(action_name, place_effects[action_name], i)

	show()
	_play_popup_animation()

func _create_activity_card(action_name: String, effects: Dictionary, index: int) -> void:
	# Card เป็นลูกของ GridContainer จึงต้องอยู่นิ่งเสมอ
	# Animation จะทำเฉพาะ icon_button ที่อยู่ใน wrapper เท่านั้น
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(176, 158)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 4)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	btn_container.add_child(card)

	var icon_wrapper := Control.new()
	icon_wrapper.custom_minimum_size = Vector2(176, 116)
	icon_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon_wrapper)

	var icon_button := TextureButton.new()
	icon_button.position = Vector2(25,0)
	icon_button.size = Vector2(126, 116)
	icon_button.ignore_texture_size = true
	icon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_button.focus_mode = Control.FOCUS_NONE
	icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_button.tooltip_text = ""
	icon_button.pivot_offset = Vector2(63, 58)

	var icon_path = _get_icon_path(current_place, action_name)
	if ResourceLoader.exists(icon_path):
		icon_button.texture_normal = load(icon_path)

	icon_wrapper.add_child(icon_button)

	var label := Label.new()
	label.text = action_name
	label.custom_minimum_size = Vector2(176, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("6b3421"))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)

	card.set_meta("hover_text", _generate_hover_text(effects))
	card.set_meta("activity_name", action_name)
	icon_button.pressed.connect(_on_activity_pressed.bind(icon_button, action_name))
	icon_button.mouse_entered.connect(_on_card_hover.bind(card, icon_button))
	icon_button.mouse_exited.connect(_on_card_exit.bind(icon_button))

	# ขยับเฉพาะรูปไอคอนขึ้น-ลง ไม่แตะตำแหน่งของ card/Grid
	_start_idle_animation(icon_button, index * 0.16)

func _get_icon_path(place_name: String, action_name: String) -> String:
	var folder = place_name.to_lower()
	var filename = activity_icons.get(place_name, {}).get(action_name, "")
	if filename == "":
		return ""
	return "res://asset/activity_icons/%s/%s" % [folder, filename]

func _clear_activity_cards() -> void:
	for tween in idle_tweens:
		if tween and tween.is_valid():
			tween.kill()
	idle_tweens.clear()
	for child in btn_container.get_children():
		btn_container.remove_child(child)
		child.queue_free()

func _start_idle_animation(icon: Control, delay: float) -> void:
	var base_y := icon.position.y
	var tween = create_tween().set_loops()
	idle_tweens.append(tween)
	if delay > 0.0:
		tween.tween_interval(delay)

	# ขึ้น-ลงอย่างเดียว ไม่มี rotation และไม่ขยับ Card ที่ GridContainer จัดตำแหน่ง
	tween.tween_property(icon, "position:y", base_y - 3.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon, "position:y", base_y + 3.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon, "position:y", base_y, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_card_hover(card: Control, icon: Control) -> void:
	if card.has_meta("hover_text"):
		hover_label.text = str(card.get_meta("hover_text"))
		hover_label.show()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(icon, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "modulate", Color(1.08, 1.08, 1.08, 1), 0.12)

func _on_card_exit(icon: Control) -> void:
	hover_label.hide()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "modulate", Color.WHITE, 0.14)

func _on_activity_pressed(icon: Control, action_name: String) -> void:
	if is_resolving or choice_emitted or not visible:
		return
	is_resolving = true
	close_btn.disabled = true
	for card in btn_container.get_children():
		var button := card.get_child(0).get_child(0) as BaseButton
		if button:
			button.disabled = true
	hover_label.hide()
	selection_tween = create_tween()
	selection_tween.tween_property(icon, "scale", Vector2(0.90, 0.90), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	selection_tween.tween_property(icon, "scale", Vector2(1.06, 1.06), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	selection_tween.tween_callback(_finish_activity.bind(action_name))

func _finish_activity(action_name: String) -> void:
	if choice_emitted or not is_resolving or not visible:
		return
	choice_emitted = true
	hide()
	activity_chosen.emit(action_name)

func _play_popup_animation() -> void:
	bg_frame.pivot_offset = bg_frame.size / 2.0
	bg_frame.scale = Vector2(0.94, 0.94)
	bg_frame.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bg_frame, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bg_frame, "modulate:a", 1.0, 0.14)

func _setup_hover_label() -> void:
	hover_label = Label.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("f7e8cd")
	style.border_color = Color("78301f")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	hover_label.add_theme_stylebox_override("normal", style)
	hover_label.add_theme_color_override("font_color", Color("4b1d13"))
	hover_label.add_theme_font_size_override("font_size", 15)
	hover_label.z_index = 100
	hover_label.hide()
	add_child(hover_label)

func _generate_hover_text(effects: Dictionary) -> String:
	if effects.is_empty():
		return "จบเทิร์นปัจจุบัน"
	var text := ""
	var th_names = {
		"money": "เงิน", "study": "ความรู้", "happiness": "ความสุข",
		"hunger": "ความอิ่ม", "stamina": "พลังงาน"
	}
	for key in effects:
		var val = effects[key]
		var sign_str = "+" if val > 0 else ""
		text += th_names.get(key, key) + " " + sign_str + str(val) + "\n"
	return text.strip_edges()

func _on_close_pressed() -> void:
	if is_resolving or choice_emitted or not visible:
		return
	is_resolving = true
	choice_emitted = true
	hover_label.hide()
	hide()
	activity_chosen.emit("ยกเลิก (ไม่ทำกิจกรรม)")

extends Control

signal demo_finished

@onready var dim_bg: ColorRect = %DimBg
@onready var cards_layer: Control = %CardsLayer
@onready var hint_label: Label = %HintLabel
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_title: Label = %DetailTitle
@onready var detail_description: Label = %DetailDescription
@onready var detail_effects: VBoxContainer = %DetailEffects
@onready var detail_confirm: Button = %DetailConfirm

const DATA_PATH := "res://data/random_events.json"
const CARD_SIZE := Vector2(280, 390)

var events_db: Array = []
var cards: Array[Panel] = []
var selected_events: Array = []
var opened: Array[bool] = []
var current_detail_index := -1
var busy := false


func _ready() -> void:
	_load_database()
	detail_panel.hide()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F7:
			show_random_events(1)
		elif event.keycode == KEY_F8:
			show_random_events(2)
		elif event.keycode == KEY_F9:
			show_random_events(3)


func _load_database() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("RandomEventPopup: ไม่พบ " + DATA_PATH)
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		events_db = json.data.get("events", [])


func show_random_events(amount: int = 3) -> void:
	if events_db.is_empty() or busy:
		return

	amount = clampi(amount, 1, 3)
	selected_events = events_db.duplicate(true)
	selected_events.shuffle()
	selected_events = selected_events.slice(0, min(amount, selected_events.size()))

	opened.clear()
	for i in selected_events.size():
		opened.append(false)

	_clear_cards()
	show()
	detail_panel.hide()
	hint_label.text = "เลือกการ์ดที่ต้องการเปิด"

	await get_tree().process_frame
	_create_cards()
	await _deal_cards()


func _clear_cards() -> void:
	for child in cards_layer.get_children():
		child.queue_free()
	cards.clear()


func _create_cards() -> void:
	for i in selected_events.size():
		var card := _make_card(selected_events[i], i)
		cards_layer.add_child(card)
		cards.append(card)

		card.position = Vector2(
			cards_layer.size.x / 2.0 - CARD_SIZE.x / 2.0,
			cards_layer.size.y / 2.0 - CARD_SIZE.y / 2.0
		)
		card.scale = Vector2(0.82, 0.82)
		card.modulate.a = 0.0


func _make_card(data: Dictionary, index: int) -> Panel:
	# สำคัญ: ใช้ Panel ธรรมดาแทน PanelContainer
	# เพื่อไม่ให้ minimum size ของ Label/Button ดันความสูงการ์ดเอง
	var card := Panel.new()
	card.set_deferred("size", CARD_SIZE)
	card.custom_minimum_size = Vector2.ZERO
	card.pivot_offset = CARD_SIZE / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3f3028")
	style.border_color = Color("#f0d39a")
	style.set_border_width_all(6)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(6, 8)
	card.add_theme_stylebox_override("panel", style)

	# ---------- BACK ----------
	var back := Control.new()
	back.name = "Back"
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back)

	var star := Label.new()
	star.text = "✦"
	star.position = Vector2(20, 66)
	star.size = Vector2(240, 55)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.add_theme_font_size_override("font_size", 44)
	star.add_theme_color_override("font_color", Color("#ffe9b7"))
	back.add_child(star)

	var question := Label.new()
	question.text = "?"
	question.position = Vector2(20, 118)
	question.size = Vector2(240, 120)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 96)
	question.add_theme_color_override("font_color", Color("#ffe9b7"))
	back.add_child(question)

	var random_text := Label.new()
	random_text.text = "RANDOM EVENT"
	random_text.position = Vector2(20, 246)
	random_text.size = Vector2(240, 32)
	random_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	random_text.add_theme_font_size_override("font_size", 18)
	random_text.add_theme_color_override("font_color", Color("#ffe9b7"))
	back.add_child(random_text)

	var open_text := Label.new()
	open_text.text = "กดเพื่อเปิด"
	open_text.position = Vector2(20, 286)
	open_text.size = Vector2(240, 30)
	open_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	open_text.add_theme_font_size_override("font_size", 16)
	open_text.add_theme_color_override("font_color", Color("#ffe9b7"))
	back.add_child(open_text)

	# ---------- FRONT ----------
	var front := Control.new()
	front.name = "Front"
	front.visible = false
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(front)

	# Image area: fixed rectangle. It can never increase card height.
	var image_box := Panel.new()
	image_box.position = Vector2(16, 16)
	image_box.size = Vector2(248, 178)
	image_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image_style := StyleBoxFlat.new()
	image_style.bg_color = Color("#f5ead4")
	image_style.border_color = Color("#d8c5a5")
	image_style.set_border_width_all(3)
	image_style.set_corner_radius_all(12)
	image_box.add_theme_stylebox_override("panel", image_style)
	front.add_child(image_box)

	var image_label := Label.new()
	image_label.text = "พื้นที่ภาพ Event"
	image_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	image_label.add_theme_font_size_override("font_size", 15)
	image_label.add_theme_color_override("font_color", Color("#806f61"))
	image_box.add_child(image_label)

	var title := Label.new()
	title.text = data.get("title", "เหตุการณ์สุ่ม")
	title.position = Vector2(16, 204)
	title.size = Vector2(248, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#fff4d7"))
	front.add_child(title)

	var desc := Label.new()
	desc.text = data.get("description", "")
	desc.position = Vector2(20, 248)
	desc.size = Vector2(240, 62)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color("#fff4d7"))
	front.add_child(desc)

	var button := Button.new()
	button.text = "ดูรายละเอียด"
	button.position = Vector2(24, 322)
	button.size = Vector2(232, 48)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_show_detail.bind(index))
	front.add_child(button)

	card.gui_input.connect(_card_input.bind(index))
	card.mouse_entered.connect(_hover.bind(card, true))
	card.mouse_exited.connect(_hover.bind(card, false))

	return card


func _deal_cards() -> void:
	busy = true

	var count: int = cards.size()
	var available_width: float = cards_layer.size.x
	var available_height: float = cards_layer.size.y

	# เผื่อขอบสำหรับ rotation + hover
	var safe_gap: float = 26.0
	var total_cards_width: float = CARD_SIZE.x * float(count)
	var gap: float = 0.0

	if count > 1:
		gap = min(
			34.0,
			max(
				12.0,
				(available_width - total_cards_width - safe_gap * 2.0) / float(count - 1)
			)
		)

	var group_width: float = total_cards_width + gap * float(max(0, count - 1))
	var start_x: float = (available_width - group_width) / 2.0

	# วางสูงกว่ากึ่งกลางเล็กน้อย เพื่อเหลือพื้นที่ Hint ด้านล่าง
	var target_y: float = max(
		12.0,
		(available_height - CARD_SIZE.y) / 2.0 - 8.0
	)

	for i in count:
		var c := cards[i]
		var target := Vector2(start_x + i * (CARD_SIZE.x + gap), target_y)

		var angle := 0.0
		if count == 2:
			angle = -2.0 if i == 0 else 2.0
		elif count == 3:
			angle = [-3.0, 0.0, 3.0][i]

		var tw := create_tween()
		tw.tween_interval(i * 0.10)
		tw.set_parallel(true)
		tw.tween_property(c, "position", target, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation_degrees", angle, 0.34)
		tw.tween_property(c, "scale", Vector2.ONE, 0.34)
		tw.tween_property(c, "modulate:a", 1.0, 0.18)

	await get_tree().create_timer(0.58).timeout
	busy = false


func _card_input(event: InputEvent, index: int) -> void:
	if busy or opened[index]:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_flip_card(index)


func _flip_card(index: int) -> void:
	if busy or opened[index]:
		return

	busy = true
	var c := cards[index]
	c.z_index = 10

	var tw := create_tween()
	tw.tween_property(c, "scale:x", 0.04, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	c.find_child("Back", true, false).visible = false
	c.find_child("Front", true, false).visible = true
	opened[index] = true

	var style := c.get_theme_stylebox("panel").duplicate()
	var kind: String = selected_events[index].get("type", "negative")

	if kind == "positive":
		style.bg_color = Color("#245c45")
		style.border_color = Color("#83b99a")
	else:
		style.bg_color = Color("#9a4728")
		style.border_color = Color("#e7a06f")

	c.add_theme_stylebox_override("panel", style)

	var op := create_tween()
	op.tween_property(c, "scale:x", 1.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await op.finished

	c.z_index = 0
	busy = false
	if _all_opened():
		hint_label.text = "เปิดครบทุกใบแล้ว — เลือกดูรายละเอียดของแต่ละเหตุการณ์ได้"
	else:
		hint_label.text = "เปิดใบอื่นต่อได้ หรือดูรายละเอียดของใบนี้"


func _show_detail(index: int) -> void:
	if busy or not opened[index]:
		return

	current_detail_index = index
	var data: Dictionary = selected_events[index]

	detail_title.text = data.get("title", "เหตุการณ์สุ่ม")
	detail_description.text = data.get("description", "")

	for child in detail_effects.get_children():
		child.queue_free()

	for effect in data.get("effects_text", []):
		var l := Label.new()
		l.text = "• " + str(effect)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color("#5b3a2a"))
		detail_effects.add_child(l)

	detail_panel.show()
	detail_panel.modulate.a = 0.0
	detail_panel.scale = Vector2(0.92, 0.92)
	detail_panel.pivot_offset = detail_panel.size / 2.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(detail_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(detail_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_detail_confirm_pressed() -> void:
	if current_detail_index < 0:
		return

	detail_panel.hide()
	current_detail_index = -1

	if _all_opened():
		hint_label.text = "เปิดครบทุกใบแล้ว — สามารถดูรายละเอียดแต่ละใบได้"
	else:
		hint_label.text = "เลือกการ์ดใบต่อไปที่ต้องการเปิด"


func _all_opened() -> bool:
	for state in opened:
		if not state:
			return false
	return true


func _hover(card: Panel, hovering: bool) -> void:
	if busy:
		return

	var tw := create_tween()
	tw.tween_property(
		card,
		"scale",
		Vector2(1.018, 1.018) if hovering else Vector2.ONE,
		0.10
	)


func _on_close_pressed() -> void:
	hide()
	demo_finished.emit()

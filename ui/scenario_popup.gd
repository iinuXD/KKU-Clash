extends Control

signal scenario_resolved(effects)

@onready var dim_bg: ColorRect = $DimBg
@onready var bg_frame: Panel = $BgFrame
@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var vbox: VBoxContainer = %VBoxContainer
@onready var scenario_image: TextureRect = %ScenarioImage

var scenarios_db: Dictionary = {}
var current_scenario: Dictionary = {}
var is_resolving: bool = false


func _ready() -> void:
	hide()
	_load_scenarios()


func _load_scenarios() -> void:
	var file_path = "res://data/scenarios.json"
	if not FileAccess.file_exists(file_path):
		push_warning("ScenarioPopup: ไม่พบไฟล์ " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error == OK and json.data is Dictionary:
		scenarios_db = json.data
	else:
		push_warning("ScenarioPopup: อ่าน scenarios.json ไม่สำเร็จ")


# เช็คว่ามี Scenario ของสถานที่นี้หรือไม่ แล้วสุ่มมา 1 เหตุการณ์
func try_start_scenario(place_name: String) -> bool:
	if not scenarios_db.has(place_name):
		return false

	var place_scenarios = scenarios_db[place_name]
	if place_scenarios.is_empty():
		return false

	is_resolving = false
	current_scenario = place_scenarios.pick_random()

	title_label.text = current_scenario.get("title", "มีบางอย่างเกิดขึ้น...")
	desc_label.text = current_scenario.get("description", "")

	_load_scenario_image()

	# ล้าง Choice เดิมทันที เพื่อไม่ให้ปุ่มจาก Scenario ก่อนหน้าค้างอยู่
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

	var choices = current_scenario.get("choices", [])
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice.get("text", "ตัวเลือก %d" % (i + 1))
		btn.custom_minimum_size = Vector2(0, 70)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.94, 0.94)

		btn.pressed.connect(_on_choice_selected.bind(i, btn))
		btn.mouse_entered.connect(_on_choice_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_choice_hover.bind(btn, false))
		vbox.add_child(btn)

	show()

	# try_start_scenario ต้องคืนค่า true/false ทันที เพื่อให้ new_map.gd
	# เรียกใช้งานได้เหมือนเดิมโดยไม่ต้อง await
	_setup_and_play_animations.call_deferred()
	return true


func _setup_and_play_animations() -> void:
	# รอให้ Container จัด layout เสร็จในเฟรมถัดไปแล้วจึงตั้ง pivot/เล่น animation
	for child in vbox.get_children():
		if child is Button:
			child.pivot_offset = child.size * 0.5

	_play_open_animation()
	_play_choice_entrance()



func _load_scenario_image() -> void:
	scenario_image.texture = null

	var image_path: String = current_scenario.get("image", "")
	if image_path.is_empty():
		return

	if not ResourceLoader.exists(image_path):
		push_warning("ScenarioPopup: ไม่พบรูปภาพ " + image_path)
		return

	var texture = load(image_path)
	if texture is Texture2D:
		scenario_image.texture = texture
	else:
		push_warning("ScenarioPopup: ไฟล์รูปไม่ใช่ Texture2D " + image_path)

func _play_open_animation() -> void:
	dim_bg.modulate.a = 0.0
	bg_frame.modulate.a = 0.0
	bg_frame.scale = Vector2(0.92, 0.92)
	bg_frame.pivot_offset = bg_frame.size * 0.5

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_bg, "modulate:a", 1.0, 0.20)
	tween.tween_property(bg_frame, "modulate:a", 1.0, 0.18)
	tween.tween_property(bg_frame, "scale", Vector2(1.03, 1.03), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var settle = create_tween()
	settle.tween_interval(0.18)
	settle.tween_property(bg_frame, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_choice_entrance() -> void:
	var delay := 0.12
	for child in vbox.get_children():
		if child is Button:
			var btn: Button = child
			var tween = create_tween()
			tween.tween_interval(delay)
			tween.set_parallel(true)
			tween.tween_property(btn, "modulate:a", 1.0, 0.16)
			tween.tween_property(btn, "scale", Vector2.ONE, 0.18)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay += 0.07


func _on_choice_hover(btn: Button, hovering: bool) -> void:
	if is_resolving:
		return

	var target_scale = Vector2(1.035, 1.035) if hovering else Vector2.ONE
	var tween = create_tween()
	tween.tween_property(btn, "scale", target_scale, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_choice_selected(choice_index: int, btn: Button) -> void:
	if is_resolving:
		return
	is_resolving = true

	# ป้องกันการกด Choice อื่นซ้ำระหว่าง animation
	for child in vbox.get_children():
		if child is Button:
			child.disabled = true

	var click_tween = create_tween()
	click_tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.07)
	click_tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await click_tween.finished

	var effects = current_scenario["choices"][choice_index].get("effects", {})
	await _play_close_animation()
	hide()
	scenario_resolved.emit(effects)


func _play_close_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_bg, "modulate:a", 0.0, 0.16)
	tween.tween_property(bg_frame, "modulate:a", 0.0, 0.14)
	tween.tween_property(bg_frame, "scale", Vector2(0.96, 0.96), 0.14)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

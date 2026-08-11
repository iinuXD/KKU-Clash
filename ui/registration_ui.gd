extends Control

@onready var subject_inventory = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/SubjectInventory
@onready var timetable_grid = $MainPanel/MarginContainer/HBoxContainer/RightContent/TimetableGrid

func _ready():
	# 1. ตั้งค่า Drag (การดึง) ให้กับปุ่มรายวิชาทั้งหมดด้านล่าง
	for child in subject_inventory.get_children():
		if child is Button:
			child.set_drag_forwarding(_custom_get_drag_data.bind(child), _can_drop_data_dummy, _drop_data_dummy)
			
	# 2. ตั้งค่า Drop (การวาง) ให้กับช่องตารางเรียนทั้งหมด
	for child in timetable_grid.get_children():
		if child is Panel or child is PanelContainer:
			# กรองเฉพาะช่องตารางเรียน
			if child.name.begins_with("Cell_"):
				child.set_drag_forwarding(_get_drag_data_dummy, _custom_can_drop_data.bind(child), _custom_drop_data.bind(child))

# ==========================================
# ฟังก์ชันสำหรับการลาก (Drag)
# ==========================================
func _custom_get_drag_data(at_position: Vector2, button: Button) -> Variant:
	var preview_label = Label.new()
	preview_label.text = button.text
	preview_label.add_theme_color_override("font_color", Color(1, 1, 1))
	preview_label.add_theme_font_size_override("font_size", 16)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.8, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	
	var preview_panel = PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", style)
	preview_panel.custom_minimum_size = Vector2(130, 45)
	preview_panel.add_child(preview_label)
	
	var drag_control = Control.new()
	preview_panel.position = -preview_panel.custom_minimum_size / 2
	drag_control.add_child(preview_panel)
	
	button.set_drag_preview(drag_control)
	return button.text

# ==========================================
# ฟังก์ชันสำหรับการวาง (Drop)
# ==========================================
func _custom_can_drop_data(at_position: Vector2, data: Variant, panel: Control) -> bool:
	# ไม่อนุญาตให้วางข้อมูลลงในช่องที่ชื่อลงท้ายด้วย "3" (เช่น Cell_R1C3, Cell_R2C3)
	if panel.name.ends_with("3"):
		return false
		
	return typeof(data) == TYPE_STRING

func _custom_drop_data(at_position: Vector2, data: Variant, panel: Control) -> void:
	# ลบข้อมูลเก่าในช่องนี้ (ถ้ามี)
	for c in panel.get_children():
		c.queue_free()
		
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	
	var lbl = Label.new()
	lbl.text = data
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	lbl.add_theme_font_size_override("font_size", 14)
	
	center.add_child(lbl)
	panel.add_child(center)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.5, 0.2)
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	panel.add_theme_stylebox_override("panel", style)

# ==========================================
# ฟังก์ชัน Dummy สำหรับ Event ที่ไม่ได้ใช้
# ==========================================
func _get_drag_data_dummy(at_position: Vector2) -> Variant:
	return null

func _can_drop_data_dummy(at_position: Vector2, data: Variant) -> bool:
	return false

func _drop_data_dummy(at_position: Vector2, data: Variant) -> void:
	pass

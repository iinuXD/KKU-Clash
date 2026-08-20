extends Control

@onready var subject_inventory = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/SubjectInventory
@onready var timetable_grid = $MainPanel/MarginContainer/HBoxContainer/RightContent/TimetableGrid
@onready var confirm_button = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/ConfirmButton
@onready var return_button = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/ReturnButton
@onready var player_label = $MainPanel/MarginContainer/HBoxContainer/LeftMenu/Label

var current_player_index: int = 0
var total_players: int = 0 

# --- ตัวแปรเก็บ StyleBox เพื่อใช้งานซ้ำ (ประหยัดหน่วยความจำ) ---
var style_empty: StyleBoxFlat
var style_filled: StyleBoxFlat
var style_drag_preview: StyleBoxFlat

func _ready() -> void:
	_init_styles()
	
	total_players = max(1, Global.player_data.size())
	
	# 1. ตั้งค่า Drag ให้ปุ่มรายวิชา
	for child in subject_inventory.get_children():
		if child is Button:
			child.set_drag_forwarding(_custom_get_drag_data.bind(child), _can_drop_data_dummy, _drop_data_dummy)
			
	# 2. ตั้งค่า Drop และลบวิชา ให้ช่องตาราง (ใช้ฟังก์ชันตัวช่วย _get_all_cells)
	for cell in _get_all_cells():
		cell.set_meta("subject", "")
		cell.set_drag_forwarding(_get_drag_data_dummy, _custom_can_drop_data.bind(cell), _custom_drop_data.bind(cell))
		cell.gui_input.connect(_on_cell_gui_input.bind(cell))
				
	# 3. เชื่อมต่อปุ่ม
	if confirm_button: confirm_button.pressed.connect(_on_confirm_button_pressed)
	if return_button: return_button.pressed.connect(_on_return_button_pressed)

	_setup_turn()

# ==========================================
# ระบบเตรียม StyleBox พื้นฐาน (ทำงานแค่ครั้งเดียว)
# ==========================================
func _init_styles() -> void:
	style_empty = StyleBoxFlat.new()
	style_empty.bg_color = Color(1, 1, 1, 1)
	style_empty.border_width_left = 1
	style_empty.border_width_top = 1
	style_empty.border_width_right = 1
	style_empty.border_width_bottom = 1
	style_empty.border_color = Color(0.2, 0.2, 0.2, 1)
	
	style_filled = StyleBoxFlat.new()
	style_filled.bg_color = Color(1.0, 0.95, 0.9)
	style_filled.border_width_left = 2
	style_filled.border_width_top = 2
	style_filled.border_width_right = 2
	style_filled.border_width_bottom = 2
	style_filled.border_color = Color(0.9, 0.5, 0.2)
	style_filled.corner_radius_top_left = 8
	style_filled.corner_radius_top_right = 8
	style_filled.corner_radius_bottom_left = 8
	style_filled.corner_radius_bottom_right = 8
	
	style_drag_preview = StyleBoxFlat.new()
	style_drag_preview.bg_color = Color(0.2, 0.6, 0.8, 0.95)
	style_drag_preview.corner_radius_top_left = 12
	style_drag_preview.corner_radius_top_right = 12
	style_drag_preview.corner_radius_bottom_left = 12
	style_drag_preview.corner_radius_bottom_right = 12

# ==========================================
# ฟังก์ชันตัวช่วยดึงช่องตาราง (ประหยัดการเขียน Loop)
# ==========================================
func _get_all_cells() -> Array[Control]:
	var cells: Array[Control] = []
	for child in timetable_grid.get_children():
		if (child is Panel or child is PanelContainer) and child.name.begins_with("Cell_"):
			cells.append(child)
	return cells

# ==========================================
# ระบบควบคุมเทิร์น และ จัดการข้อมูล
# ==========================================
func _setup_turn() -> void:
	player_label.text = "PLAYER " + str(current_player_index + 1)
	return_button.visible = (current_player_index > 0)
	_load_schedule_from_global(current_player_index)

func _save_schedule_to_global() -> void:
	var schedule_positions = {}
	var subject_counts = {}
	var temp_daily = {"R1": [], "R2": [], "R3": [], "R4": [], "R5": []}
	
	for cell in _get_all_cells():
		var subject = cell.get_meta("subject", "")
		if subject != "":
			schedule_positions[cell.name] = subject
			subject_counts[subject] = subject_counts.get(subject, 0) + 1
				
			var r_name = _get_row_name(cell.name)
			var c_index = _get_col_index(cell.name)
			if temp_daily.has(r_name):
				temp_daily[r_name].append({"col": c_index, "subject": subject, "is_completed": false})
						
	var daily_subjects = {"R1": [], "R2": [], "R3": [], "R4": [], "R5": []}
	for r in temp_daily.keys():
		temp_daily[r].sort_custom(func(a, b): return a["col"] < b["col"])
		for item in temp_daily[r]:
			daily_subjects[r].append({"subject": item["subject"], "is_completed": item["is_completed"]})
			
	if not Global.player_data[current_player_index].has("timetable"):
		Global.player_data[current_player_index]["timetable"] = {}
		
	var t_data = Global.player_data[current_player_index]["timetable"]
	t_data["positions"] = schedule_positions
	t_data["counts"] = subject_counts
	t_data["daily_subjects"] = daily_subjects
	
	print(">>> บันทึกข้อมูลตารางเรียนของ P", current_player_index + 1, " เรียบร้อย <<<")

func _load_schedule_from_global(player_idx: int) -> void:
	var saved_positions = {}
	if Global.player_data.size() > player_idx and Global.player_data[player_idx].has("timetable"):
		saved_positions = Global.player_data[player_idx]["timetable"].get("positions", {})
		
	for cell in _get_all_cells():
		if saved_positions.has(cell.name):
			_apply_subject_to_cell(cell, saved_positions[cell.name])
		else:
			_clear_cell(cell)

# ==========================================
# ระบบลบ และ วาดช่องตาราง
# ==========================================
func _on_cell_gui_input(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if panel.get_meta("subject", "") != "":
			_clear_cell(panel)

func _clear_cell(panel: Control) -> void:
	panel.set_meta("subject", "")
	for c in panel.get_children(): c.queue_free()
	panel.add_theme_stylebox_override("panel", style_empty)

func _apply_subject_to_cell(panel: Control, subject_name: String) -> void:
	panel.set_meta("subject", subject_name)
	for c in panel.get_children(): c.queue_free()
		
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	
	var lbl = Label.new()
	lbl.text = subject_name
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	lbl.add_theme_font_size_override("font_size", 14)
	
	center.add_child(lbl)
	panel.add_child(center)
	panel.add_theme_stylebox_override("panel", style_filled)

# ==========================================
# ฟังก์ชันสำหรับการลาก (Drag & Drop)
# ==========================================
func _custom_get_drag_data(at_position: Vector2, button: Button) -> Variant:
	var preview_label = Label.new()
	preview_label.text = button.text
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var preview_panel = PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", style_drag_preview)
	preview_panel.custom_minimum_size = Vector2(130, 45)
	preview_panel.add_child(preview_label)
	
	var drag_control = Control.new()
	preview_panel.position = -preview_panel.custom_minimum_size / 2
	drag_control.add_child(preview_panel)
	
	button.set_drag_preview(drag_control)
	return button.text

func _custom_can_drop_data(at_position: Vector2, data: Variant, panel: Control) -> bool:
	if panel.name.ends_with("3"): return false # กันช่องพักเที่ยง
	if typeof(data) != TYPE_STRING: return false

	var target_day = _get_row_name(panel.name)
	var unique_subjects = []
	var subject_period_count = 0
	var day_period_count = 0
	
	for cell in _get_all_cells():
		var cell_subject = data if cell == panel else cell.get_meta("subject", "")
		if cell_subject != "":
			if not unique_subjects.has(cell_subject): unique_subjects.append(cell_subject)
			if cell_subject == data: subject_period_count += 1
			if _get_row_name(cell.name) == target_day: day_period_count += 1
						
	if unique_subjects.size() > 4: return false
	if subject_period_count > 3: return false
	if day_period_count > 2: return false
	return true

func _custom_drop_data(at_position: Vector2, data: Variant, panel: Control) -> void:
	_apply_subject_to_cell(panel, data)

# ==========================================
# ฟังก์ชันปุ่ม ยืนยัน / ย้อนกลับ
# ==========================================
func _on_confirm_button_pressed() -> void:
	var unique_subjects = []
	var day_counts = {"R1": 0, "R2": 0, "R3": 0, "R4": 0, "R5": 0}
	
	for cell in _get_all_cells():
		var cell_subject = cell.get_meta("subject", "")
		if cell_subject != "":
			if not unique_subjects.has(cell_subject):
				unique_subjects.append(cell_subject)
			
			var row_name = _get_row_name(cell.name)
			if day_counts.has(row_name):
				day_counts[row_name] += 1
					
	if unique_subjects.size() != 4:
		print("กรุณาลงทะเบียนให้มี 4 วิชาพอดี! (ตอนนี้มี ", unique_subjects.size(), " วิชา)")
		return
		
	var incomplete_days = []
	var day_names = {"R1": "จันทร์", "R2": "อังคาร", "R3": "พุธ", "R4": "พฤหัสฯ", "R5": "ศุกร์"}
	
	for r in day_names.keys():
		if day_counts[r] != 2:
			incomplete_days.append(day_names[r])
			
	if not incomplete_days.is_empty():
		print("จัดตารางไม่ครบ! ต้องลงวันละ 2 คาบ (วันที่ขาด: ", ", ".join(incomplete_days), ")")
		return
		
	_save_schedule_to_global()
	
	if current_player_index < total_players - 1:
		current_player_index += 1
		_setup_turn() 
	else:
		print("ผู้เล่นทุกคนจัดตารางเรียนเสร็จสิ้น! โหลดเข้าสู่ NewMap...")
		get_tree().change_scene_to_file("res://locations/NewMap.tscn")

func _on_return_button_pressed() -> void:
	if current_player_index > 0:
		_save_schedule_to_global()
		current_player_index -= 1
		_setup_turn() 

# ==========================================
# ฟังก์ชันตัวช่วยแยกคำ R และ C (Cell_R1C1)
# ==========================================
func _get_row_name(cell_name: String) -> String:
	var parts = cell_name.split("_")
	if parts.size() > 1:
		return parts[1].split("C")[0]
	return cell_name

func _get_col_index(cell_name: String) -> int:
	var parts = cell_name.split("_")
	if parts.size() > 1:
		var c_parts = parts[1].split("C")
		if c_parts.size() > 1:
			return c_parts[1].to_int()
	return 999

# ==========================================
# ฟังก์ชัน Dummy สำหรับ Drag 
# ==========================================
func _get_drag_data_dummy(at_position: Vector2) -> Variant: return null
func _can_drop_data_dummy(at_position: Vector2, data: Variant) -> bool: return false
func _drop_data_dummy(at_position: Vector2, data: Variant) -> void: pass

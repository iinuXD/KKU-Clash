extends Control

@onready var subject_inventory = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/SubjectInventory
@onready var timetable_grid = $MainPanel/MarginContainer/HBoxContainer/RightContent/TimetableGrid
@onready var confirm_button = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/ConfirmButton
@onready var return_button = $MainPanel/MarginContainer/HBoxContainer/RightContent/BottomBar/ReturnButton
@onready var player_label = $MainPanel/MarginContainer/HBoxContainer/LeftMenu/Label

var current_player_index: int = 0
var total_players: int = 0 

func _ready():
	# ดึงจำนวนผู้เล่นจริงจาก Global
	total_players = Global.player_data.size()
	
	# ป้องกันบั๊กกรณีเทสต์แล้วยังไม่มีข้อมูลใน Global
	if total_players == 0: 
		total_players = 1 

	# 1. ตั้งค่า Drag (ดึง) ให้ปุ่มรายวิชา
	for child in subject_inventory.get_children():
		if child is Button:
			child.set_drag_forwarding(_custom_get_drag_data.bind(child), _can_drop_data_dummy, _drop_data_dummy)
			
	# 2. ตั้งค่า Drop (วาง) และ คลิกขวา (ลบ) ให้ช่องตาราง
	for child in timetable_grid.get_children():
		if child is Panel or child is PanelContainer:
			if child.name.begins_with("Cell_"):
				child.set_meta("subject", "")
				child.set_drag_forwarding(_get_drag_data_dummy, _custom_can_drop_data.bind(child), _custom_drop_data.bind(child))
				child.gui_input.connect(_on_cell_gui_input.bind(child))
				
	# 3. เชื่อมต่อปุ่มกดยืนยันและย้อนกลับ
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)

	# 4. เริ่มต้นเทิร์นของผู้เล่นคนแรก
	_setup_turn()

# ==========================================
# ระบบควบคุมเทิร์น (Turn Management)
# ==========================================
func _setup_turn() -> void:
	player_label.text = "PLAYER " + str(current_player_index + 1)
	return_button.visible = (current_player_index > 0)
	_load_schedule_from_global(current_player_index)

# ==========================================
# ระบบบันทึกและโหลดข้อมูล
# ==========================================
func _save_schedule_to_global() -> void:
	var schedule_positions = {}
	var subject_counts = {}
	
	for cell in timetable_grid.get_children():
		if cell is Panel or cell is PanelContainer:
			if cell.name.begins_with("Cell_"):
				var subject = cell.get_meta("subject", "")
				if subject != "":
					schedule_positions[cell.name] = subject
					
					if subject_counts.has(subject):
						subject_counts[subject] += 1
					else:
						subject_counts[subject] = 1
						
	# ตรวจสอบและสร้าง Dictionary ใน Global (ถ้ายังไม่มี)
	# หมายเหตุ: จำเป็นต้องมีตัวแปร player_data ใน Global.gd ก่อน
	if not Global.player_data[current_player_index].has("timetable"):
		Global.player_data[current_player_index]["timetable"] = {}
		
	Global.player_data[current_player_index]["timetable"]["positions"] = schedule_positions
	Global.player_data[current_player_index]["timetable"]["counts"] = subject_counts
	
	print(">>> บันทึกข้อมูล P", current_player_index + 1, " เรียบร้อย <<<")

func _load_schedule_from_global(player_idx: int) -> void:
	# เคลียร์กระดานทุกช่องให้ว่างเปล่า
	for cell in timetable_grid.get_children():
		if cell is Panel or cell is PanelContainer:
			if cell.name.begins_with("Cell_"):
				_clear_cell(cell)

	# โหลดข้อมูลมาวาดลงตาราง
	if Global.player_data.size() > player_idx and Global.player_data[player_idx].has("timetable"):
		var saved_positions = Global.player_data[player_idx]["timetable"].get("positions", {})
		for cell in timetable_grid.get_children():
			if saved_positions.has(cell.name):
				_apply_subject_to_cell(cell, saved_positions[cell.name])

# ==========================================
# ระบบลบวิชา (คลิกขวาเคลียร์ช่อง)
# ==========================================
func _on_cell_gui_input(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if panel.get_meta("subject", "") != "":
			_clear_cell(panel)

func _clear_cell(panel: Control) -> void:
	panel.set_meta("subject", "")
	for c in panel.get_children():
		c.queue_free()
		
	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(1, 1, 1, 1)
	empty_style.border_width_left = 1
	empty_style.border_width_top = 1
	empty_style.border_width_right = 1
	empty_style.border_width_bottom = 1
	empty_style.border_color = Color(0.2, 0.2, 0.2, 1)
	panel.add_theme_stylebox_override("panel", empty_style)

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
	if panel.name.ends_with("3"): 
		return false
	if typeof(data) != TYPE_STRING:
		return false

	var target_day = _get_row_name(panel.name)
	var simulated_unique_subjects = []
	var subject_period_count = 0
	var day_period_count = 0
	
	for cell in timetable_grid.get_children():
		if cell is Panel or cell is PanelContainer:
			if cell.name.begins_with("Cell_"):
				var cell_subject = cell.get_meta("subject", "") 
				if cell == panel:
					cell_subject = data
					
				if cell_subject != "":
					if not simulated_unique_subjects.has(cell_subject):
						simulated_unique_subjects.append(cell_subject)
					if cell_subject == data:
						subject_period_count += 1
					if _get_row_name(cell.name) == target_day:
						day_period_count += 1
						
	# กฎการวาง: วิชาไม่เกิน 4, วิชานึงไม่เกิน 3 คาบ, วันนึงไม่เกิน 2 คาบ
	if simulated_unique_subjects.size() > 4: return false
	if subject_period_count > 3: return false
	if day_period_count > 2: return false
		
	return true

func _custom_drop_data(at_position: Vector2, data: Variant, panel: Control) -> void:
	_apply_subject_to_cell(panel, data)

func _apply_subject_to_cell(panel: Control, subject_name: String) -> void:
	panel.set_meta("subject", subject_name)
	for c in panel.get_children():
		c.queue_free()
		
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	
	var lbl = Label.new()
	lbl.text = subject_name
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
# ฟังก์ชันปุ่ม ยืนยัน / ย้อนกลับ
# ==========================================
func _on_confirm_button_pressed() -> void:
	var unique_subjects = []
	var day_counts = {"R1": 0, "R2": 0, "R3": 0, "R4": 0, "R5": 0}
	
	for cell in timetable_grid.get_children():
		if cell is Panel or cell is PanelContainer:
			if cell.name.begins_with("Cell_"):
				var cell_subject = cell.get_meta("subject", "")
				if cell_subject != "":
					# 1. นับวิชาที่ไม่ซ้ำ
					if not unique_subjects.has(cell_subject):
						unique_subjects.append(cell_subject)
					
					# 2. นับคาบเรียนในแต่ละวัน
					var row_name = _get_row_name(cell.name)
					if day_counts.has(row_name):
						day_counts[row_name] += 1
					
	# เช็คเงื่อนไขที่ 1: ต้องมี 4 วิชาพอดี
	if unique_subjects.size() != 4:
		print("กรุณาลงทะเบียนให้มี 4 วิชาพอดี! (ตอนนี้มี " + str(unique_subjects.size()) + " วิชา)")
		return
		
	# เช็คเงื่อนไขที่ 2: ทุกวัน (R1-R5) ต้องลงครบ 2 คาบ
	var is_days_complete = true
	var incomplete_days = []
	var day_names = {"R1": "จันทร์", "R2": "อังคาร", "R3": "พุธ", "R4": "พฤหัสฯ", "R5": "ศุกร์"}
	
	for r in ["R1", "R2", "R3", "R4", "R5"]:
		if day_counts[r] != 2:
			is_days_complete = false
			incomplete_days.append(day_names[r])
			
	if not is_days_complete:
		print("จัดตารางไม่ครบ! ต้องลงวันละ 2 คาบ (วันที่ขาด: " + ", ".join(incomplete_days) + ")")
		return
		
	# ผ่านทุกเงื่อนไข -> บันทึกและเปลี่ยนเทิร์น
	_save_schedule_to_global()
	
	if current_player_index < total_players - 1:
		current_player_index += 1
		_setup_turn() 
	else:
		print("ผู้เล่นทุกคนจัดตารางเรียนเสร็จสิ้น! โหลดเข้าสู่ NewMap...")
		get_tree().change_scene_to_file("res://locations/NewMap.tscn")

func _on_return_button_pressed() -> void:
	if current_player_index > 0:
		# 1. บันทึกตารางที่จัดค้างไว้ของคนปัจจุบันลง Global ก่อน
		print("บันทึกตารางชั่วคราวของ P", current_player_index + 1)
		_save_schedule_to_global()
		
		# 2. ถอยกลับไปโหลดข้อมูลผู้เล่นคนก่อนหน้า
		current_player_index -= 1
		_setup_turn() 

# ==========================================
# ฟังก์ชันตัวช่วยดึงชื่อวัน
# ==========================================
func _get_row_name(cell_name: String) -> String:
	var parts = cell_name.split("_")
	if parts.size() > 1:
		var r_c_part = parts[1] 
		var c_index = r_c_part.find("C")
		if c_index != -1:
			return r_c_part.substr(0, c_index) 
	return cell_name

# ==========================================
# ฟังก์ชัน Dummy
# ==========================================
func _get_drag_data_dummy(at_position: Vector2) -> Variant: return null
func _can_drop_data_dummy(at_position: Vector2, data: Variant) -> bool: return false
func _drop_data_dummy(at_position: Vector2, data: Variant) -> void: pass

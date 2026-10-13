extends Control

signal quiz_finished(study_gained: int)
signal exam_finished(result: Dictionary)

# อ้างอิง Nodes ด้วย % (อย่าลืมตั้งค่า Access as Unique Name ใน Editor ด้วยนะครับ)
@onready var subject_label = %SubjectLabel
@onready var time_label = %TimeLabel
@onready var question_number_label = %QuestionNumberLabel
@onready var question_label = %QuestionLabel
@onready var feedback_label = %FeedbackLabel

@onready var btn1 = %Btn1
@onready var btn2 = %Btn2
@onready var btn3 = %Btn3
@onready var btn4 = %Btn4
@onready var choice_buttons = [btn1, btn2, btn3, btn4]

@onready var grid_container = %GridContainer
@onready var summary_panel = %SummaryPanel
@onready var result_label = %ResultLabel
@onready var ok_button = %OkButton

var is_quiz_active: bool = false
var time_left: float = 20.0
var current_question_index: int = 0
var correct_answers: int = 0
var study_multiplier: float = 1.0
var result_modifier_text: String = ""
var question_target: int = 3
var is_exam_mode: bool = false

# --- ชุดตัวแปรใหม่สำหรับโจทย์ที่คิดเอง ---
var current_quiz_set: Array = []
var current_correct_answer: String = ""

# ไฟล์คำถามแยกตามรายวิชา
const SUBJECT_FILES = {
	"ภาษาไทย": "res://data/questions/thai.json",
	"คณิตศาสตร์": "res://data/questions/math.json",
	"ภาษาอังกฤษ": "res://data/questions/english.json",
	"ฟิสิกส์": "res://data/questions/physics.json",
	"เคมี": "res://data/questions/chemistry.json",
	"ชีววิทยา": "res://data/questions/biology.json"
}

func _ready() -> void:
	hide()
	summary_panel.hide()
	feedback_label.hide()
	
	# เชื่อมต่อสัญญาณปุ่มคำตอบทั้ง 4 ปุ่ม
	for i in range(choice_buttons.size()):
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
		
	# เชื่อมต่อปุ่มตกลง
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)

func _process(delta: float) -> void:
	if is_quiz_active:
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			_end_quiz()
			
		# อัปเดตข้อความเวลา
		time_label.text = "%02d วินาที" % int(time_left)
		
		# เปลี่ยนสีเวลาเป็นสีแดงชอล์กเมื่อเหลือน้อยกว่า 5 วินาที
		if time_left <= 5.0:
			time_label.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
		else:
			# พื้นคำถามเป็นสีครีม จึงใช้สีน้ำตาลเข้มเพื่อให้อ่านชัด
			time_label.add_theme_color_override("font_color", Color("#401c12"))

# ==========================================
# 1. ระบบเริ่มต้น Quiz (ดึงโจทย์ตามวิชา)
# ==========================================
func start_quiz(subject_name: String, subject_level: int = 1, reward_multiplier: float = 1.0, modifier_text: String = "") -> void:
	current_question_index = 0
	correct_answers = 0
	question_target = 3
	is_exam_mode = false
	study_multiplier = clampf(reward_multiplier, 0.0, 1.0)
	result_modifier_text = modifier_text
	time_left = 20.0
	is_quiz_active = true
	
	summary_panel.hide()
	feedback_label.hide()
	
	question_label.show()
	grid_container.show()
	question_number_label.show()
	show()
	
	var display_level = clampi(subject_level, 1, 6)
	var subject_data = _load_subject_database(subject_name)
	
	if subject_data.is_empty():
		print("❌ ไม่สามารถโหลดโจทย์วิชา ", subject_name, " ได้")
		is_quiz_active = false
		hide()
		return
	
	var level_key = str(display_level)
	if not subject_data.has(level_key):
		print("❌ ไม่พบ Level ", level_key, " ของวิชา ", subject_name)
		is_quiz_active = false
		hide()
		return
	
	var all_questions: Array = subject_data[level_key].duplicate(true)
	if all_questions.is_empty():
		print("❌ Level ", level_key, " ของวิชา ", subject_name, " ไม่มีโจทย์")
		is_quiz_active = false
		hide()
		return
	
	# ทำข้อความส่วนหัวให้กระชับเพื่อไม่ให้ทับเลขข้อและตัวจับเวลา
	subject_label.text = "%s | ระดับ %d" % [subject_name, display_level]
	
	# สุ่มโจทย์จาก Level ปัจจุบัน แล้วเลือกสูงสุด 3 ข้อ
	all_questions.shuffle()
	current_quiz_set = all_questions.slice(0, mini(question_target, all_questions.size()))
	
	_load_custom_question()


func start_exam(subject_name: String, subject_level: int = 1, exam_question_count: int = 5) -> void:
	current_question_index = 0
	correct_answers = 0
	question_target = maxi(1, exam_question_count)
	is_exam_mode = true
	study_multiplier = 1.0
	result_modifier_text = ""
	time_left = 60.0
	is_quiz_active = true

	summary_panel.hide()
	feedback_label.hide()
	question_label.show()
	grid_container.show()
	question_number_label.show()
	show()

	var display_level := clampi(subject_level, 1, 6)
	var subject_data := _load_subject_database(subject_name)
	if subject_data.is_empty():
		_abort_current_session()
		return

	var level_key := str(display_level)
	if not subject_data.has(level_key):
		_abort_current_session()
		return

	var all_questions: Array = subject_data[level_key].duplicate(true)
	if all_questions.is_empty():
		_abort_current_session()
		return

	# ชื่อวิชาอาจยาว โดยเฉพาะข้อความที่ผสมภาษาไทยและภาษาอังกฤษ
	subject_label.text = "สอบ %s | ระดับ %d" % [subject_name, display_level]
	all_questions.shuffle()
	current_quiz_set = all_questions.slice(0, mini(question_target, all_questions.size()))
	_load_custom_question()

# ==========================================
# 2. ระบบโหลดโจทย์ขึ้นหน้าจอ
# ==========================================
func _load_custom_question() -> void:
	# เช็คว่าทำครบตามจำนวนของโหมดปัจจุบัน หรือโจทย์หมดหรือยัง
	if current_question_index >= question_target or current_question_index >= current_quiz_set.size():
		_end_quiz()
		return
		
	var q_data = current_quiz_set[current_question_index]
	
	# เอาคำถามไปแสดงผล
	question_number_label.text = "ข้อ %d/%d" % [current_question_index + 1, current_quiz_set.size()]
	question_label.text = q_data["q"]
	
	# เก็บคำตอบที่ถูกต้องก่อนสับตัวเลือก
	# รองรับทั้ง answer แบบข้อความเดิม และ answer แบบ index (0-3)
	var original_choices: Array = q_data["choices"]
	var answer_data = q_data["answer"]
	if answer_data is int or answer_data is float:
		var answer_index = int(answer_data)
		if answer_index >= 0 and answer_index < original_choices.size():
			current_correct_answer = str(original_choices[answer_index])
		else:
			current_correct_answer = ""
	else:
		current_correct_answer = str(answer_data)
	
	# นำตัวเลือกมาสับเปลี่ยนลำดับ (ก.ข.ค.ง จะได้ไม่สลับตำแหน่งเดิมตลอด)
	var choices = original_choices.duplicate()
	choices.shuffle()
	
	# นำตัวเลือกไปใส่ในปุ่ม
	for i in range(4):
		if i < choices.size():
			choice_buttons[i].text = choices[i]
			choice_buttons[i].disabled = false
			choice_buttons[i].show()
		else:
			choice_buttons[i].hide() # ซ่อนปุ่มถ้าช้อยส์มีไม่ถึง 4 ข้อ

# ==========================================
# 3. ระบบตรวจคำตอบ
# ==========================================
func _on_choice_pressed(btn_index: int) -> void:
	if not is_quiz_active: return
	
	# ดึงข้อความจากปุ่มที่กดมาตรวจ
	var chosen_val = choice_buttons[btn_index].text
	
	if chosen_val == current_correct_answer:
		correct_answers += 1
		# สีเขียวชอล์กสไตล์กระดานดำ
		_show_feedback("ถูกต้อง!", Color(0.5, 0.9, 0.5)) 
	else:
		# สีแดงชอล์กสไตล์กระดานดำ
		_show_feedback("ผิด!", Color(0.9, 0.4, 0.4)) 
		
	current_question_index += 1
	_load_custom_question() # โหลดข้อถัดไป

func _show_feedback(msg: String, color: Color) -> void:
	feedback_label.text = msg
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.show()
	feedback_label.modulate.a = 1.0 
	
	# ทำให้ข้อความค่อยๆ จางหายไปใน 1 วินาที
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): feedback_label.hide())

# ==========================================
# 4. ระบบจบ Quiz และสรุปผล
# ==========================================
func _end_quiz() -> void:
	is_quiz_active = false
	for btn in choice_buttons: 
		btn.disabled = true
		
	question_label.hide()
	grid_container.hide()
	question_number_label.hide()
	
	var time_up_text = "หมดเวลา!\n" if time_left <= 0 else ""
	if is_exam_mode:
		result_label.text = "%sผลสอบวิชานี้\nตอบถูก: %d / %d ข้อ" % [
			time_up_text,
			correct_answers,
			current_quiz_set.size()
		]
	else:
		var study_gained := _calculate_study_gained()
		var modifier_line := (result_modifier_text + "\n") if not result_modifier_text.is_empty() else ""
		result_label.text = "%sตอบถูก: %d / %d ข้อ\n%sความรู้ที่ได้รับ: +%d" % [
			time_up_text,
			correct_answers,
			current_quiz_set.size(),
			modifier_line,
			study_gained
		]
	
	summary_panel.show()

func _on_ok_pressed() -> void:
	hide()
	if is_exam_mode:
		exam_finished.emit({
			"correct": correct_answers,
			"total": current_quiz_set.size()
		})
		return
	var study_gained := _calculate_study_gained()
	quiz_finished.emit(study_gained) # ส่งค่าความรู้กลับไปให้ new_map.gd


func _abort_current_session() -> void:
	is_quiz_active = false
	hide()
	if is_exam_mode:
		exam_finished.emit.call_deferred({"correct": 0, "total": question_target})
	else:
		quiz_finished.emit.call_deferred(0)


func _calculate_study_gained() -> int:
	return roundi(float(correct_answers * 10) * study_multiplier)

func _load_subject_database(subject_name: String) -> Dictionary:
	if not SUBJECT_FILES.has(subject_name):
		print("❌ ไม่พบไฟล์ที่กำหนดไว้สำหรับวิชา: ", subject_name)
		return {}
	
	var file_path: String = SUBJECT_FILES[subject_name]
	if not FileAccess.file_exists(file_path):
		print("❌ หาไฟล์ JSON ไม่เจอ: ", file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("❌ เปิดไฟล์ JSON ไม่สำเร็จ: ", file_path)
		return {}
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("❌ JSON ผิดพลาดใน ", file_path, " บรรทัด ", json.get_error_line(), ": ", json.get_error_message())
		return {}
	
	if not json.data is Dictionary:
		print("❌ โครงสร้าง JSON ของวิชา ", subject_name, " ต้องเป็น Dictionary ของ Level 1-6")
		return {}
	
	print("✅ โหลดโจทย์ ", subject_name, " สำเร็จ | ", file_path)
	return json.data

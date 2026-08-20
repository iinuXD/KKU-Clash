extends Control

signal quiz_finished(study_gained: int)

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

# --- ชุดตัวแปรใหม่สำหรับโจทย์ที่คิดเอง ---
var current_quiz_set: Array = [] 
var current_correct_answer: String = ""

# ฐานข้อมูลโจทย์ แยกตามรายวิชา
var question_database = {
	"ภาษาไทย": [
		{"q": "ข้อใดเขียนสะกดคำได้ถูกต้อง?", "choices": ["สังเกตุ", "อนุญาติ", "โอกาส", "อุปการะคุณ"], "answer": "โอกาส"},
		{"q": "คำว่า 'กิน' เป็นคำชนิดใด?", "choices": ["คำนาม", "คำสรรพนาม", "คำกริยา", "คำวิเศษณ์"], "answer": "คำกริยา"},
		{"q": "ใครคือผู้แต่งวรรณคดีเรื่อง พระอภัยมณี?", "choices": ["สุนทรภู่", "รัชกาลที่ 2", "รัชกาลที่ 6", "เจ้าฟ้ากุ้ง"], "answer": "สุนทรภู่"},
		{"q": "ข้อใดคือคำไวพจน์ที่มีความหมายว่า 'ช้าง'?", "choices": ["พาชี", "กุญชร", "วิหค", "มัจฉา"], "answer": "กุญชร"},
		{"q": "สำนวน 'สีซอให้ควายฟัง' มีความหมายว่าอย่างไร?", "choices": ["สอนคนโง่ไม่ได้ผล", "ทำเรื่องไร้สาระ", "อวดรู้กับผู้เชี่ยวชาญ", "ทำดีได้ดี"], "answer": "สอนคนโง่ไม่ได้ผล"}
	],
	"คณิตศาสตร์": [
		{"q": "ค่าของ 5! (5 แฟกทอเรียล) คือเท่าใด?", "choices": ["20", "60", "120", "720"], "answer": "120"},
		{"q": "มุมภายในของรูปสามเหลี่ยมรวมกันได้กี่องศา?", "choices": ["90", "180", "270", "360"], "answer": "180"},
		{"q": "ถ้า 2x + 5 = 15 ค่าของ x คือเท่าใด?", "choices": ["3", "5", "10", "20"], "answer": "5"},
		{"q": "ข้อใดคือจำนวนเฉพาะทั้งหมด?", "choices": ["2, 3, 5, 9", "2, 3, 5, 7", "1, 3, 5, 7", "2, 4, 6, 8"], "answer": "2, 3, 5, 7"},
		{"q": "8 ยกกำลัง 2 มีค่าเท่ากับเท่าใด?", "choices": ["16", "32", "64", "128"], "answer": "64"}
	],
	"Default": [
		{"q": "วิชานี้ยังไม่มีโจทย์ (ทดสอบ)", "choices": ["A", "B", "C", "D"], "answer": "A"},
		{"q": "วิชานี้ยังไม่มีโจทย์ (ทดสอบ)", "choices": ["1", "2", "3", "4"], "answer": "1"},
		{"q": "วิชานี้ยังไม่มีโจทย์ (ทดสอบ)", "choices": ["ก", "ข", "ค", "ง"], "answer": "ก"}
	]
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
		
		# เปลี่ยนสีเวลาเป็นสีแดงเมื่อเหลือน้อยกว่า 5 วินาที
		if time_left <= 5.0:
			time_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
		else:
			time_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))

# ==========================================
# 1. ระบบเริ่มต้น Quiz (ดึงโจทย์ตามวิชา)
# ==========================================
func start_quiz(subject_name: String) -> void:
	subject_label.text = "วิชา: " + subject_name
	current_question_index = 0
	correct_answers = 0
	time_left = 20.0
	is_quiz_active = true
	
	summary_panel.hide()
	feedback_label.hide()
	
	question_label.show()
	grid_container.show()
	question_number_label.show()
	show()
	
	# ดึงโจทย์ตามชื่อวิชา ถ้าหาวิชาไม่เจอให้ดึงหมวด "Default" มาใช้แทน
	var all_questions = question_database.get(subject_name, question_database["Default"]).duplicate()
	
	# สับเปลี่ยนลำดับโจทย์ทั้งหมดที่มี
	all_questions.shuffle() 
	
	# ตัดมาใช้งานแค่ 3 ข้อ (หรือเท่าที่มีถ้าโจทย์มีไม่ถึง 3 ข้อ)
	current_quiz_set = all_questions.slice(0, 3)
	
	_load_custom_question()

# ==========================================
# 2. ระบบโหลดโจทย์ขึ้นหน้าจอ
# ==========================================
func _load_custom_question() -> void:
	# เช็คว่าทำครบ 3 ข้อหรือยัง หรือโจทย์หมดหรือยัง
	if current_question_index >= 3 or current_question_index >= current_quiz_set.size():
		_end_quiz()
		return
		
	var q_data = current_quiz_set[current_question_index]
	
	# เอาคำถามไปแสดงผล
	question_number_label.text = "ข้อ %d/3" % [current_question_index + 1]
	question_label.text = q_data["q"]
	
	# นำตัวเลือกมาสับเปลี่ยนลำดับ (ก.ข.ค.ง จะได้ไม่สลับตำแหน่งเดิมตลอด)
	var choices = q_data["choices"].duplicate()
	choices.shuffle() 
	
	# บันทึกคำตอบที่ถูกต้องของข้อนี้เอาไว้ตรวจ
	current_correct_answer = q_data["answer"]
	
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
		_show_feedback("ถูกต้อง!", Color(0.1, 0.7, 0.1)) # สีเขียว
	else:
		_show_feedback("ผิด!", Color(0.8, 0.1, 0.1)) # สีแดง
		
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
	
	# คำนวณความรู้ที่ได้รับ (สมมติข้อละ 20 หน่วย)
	var study_gained = correct_answers * 20 
	
	var time_up_text = "หมดเวลา!\n" if time_left <= 0 else ""
	result_label.text = "%sตอบถูก: %d / 3 ข้อ\nความรู้ที่ได้รับ: +%d" % [time_up_text, correct_answers, study_gained]
	
	summary_panel.show()

func _on_ok_pressed() -> void:
	hide()
	var study_gained = correct_answers * 20
	quiz_finished.emit(study_gained) # ส่งค่าความรู้กลับไปให้ new_map.gd

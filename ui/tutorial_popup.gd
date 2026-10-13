class_name TutorialPopup
extends Control

signal closed(completed: bool)

const PAGES: Array[Dictionary] = [
	{
		"title": "ยินดีต้อนรับสู่ KKU Clash",
		"body": "รอบแรกเป็นรอบฝึกเล่น จึงยังไม่มีเหตุการณ์สุ่ม\nระหว่างอ่านคำแนะนำ เวลาในเกมจะหยุดเดิน",
		"hint": "อ่านได้ตามสบาย แล้วกด ถัดไป เพื่อเริ่มทำความรู้จักเกม"
	},
	{
		"title": "การเคลื่อนที่",
		"body": "ใช้ปุ่ม W A S D เพื่อพาตัวละครเดินบนแผนที่\nหมุนลูกกลิ้งเมาส์เพื่อย่อหรือขยายมุมมอง",
		"hint": "W ขึ้น   •   A ซ้าย   •   S ลง   •   D ขวา"
	},
	{
		"title": "การเข้าใช้สถานที่",
		"body": "เดินเข้าใกล้สถานที่จนพื้นที่นั้นแสดงกรอบเด่น แล้วกด E เพื่อเปิดรายการกิจกรรม\nเลื่อนเมาส์ไปที่กิจกรรมเพื่อดูผลต่อเงิน ค่าสถานะ และเวลาก่อนตัดสินใจ",
		"hint": "เข้าใกล้สถานที่  →  กด E  →  ตรวจสอบผล  →  เลือกกิจกรรม"
	},
	{
		"title": "ภารกิจและตารางเรียน",
		"body": "ตรวจสอบภารกิจของรอบปัจจุบันจากกล่องภารกิจ และกดปุ่ม ตารางเรียน ด้านบนเพื่อดูเวลาเรียน\nควรเดินทางไปคณะให้ทันเวลา เพราะการเข้าเรียนสายจะได้รับความรู้น้อยลง",
		"hint": "แต่ละรอบมี 2 คาบเรียน และอาจมีภารกิจเสริมจากเหตุการณ์"
	},
	{
		"title": "บริหารทรัพยากรให้สมดุล",
		"body": "วางแผนเงิน ความสุข ความอิ่ม พลังงาน และความรู้ให้เหมาะสม\nกิจกรรมแต่ละชนิดให้ผลต่างกัน และไม่สามารถซื้อของได้เมื่อมีเงินไม่เพียงพอ",
		"hint": "หากความอิ่มหรือพลังงานหมด ตัวละครจะเป็นลมและเสียเวลา"
	},
	{
		"title": "เวลา การจบเทิร์น และการบันทึก",
		"body": "ทุกการเดินทางและกิจกรรมใช้เวลา จึงควรวางแผนให้เสร็จสิ้นก่อนหมดวัน\nผู้เล่นต้องกลับไปจบเทิร์นที่หอพักก่อนเวลา 03:00 น.",
		"hint": "เปิดเมนูมุมขวาบนเพื่อบันทึกเกม หรือตรวจสอบวิธีเล่นอีกครั้ง"
	}
]

@onready var progress_label: Label = $Panel/ProgressLabel
@onready var title_label: Label = $Panel/TitleLabel
@onready var body_label: Label = $Panel/BodyLabel
@onready var hint_label: Label = $Panel/HintPanel/HintLabel
@onready var skip_button: Button = $Panel/Buttons/SkipButton
@onready var back_button: Button = $Panel/Buttons/BackButton
@onready var next_button: Button = $Panel/Buttons/NextButton

var current_page: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	skip_button.pressed.connect(_close_tutorial)
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	hide()


func open_tutorial() -> void:
	current_page = 0
	_render_page()
	show()
	next_button.grab_focus()


func _render_page() -> void:
	var page: Dictionary = PAGES[current_page]
	progress_label.text = "%d / %d" % [current_page + 1, PAGES.size()]
	title_label.text = str(page.get("title", ""))
	body_label.text = str(page.get("body", ""))
	hint_label.text = str(page.get("hint", ""))
	back_button.disabled = current_page == 0
	next_button.text = "เริ่มเล่น" if current_page == PAGES.size() - 1 else "ถัดไป"


func _on_back_pressed() -> void:
	if current_page <= 0:
		return
	current_page -= 1
	_render_page()


func _on_next_pressed() -> void:
	if current_page >= PAGES.size() - 1:
		_close_tutorial()
		return
	current_page += 1
	_render_page()


func _close_tutorial() -> void:
	hide()
	closed.emit(true)

extends Control

signal activity_chosen(activity_name)

@onready var title_label = $BgFrame/TitleLabel
@onready var btn_container = $BgFrame/VBoxContainer
@onready var close_btn = $BgFrame/CloseButton

var activity_data = {
	"Dorm": {"title": "หอพัก", "options": ["นอนพัก", "เล่นเกม", "อ่านหนังสือ", "จ่ายค่าห้อง"]},
	"Learn": {"title": "ตึกเรียน", "options": ["", "", "", ""]},
	"Food": {"title": "โรงอาหาร", "options": ["กินข้าวจานธรรมดา", "กินข้าวจานพิเศษ", "กินของทานเล่น", "ทำ Parttime"]},
	"Library": {"title": "ห้องสมุด", "options": ["อ่านหนังสือ", "ค้นคว้า", "ยืมหนังสือ", "ทำ Parttime"]},
	"Shop": {"title": "ร้านค้า", "options": ["ซื้ออาหารตุน 2 สัปดาห์", "ซื้ออาหารตุน 3 สัปดาห์", "ทำ Parttime"]},
	"Hospital": {"title": "โรงพยาบาล", "options": ["เข้ารับการรักษา", "ซื้อยา", "ตรวจสุขภาพ"]},
	"Park": {"title": "สวนเกษตร", "options": ["เดินเล่น", "ซื้อของกิน", "ขายของ"]},
	"Sport": {"title": "สนามกีฬา", "options": ["วิ่ง", "เล่นกีฬา", "ทำกิจกรรม"]},
	"Fun": {"title": "สถานบันเทิง", "options": ["ดูหนัง", "ปาร์ตี้", "ทำ Parttime"]}
}

func _ready() -> void:
	hide()
	

	var btns = btn_container.get_children()
	for btn in btns:
		if btn is Button:
			btn.pressed.connect(_on_button_pressed.bind(btn))
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		
func open_popup(place_name: String, player_index: int) -> void:
	var data = activity_data.get(place_name, {"title": place_name, "options": ["ปิดหน้าต่าง"]})
	var current_title = data["title"]
	var current_options = data["options"].duplicate()
	
	if place_name == "Learn":
		if Global.player_data.size() > player_index:
			var p_data = Global.player_data[player_index]
			# เช็คว่าผู้เล่นคนนี้มีข้อมูลจัดตารางเรียนเซฟไว้ไหม
			if p_data.has("timetable") and p_data["timetable"].has("counts"):
				var registered_subjects = p_data["timetable"]["counts"].keys()
				
				# เคลียร์ปุ่มเก่าทิ้ง และเอาวิชาที่ลงทะเบียนไว้มาใส่แทน
				current_options.clear()
				for sub_name in registered_subjects:
					current_options.append("เรียน " + str(sub_name))
					
					# จำกัดแค่ 4 วิชา (เท่าจำนวนปุ่มที่เรามี)
					if current_options.size() == 4:
						break
			else:
				# เผื่อกรณีเทสต์เกมข้ามด่าน แล้วลืมลงทะเบียนเรียน
				current_options = ["ยังไม่ได้ลงทะเบียน", "-", "-", "-"]
	
	title_label.text = current_title
	
	var btns = btn_container.get_children()
	for i in range(btns.size()):
		if btns[i] is Button:
			if i < current_options.size():
				btns[i].text = current_options[i]
				btns[i].show()
			else:
				btns[i].hide()
			
	show() # แสดง Popup

func _on_button_pressed(btn: Button) -> void:
	hide() # กดเสร็จให้ซ่อนหน้าต่าง
	activity_chosen.emit(btn.text) # ส่งสัญญาณบอกแผนที่ว่าเลือกกิจกรรมอะไรไป

func _on_close_pressed() -> void:
	hide()
	activity_chosen.emit("ยกเลิก (ไม่ทำกิจกรรม)")

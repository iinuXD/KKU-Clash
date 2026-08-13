extends Control

signal activity_chosen(activity_name)

@onready var title_label = $BgFrame/TitleLabel
@onready var btn_container = $BgFrame/VBoxContainer
@onready var close_btn = $BgFrame/CloseButton 

# ตัวแปรสำหรับป้ายโชว์สเตตัสที่เมาส์
var hover_label: Label

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
	
	# สร้างป้าย Label ขึ้นมาตกแต่งพร้อมกรอบดำโปร่งแสง
	hover_label = Label.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	
	hover_label.add_theme_stylebox_override("normal", style)
	hover_label.add_theme_font_size_override("font_size", 14)
	hover_label.z_index = 100 
	hover_label.hide() 
	add_child(hover_label)
	
	# เชื่อมต่อปุ่ม และเพิ่ม Event ตรวจจับเมาส์
	var btns = btn_container.get_children()
	for btn in btns:
		if btn is Button:
			btn.pressed.connect(_on_button_pressed.bind(btn))
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_exit)
			
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

func _process(delta: float) -> void:
	# ขยับป้ายให้ลอยตามปลายเมาส์ตลอดเวลา
	if hover_label and hover_label.visible:
		hover_label.global_position = get_global_mouse_position() + Vector2(15, 15)

# สังเกตว่ามีการรับค่า place_effects (ตารางกิจกรรม) เข้ามาด้วย
func open_popup(place_name: String, player_index: int, place_effects: Dictionary = {}) -> void:
	var data = activity_data.get(place_name, {"title": place_name, "options": ["ปิดหน้าต่าง"]})
	var current_title = data["title"]
	var current_options = data["options"].duplicate()
	
	if place_name == "Learn":
		if Global.player_data.size() > player_index:
			var p_data = Global.player_data[player_index]
			if p_data.has("timetable") and p_data["timetable"].has("counts"):
				var registered_subjects = p_data["timetable"]["counts"].keys()
				current_options.clear()
				for sub_name in registered_subjects:
					current_options.append("เรียน " + str(sub_name))
					if current_options.size() == 4:
						break
			else:
				current_options = ["ยังไม่ได้ลงทะเบียน", "-", "-", "-"]
				
	title_label.text = current_title
	
	var btns = btn_container.get_children()
	for i in range(btns.size()):
		if btns[i] is Button:
			if i < current_options.size():
				var action_name = current_options[i]
				btns[i].text = action_name
				btns[i].show()
				
				# --- เตรียมข้อความแจ้งสเตตัสสำหรับปุ่มนี้ ---
				var hover_str = ""
				if place_name == "Learn" and action_name.begins_with("เรียน "):
					hover_str = _generate_hover_text({"study": 20, "stamina": -15, "hunger": -10, "happiness": -10})
				elif place_effects.has(action_name):
					hover_str = _generate_hover_text(place_effects[action_name])
				else:
					hover_str = "ไม่มีผลกระทบต่อสเตตัส"
					
				# ฝังข้อความสเตตัสไว้ในปุ่ม
				btns[i].set_meta("hover_text", hover_str)
			else:
				btns[i].hide() 
			
	show() 

# ฟังก์ชันแปลง Dictionary ตัวเลข ให้กลายเป็นข้อความภาษาไทยพร้อมเครื่องหมาย +/-
func _generate_hover_text(effects: Dictionary) -> String:
	var text = ""
	var th_names = {
		"money": "เงิน", 
		"study": "ความรู้", 
		"happiness": "ความสุข", 
		"hunger": "ความอิ่ม", 
		"stamina": "พลังงาน"
	}
	
	for key in effects:
		var val = effects[key]
		var sign_str = "+" if val > 0 else ""
		text += th_names.get(key, key) + " " + sign_str + str(val) + "\n"
		
	return text.strip_edges() # ตัดช่องว่างบรรทัดสุดท้ายออก

# เมื่อเอาเมาส์ชี้ปุ่ม
func _on_btn_hover(btn: Button) -> void:
	if btn.has_meta("hover_text"):
		hover_label.text = btn.get_meta("hover_text")
		hover_label.show()

# เมื่อเอาเมาส์ออกจากปุ่ม
func _on_btn_exit() -> void:
	hover_label.hide()

func _on_button_pressed(btn: Button) -> void:
	hover_label.hide() # ซ่อนป้ายทันทีเมื่อกด
	hide() 
	activity_chosen.emit(btn.text) 

func _on_close_pressed() -> void:
	hover_label.hide()
	hide() 
	activity_chosen.emit("ยกเลิก (ไม่ทำกิจกรรม)")

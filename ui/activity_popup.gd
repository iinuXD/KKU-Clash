extends Control

signal activity_chosen(activity_name)

@onready var title_label = $BgFrame/TitleLabel
@onready var btn_container = $BgFrame/VBoxContainer
@onready var close_btn = $BgFrame/CloseButton 

var hover_label: Label

var activity_data = {
	"Dorm": {"title": "หอพัก", "options": ["นอนพัก", "อ่านหนังสือ", "จบเทิร์น"]},
	"Food": {"title": "โรงอาหาร", "options": ["กินข้าวจานธรรมดา", "กินข้าวจานพิเศษ", "กินของทานเล่น", "ทำ Parttime"]},
	"Library": {"title": "หอสมุด", "options": ["อ่านหนังสือ", "ยืมหนังสือ", "นั่งเล่น"]},
	"Shop": {"title": "ร้านค้า", "options": ["ซื้อกาแฟ", "ซื้อขนม", "ซื้อยา", "ทำ Parttime"]},
	"Hospital": {"title": "โรงพยาบาล", "options": ["เข้ารับการรักษา", "ซื้อยา", "ตรวจสุขภาพ"]},
	"Sport": {"title": "สนามกีฬา", "options": ["วิ่ง", "เล่นกีฬา", "ออกกำลังกาย"]},
	"Fun": {"title": "สถานบันเทิง", "options": ["ร้องคาราโอเกะ", "ปาร์ตี้", "ทำ Parttime"]}
}

func _ready() -> void:
	hide() 
	_setup_hover_label()
	
	# เชื่อมต่อสัญญาณปุ่มทั้งหมด
	for btn in btn_container.get_children():
		if btn is Button:
			btn.pressed.connect(_on_button_pressed.bind(btn))
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_exit)
			
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

func _process(delta: float) -> void:
	if hover_label and hover_label.visible:
		hover_label.global_position = get_global_mouse_position() + Vector2(15, 15)

# ==========================================
# ระบบจัดเตรียมหน้าต่าง Popup
# ==========================================
func open_popup(place_name: String, player_index: int, place_effects: Dictionary = {}) -> void:
	# ดึงข้อมูลชื่อตึกและปุ่ม หากตึกนั้นไม่มีใน data ให้ดึง title จากชื่อ Node แทน
	var data = activity_data.get(place_name, {"title": "คณะ", "options": []})
	title_label.text = data["title"]
	
	# กรณีเป็นตึก Learn ให้ดึงชื่อปุ่มวิชามาจาก place_effects ที่ new_map โยนมาให้เลย
	var current_options = place_effects.keys() if place_name == "Learn" else data["options"]
	var btns = btn_container.get_children()
	
	for i in range(btns.size()):
		if btns[i] is Button:
			if i < current_options.size():
				var action_name = current_options[i]
				btns[i].text = action_name
				btns[i].show()
				
				# จัดการ Tooltip โชว์สเตตัส
				var hover_str = _generate_hover_text(place_effects[action_name]) if place_effects.has(action_name) else "ไม่มีผลกระทบต่อสเตตัส"
				btns[i].set_meta("hover_text", hover_str)
			else:
				btns[i].hide() 
				
	show()

# ==========================================
# ระบบป้าย Tooltip (Hover)
# ==========================================
func _setup_hover_label() -> void:
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
		
	return text.strip_edges()

# ==========================================
# Event ปฏิสัมพันธ์กับผู้เล่น
# ==========================================
func _on_btn_hover(btn: Button) -> void:
	if btn.has_meta("hover_text"):
		hover_label.text = btn.get_meta("hover_text")
		hover_label.show()

func _on_btn_exit() -> void:
	hover_label.hide()

func _on_button_pressed(btn: Button) -> void:
	hover_label.hide()
	hide() 
	activity_chosen.emit(btn.text) 

func _on_close_pressed() -> void:
	hover_label.hide()
	hide() 
	activity_chosen.emit("ยกเลิก (ไม่ทำกิจกรรม)")

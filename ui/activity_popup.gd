extends Control

signal activity_chosen(activity_name)

@onready var title_label = $BgFrame/TitleLabel
@onready var btn_container = $BgFrame/ButtonsCenter/GridContainer   # แก้ path
@onready var close_btn = $BgFrame/CloseButton
@onready var place_image = $BgFrame/LeftImage

var hover_label: Label

# เหลือแค่ title — เลิกเก็บ "options" ซ้ำซ้อนกับ activity_effects ใน map script แล้ว
var activity_data = {
	"Dorm": {"title": "หอพัก", "img": "dorm.png"},
	"Food": {"title": "โรงอาหาร", "img": "food.png"},
	"Library": {"title": "หอสมุด", "img": "shop.png"},
	"Shop": {"title": "ร้านค้า", "img": "shop.png"},
	"Hospital": {"title": "โรงพยาบาล", "img": "shop.png"},
	"Sport": {"title": "สนามกีฬา", "img": "shop.png"},
	"Fun": {"title": "สถานบันเทิง", "img": "shop.png"},
	"Learn": {"title": "ตึกเรียน", "img": "dorm.png"}
}

func _ready() -> void:
	hide() 
	_setup_hover_label()
	
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

func open_popup(place_name: String, player_index: int, place_effects: Dictionary = {}) -> void:
	var data = activity_data.get(place_name, {"title": "สถานที่", "img": "dorm.png"})
	title_label.text = data.get("title", "สถานที่")
	
	var image_filename = data.get("img", "dorm.png")
	var image_path = "res://asset/activities/" + image_filename
	
	if ResourceLoader.exists(image_path):
		place_image.texture = load(image_path)
	else:
		place_image.texture = load("res://asset/activities/dorm.png")
	
	# ใช้ place_effects (จาก map script) เป็นแหล่งข้อมูลเดียวเสมอ ไม่แยกเคส "Learn" อีกต่อไป
	var current_options = place_effects.keys()
	var btns = btn_container.get_children()
	
	for i in range(btns.size()):
		if btns[i] is Button:
			if i < current_options.size():
				var action_name = current_options[i]
				btns[i].text = action_name
				btns[i].show()
				
				var hover_str = _generate_hover_text(place_effects[action_name])
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

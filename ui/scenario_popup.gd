extends Control

signal scenario_resolved(effects)

@onready var title_label = %TitleLabel
@onready var desc_label = %DescLabel
@onready var vbox = %VBoxContainer

var scenarios_db: Dictionary = {}
var current_scenario: Dictionary = {}

func _ready() -> void:
	hide()
	_load_scenarios()

func _load_scenarios() -> void:
	var file_path = "res://data/scenarios.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			scenarios_db = json.data

# ฟังก์ชันนี้จะเช็คว่ามีอีเวนต์ไหม และจะสุ่มแสดงผล
func try_start_scenario(place_name: String) -> bool:
	if not scenarios_db.has(place_name): return false
	
	var place_scenarios = scenarios_db[place_name]
	if place_scenarios.is_empty(): return false
	
	# สุ่มหยิบมา 1 สถานการณ์
	current_scenario = place_scenarios.pick_random()
	desc_label.text = current_scenario["description"]
	
	# ล้างปุ่มเก่าทิ้ง
	for child in vbox.get_children():
		child.queue_free()
		
	# สร้างปุ่มใหม่ตามจำนวนทางเลือกใน JSON
	var choices = current_scenario.get("choices", [])
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice["text"]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 28)
		# ส่ง index ไปกับ signal เพื่อให้รู้ว่ากดปุ่มไหน
		btn.pressed.connect(_on_choice_selected.bind(i))
		vbox.add_child(btn)
		
	show()
	return true

func _on_choice_selected(choice_index: int) -> void:
	hide()
	var effects = current_scenario["choices"][choice_index].get("effects", {})
	scenario_resolved.emit(effects)

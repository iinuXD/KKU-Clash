extends Control

signal closed

@export var in_game_mode: bool = false

@onready var player_label: Label = %PlayerLabel
@onready var schedule_grid: GridContainer = %ScheduleGrid
@onready var previous_button: Button = %PreviousButton
@onready var next_button: Button = %NextButton
@onready var primary_button: Button = %PrimaryButton

const DAY_LABELS := {
	"R1": "จันทร์",
	"R2": "อังคาร",
	"R3": "พุธ",
	"R4": "พฤหัสบดี",
	"R5": "ศุกร์"
}

var current_player_index: int = 0
var total_players: int = 1


func _ready() -> void:
	if Global.player_data.is_empty():
		Global.setup_players(max(1, Global.player_count))
	Global.ensure_random_timetables()

	total_players = max(1, Global.player_data.size())
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	primary_button.pressed.connect(_on_primary_pressed)
	primary_button.text = "ปิดตาราง" if in_game_mode else "เข้าสู่เกม"
	_render_schedule()

	if in_game_mode:
		hide()


func open_for_player(player_index: int) -> void:
	current_player_index = clampi(player_index, 0, total_players - 1)
	_render_schedule()
	show()
	primary_button.grab_focus()


func _render_schedule() -> void:
	if not is_node_ready() or Global.player_data.is_empty():
		return

	current_player_index = clampi(current_player_index, 0, Global.player_data.size() - 1)
	var faculty := Global.get_faculty(str(Global.player_data[current_player_index].get("faculty_id", "none")))
	player_label.text = "ผู้เล่น %d / %d · %s" % [current_player_index + 1, total_players, faculty["name"]]
	previous_button.disabled = current_player_index <= 0
	next_button.disabled = current_player_index >= total_players - 1

	var timetable: Dictionary = Global.player_data[current_player_index].get("timetable", {})
	_build_schedule_grid(timetable)


func _build_schedule_grid(timetable: Dictionary) -> void:
	_clear_container(schedule_grid)
	_add_header_cell("วัน")
	for period in Global.TIMETABLE_PERIODS:
		_add_header_cell(period["label"])

	var daily_subjects: Dictionary = timetable.get("daily_subjects", {})
	for day_key in Global.TIMETABLE_DAY_KEYS:
		_add_day_cell(DAY_LABELS.get(day_key, day_key))
		var classes_by_period: Dictionary = {}
		for class_entry in daily_subjects.get(day_key, []):
			var period_column: int = int(class_entry.get("period", class_entry.get("col", 0)))
			classes_by_period[period_column] = class_entry

		for period in Global.TIMETABLE_PERIODS:
			var column: int = int(period["column"])
			_add_schedule_cell(classes_by_period.get(column, {}))


func _add_header_cell(text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.add_theme_stylebox_override("panel", _make_style(Color("#ead2ad"), Color("#742d1d"), 2, 8))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#4d2318"))
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	schedule_grid.add_child(panel)


func _add_day_cell(day_name: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(130, 66)
	panel.add_theme_stylebox_override("panel", _make_style(Color("#f3e6cf"), Color("#9e5938"), 2, 8))
	var label := Label.new()
	label.text = day_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#5a2b1d"))
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	schedule_grid.add_child(panel)


func _add_schedule_cell(class_entry: Dictionary) -> void:
	var subject: String = class_entry.get("subject", "")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(205, 66)
	var background: Color = Color("#f6eddd") if subject.is_empty() else Color("#edc997")
	var border: Color = Color("#cbb58e") if subject.is_empty() else Color("#8a3522")
	panel.add_theme_stylebox_override("panel", _make_style(background, border, 1, 8))

	var label := Label.new()
	label.text = "—" if subject.is_empty() else subject
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = subject
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#8f7b60") if subject.is_empty() else Color("#4d2318"))
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	schedule_grid.add_child(panel)


func _make_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_previous_pressed() -> void:
	if current_player_index > 0:
		current_player_index -= 1
		_render_schedule()


func _on_next_pressed() -> void:
	if current_player_index < total_players - 1:
		current_player_index += 1
		_render_schedule()


func _on_primary_pressed() -> void:
	if in_game_mode:
		hide()
		closed.emit()
	else:
		get_tree().change_scene_to_file("res://locations/NewMap.tscn")

extends Control

const BORDER_NORMAL = preload("res://asset/playerpanel/border.png")
const BORDER_ACTIVE = preload("res://asset/playerpanel/border2.png")
const FULL_CARD_SIZE := Vector2(252, 130)
const COMPACT_CARD_SIZE := Vector2(104, 112)
const CARD_SIDE_MARGIN := 8.0
const CARD_TOP_OFFSET := 68.0
const CARD_BOTTOM_MARGIN := 8.0

const STAT_CONFIG := {
	"happiness": {"bar": "HappinessBar", "value": "HappinessValue", "max": 200.0},
	"hunger": {"bar": "HungerBar", "value": "HungerValue", "max": 200.0},
	"stamina": {"bar": "StaminaBar", "value": "StaminaValue", "max": 200.0},
	"study": {"bar": "StudyBar", "value": "StudyValue", "max": 400.0},
}

@onready var stats: Array[Control] = [$playerstat1, $playerstat2, $playerstat3, $playerstat4]
@onready var time_label: Label = $TopInfo/MarginContainer/InfoRow/ActionPoint
@onready var week_label: Label = $TopInfo/MarginContainer/InfoRow/WeekReportLabel
@onready var mission_panel: PanelContainer = $MissionPanel
@onready var mission_scroll: ScrollContainer = $MissionPanel/MarginContainer/VBoxContainer/MissionScroll
@onready var mission_details: Label = $MissionPanel/MarginContainer/VBoxContainer/MissionScroll/MissionDetails


func _ready() -> void:
	mission_scroll.gui_input.connect(_on_mission_scroll_gui_input)


func setup_players_ui() -> void:
	var player_count := Global.player_data.size() if Global.player_data.size() > 0 else 1
	for i in range(stats.size()):
		var stat_panel := stats[i]
		if i < player_count:
			stat_panel.visible = true
			var player_label := stat_panel.find_child("PlayerName", true, false) as Label
			if player_label:
				player_label.text = "P%d" % (i + 1)
			_update_avatar(stat_panel, i)
			_update_stats_ui(stat_panel, i)
		else:
			stat_panel.visible = false


func update_turn_ui(active_index: int) -> void:
	for i in range(stats.size()):
		if stats[i].visible:
			_set_card_active(stats[i], i, i == active_index)


func update_time_ui(current_minutes: int, _start_minutes: int, _end_minutes: int, speed_multiplier: float = 1.0) -> void:
	if not time_label:
		return
	var hour := int(current_minutes / 60) % 24
	var minute := current_minutes % 60
	var speed_text := "  ×%.2f" % speed_multiplier if speed_multiplier > 1.001 else ""
	time_label.text = "เวลา  %02d:%02d น.%s" % [hour, minute, speed_text]
	time_label.add_theme_color_override(
		"font_color",
		Color("#a33f23") if speed_multiplier > 1.001 else Color("#471c12")
	)


func update_round_ui(current_round: int, max_rounds: int) -> void:
	if week_label:
		week_label.text = "วันที่  %d / %d" % [current_round, max_rounds]


func _on_mission_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mission_scroll.accept_event()


func _update_avatar(stat_panel: Node, player_index: int) -> void:
	var p_data: Dictionary = Global.player_data[player_index] if Global.player_data.size() > player_index else {}
	if not p_data.has("avatar_settings"):
		return
	var settings: Dictionary = p_data["avatar_settings"]
	var center_point := stat_panel.find_child("CenterPoint", true, false)
	if not center_point:
		return
	_set_avatar_layer(center_point, "BodySprite", settings.get("skin_path", ""))
	_set_avatar_layer(center_point, "EyeSprite", settings.get("face_path", ""))
	_set_avatar_layer(center_point, "OutfitSprite", settings.get("outfit_path", ""))
	_set_avatar_layer(center_point, "HairSprite", settings.get("hair_path", ""))
	_set_avatar_layer(center_point, "AccessorySprite", settings.get("accessory_path", ""))


func _set_avatar_layer(center_point: Node, node_name: String, texture_path: String) -> void:
	if texture_path.is_empty():
		return
	var sprite := center_point.get_node_or_null(node_name) as Sprite2D
	if sprite:
		sprite.texture = load(texture_path)


func _update_stats_ui(stat_panel: Node, player_index: int) -> void:
	var p_data: Dictionary = Global.player_data[player_index] if Global.player_data.size() > player_index else {}
	var money_label := stat_panel.find_child("money", true, false) as Label
	if money_label:
		money_label.text = "%d ฿" % int(p_data.get("money", 0))

	var stats_data: Dictionary = p_data.get("stats", {})
	for stat_name: String in STAT_CONFIG:
		var config: Dictionary = STAT_CONFIG[stat_name]
		var bar := stat_panel.find_child(config.bar, true, false) as ProgressBar
		var value_label := stat_panel.find_child(config.value, true, false) as Label
		var value := float(stats_data.get(stat_name, 0))
		var max_value := float(config.max)
		var percent := clampf((value / max_value) * 100.0, 0.0, 100.0)
		if bar:
			bar.value = percent
		if value_label:
			value_label.text = "%d/%d" % [int(value), int(max_value)]


func _set_card_active(stat_panel: Control, player_index: int, is_active: bool) -> void:
	var portrait := stat_panel.find_child("PortraitBackground1", true, false) as TextureRect
	if portrait:
		portrait.texture = BORDER_ACTIVE if is_active else BORDER_NORMAL
	var body := stat_panel.find_child("Body", true, false) as HBoxContainer
	if body:
		body.visible = true
		body.alignment = BoxContainer.ALIGNMENT_BEGIN if is_active else BoxContainer.ALIGNMENT_CENTER
	var stats_container := stat_panel.find_child("Stats", true, false) as Control
	if stats_container:
		stats_container.visible = is_active
	var money_caption := stat_panel.find_child("MoneyCaption", true, false) as Control
	if money_caption:
		money_caption.visible = is_active
	var money_value := stat_panel.find_child("money", true, false) as Control
	if money_value:
		money_value.visible = is_active
	var header := stat_panel.find_child("Header", true, false) as HBoxContainer
	if header:
		header.alignment = BoxContainer.ALIGNMENT_BEGIN if is_active else BoxContainer.ALIGNMENT_CENTER
	var header_spacer := stat_panel.find_child("Spacer", true, false) as Control
	if header_spacer:
		header_spacer.visible = is_active
	var badge := stat_panel.find_child("ActiveBadge", true, false) as Control
	if badge:
		badge.visible = is_active
	_apply_card_layout(stat_panel, player_index, is_active)
	if stat_panel is PanelContainer:
		stat_panel.add_theme_stylebox_override("panel", _make_card_style(is_active))
	stat_panel.modulate = Color.WHITE if is_active else Color(0.94, 0.91, 0.86, 0.98)


func _apply_card_layout(stat_panel: Control, player_index: int, is_active: bool) -> void:
	var card_size := FULL_CARD_SIZE if is_active else COMPACT_CARD_SIZE
	var is_right := player_index == 1 or player_index == 3
	var is_bottom := player_index >= 2

	stat_panel.custom_minimum_size = card_size
	if is_right:
		stat_panel.offset_right = -CARD_SIDE_MARGIN
		stat_panel.offset_left = stat_panel.offset_right - card_size.x
	else:
		stat_panel.offset_left = CARD_SIDE_MARGIN
		stat_panel.offset_right = stat_panel.offset_left + card_size.x

	if is_bottom:
		stat_panel.offset_bottom = -CARD_BOTTOM_MARGIN
		stat_panel.offset_top = stat_panel.offset_bottom - card_size.y
	else:
		stat_panel.offset_top = CARD_TOP_OFFSET
		stat_panel.offset_bottom = stat_panel.offset_top + card_size.y


func _make_card_style(is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7e3bff7") if is_active else Color("f1dfc4f2")
	style.border_color = Color("8e341fff") if is_active else Color("9f6a50e6")
	style.set_border_width_all(3 if is_active else 2)
	style.set_corner_radius_all(9)
	if is_active:
		style.shadow_color = Color(0.18, 0.07, 0.035, 0.36)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 3)
	return style


func update_mission(mission_text: String) -> void:
	if mission_details:
		mission_details.text = mission_text
		if mission_panel and not mission_panel.visible:
			mission_panel.show()

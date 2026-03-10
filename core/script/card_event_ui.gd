extends Control

# ---------------------------------------------------------------
# CARD EVENT UI
# Attach this script to the "Cardevent" CanvasLayer node.
#
# Scene structure expected:
#   Cardevent (CanvasLayer)   ← this node
#     ColorRect
#     Panel (TextureRect)
#       VBoxContainer
#         TitleLabel
#         DescLabel
#         OKButton           ← used for instant events / single confirm
#         ChoiceAButton      ← used for choice events (option A)
#         ChoiceBButton      ← used for choice events (option B)
#         ChoiceCButton      ← used for 3-choice events (option C, optional)
#
# If ChoiceAButton / ChoiceBButton don't exist yet in your scene,
# add them as siblings of OKButton inside the VBoxContainer.
# ---------------------------------------------------------------

signal event_resolved()

@onready var title_label: Label       = $Panel/VBoxContainer/TitleLabel
@onready var desc_label: Label        = $Panel/VBoxContainer/DescLabel
@onready var ok_button: Button        = $Panel/VBoxContainer/OKButton
@onready var choice_a: Button         = $Panel/VBoxContainer/ChoiceAButton
@onready var choice_b: Button         = $Panel/VBoxContainer/ChoiceBButton
@onready var choice_c: Button         = $Panel/VBoxContainer/ChoiceCButton

var _card_event_manager: Node = null
var _pending_events: Array[Dictionary] = []
var _current_event: Dictionary = {}
var _is_showing: bool = false

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok_pressed)
	choice_a.pressed.connect(_on_choice_pressed.bind(0))
	choice_b.pressed.connect(_on_choice_pressed.bind(1))
	choice_c.pressed.connect(_on_choice_pressed.bind(2))

## Sets the reference to the CardEventManager autoload/node
func set_card_event_manager(manager: Node) -> void:
	_card_event_manager = manager
	_card_event_manager.card_event_requested.connect(_on_card_event_requested)

## Enqueue an event to show; displays immediately if nothing is showing
func _on_card_event_requested(event_data: Dictionary) -> void:
	_pending_events.append(event_data)
	if not _is_showing:
		_show_next()

## Show the next queued card
func _show_next() -> void:
	if _pending_events.is_empty():
		_is_showing = false
		visible = false
		event_resolved.emit()
		return

	_is_showing = true
	_current_event = _pending_events.pop_front()
	visible = true

	title_label.text = _current_event.get("title", "Event")
	desc_label.text  = _current_event.get("desc",  "")

	var event_type: String = _current_event.get("type", "instant")

	if event_type == "instant":
		_show_instant_layout()
	else:
		_show_choice_layout(_current_event.get("choices", []))

# ── LAYOUT HELPERS ──────────────────────────────────────────────

func _show_instant_layout() -> void:
	ok_button.visible = true
	ok_button.text = "รับทราบ"
	_build_effect_hint(ok_button, _current_event.get("effects", {}))
	choice_a.visible = false
	choice_b.visible = false
	choice_c.visible = false

func _show_choice_layout(choices: Array) -> void:
	ok_button.visible = false
	var btns: Array[Button] = [choice_a, choice_b, choice_c]
	for i in btns.size():
		if i < choices.size():
			btns[i].visible = true
			btns[i].text    = choices[i].get("label", "เลือก %d" % (i + 1))
			_build_effect_hint(btns[i], choices[i].get("effects", {}))
		else:
			btns[i].visible = false

## Appends a small stat-change hint to the button label, e.g. "ซื้อเลย!  💰-300 😊+10"
func _build_effect_hint(btn: Button, effects: Dictionary) -> void:
	if effects.is_empty():
		return
	var hints: Array[String] = []
	var icons = {
		"money":     "💰", "study":   "📚", "happy":   "😊",
		"energy":    "⚡", "hunger":  "🍚", "time":    "⏰",
		"time_pct":  "⏰-%", "next_round_time_pct": "⏰↓",
		"exam_bonus":"🎓+", "set_sick": "", "set_injured": ""
	}
	for key in effects:
		if key in ["set_sick", "set_injured", "set_weather", "skip_activity_ui"]:
			continue  # don't show boolean/string flags
		var icon = icons.get(key, key)
		var val  = effects[key]
		if val > 0:
			hints.append("%s+%d" % [icon, val])
		elif val < 0:
			hints.append("%s%d" % [icon, val])
	if hints.size() > 0:
		btn.text += "  " + "  ".join(hints)

# ── BUTTON CALLBACKS ────────────────────────────────────────────

func _on_ok_pressed() -> void:
	_apply_and_advance(_current_event.get("effects", {}))

func _on_choice_pressed(index: int) -> void:
	var choices = _current_event.get("choices", [])
	if index < choices.size():
		_apply_and_advance(choices[index].get("effects", {}))
	else:
		_show_next()

func _apply_and_advance(effects: Dictionary) -> void:
	if _card_event_manager:
		_card_event_manager.apply_effects(effects)
	_show_next()

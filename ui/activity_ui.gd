extends Control

signal activity_selected(activity_id: String)

@onready var npc_portrait: TextureRect = %NPCPortrait
@onready var leave_button: Button = %LeaveButton

@onready var npc_name_label: Label = %NPCNameLabel
@onready var dialog_label: Label = %DialogLabel
@onready var activity_buttons: Array[Button] = [
	%Activity1Btn,
	%Activity2Btn,
	%Activity3Btn,
	%Activity4Btn,
]

var activities: Array[Dictionary] = []


func _ready() -> void:
	for i in activity_buttons.size():
		activity_buttons[i].pressed.connect(_on_activity_pressed.bind(i))
	leave_button.pressed.connect(func(): visible = false)


## Call this to populate the panel before showing it.
## activity_list entries: full activity Dictionary from MapMananger
func setup(npc_name: String, portrait: Texture2D, dialog: String, activity_list: Array[Dictionary]) -> void:
	npc_name_label.text = npc_name
	
	dialog_label.text = dialog
	if portrait:
		npc_portrait.texture = portrait
	activities = activity_list
	for i in activity_buttons.size():
		if i < activities.size():
			activity_buttons[i].text = activities[i].get("name", "กิจกรรม %d" % (i + 1))
			activity_buttons[i].visible = true
			activity_buttons[i].disabled = not _check_requirements(activities[i])
		else:
			activity_buttons[i].visible = false


## Returns false if the player does not meet the activity's requirements.
func _check_requirements(activity: Dictionary) -> bool:
	# Auto-check money from the activity's cost field
	var money_cost: int = activity.get("money", 0)
	if money_cost < 0 and Global.money < -money_cost:
		return false
	# Check explicit requires dict
	var requires: Dictionary = activity.get("requires", {})
	for req in requires:
		match req:
			"energy":
				if Global.energy < requires[req]:
					return false
			"hunger":
				if Global.hunger < requires[req]:
					return false
			"happy":
				if Global.happy < requires[req]:
					return false
			"not_injured":
				if Global.is_injured:
					return false
			"not_sick":
				if Global.is_sick:
					return false
	return true


func _on_activity_pressed(index: int) -> void:
	if index < activities.size():
		activity_selected.emit(activities[index].get("id", str(index)))

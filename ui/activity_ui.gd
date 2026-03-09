extends Control

signal activity_selected(activity_id: String)

@onready var npc_portrait: TextureRect = %NPCPortrait

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


## Call this to populate the panel before showing it.
## activity_list entries: { "id": String, "name": String }
func setup(npc_name: String, portrait: Texture2D, dialog: String, activity_list: Array[Dictionary]) -> void:
	npc_name_label.text = npc_name
	
	dialog_label.text = dialog
	if portrait:
		npc_portrait.texture = portrait
	activities = activity_list
	for i in activity_buttons.size():
		if i < activities.size():
			activity_buttons[i].text = activities[i].get("name", "Activity %d" % (i + 1))
			activity_buttons[i].visible = true
		else:
			activity_buttons[i].visible = false


func _on_activity_pressed(index: int) -> void:
	if index < activities.size():
		activity_selected.emit(activities[index].get("id", str(index)))

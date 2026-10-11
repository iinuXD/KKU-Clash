extends Control

@onready var round_label = $VBoxContainer/RoundLabel
@onready var money_label = $Status/VBoxContainer/Money/MoneyAmount

@onready var energy_bar = $Status/VBoxContainer/EnergyBox/EnergyProgressBar
@onready var happy_bar = $Status/VBoxContainer/HappyBox/HappyProgressBar
@onready var study_bar = $Status/VBoxContainer/StudyBox/StudyProgressBar
@onready var hunger_bar =$Status/VBoxContainer/HungerBox/HungerProgressBar
@onready var timer_bar = $VBoxContainer/TimeProgessBar
@onready var main_quest = $FoldableContainer/VBoxContainer/miancontainer/main
@onready var sub_quest_injured = $FoldableContainer/VBoxContainer/subcontainer/subInjured
@onready var sub_quest_sick = $FoldableContainer/VBoxContainer/subcontainer/subSick

func _ready() -> void:
		sub_quest_injured.text = "[ภารกิจรอง] คุณบาดเจ็บ ไปโรงพยาบาลเพื่อรักษาตัว"
		sub_quest_sick.text = "[ภารกิจรอง] คุณป่วย ซื้อยาหรือพักผ่อนที่หอพัก"

func _process(delta: float) -> void:
	round_label.text = "รอบ: " + str(Global.current_round) + " / " + str(Global.max_rounds)
	money_label.text = "฿" + str(Global.money)
	
	energy_bar.value = Global.energy
	happy_bar.value = Global.happy
	study_bar.value = Global.study_score
	hunger_bar.value = Global.hunger
	timer_bar.value = Global.time_remaining
	
	# Quest labels
	main_quest.text = "[ภารกิจหลัก] เข้าเรียน: %d / 10" % Global.class_join_count
	sub_quest_injured.visible = Global.is_injured
	sub_quest_sick.visible = Global.is_sick

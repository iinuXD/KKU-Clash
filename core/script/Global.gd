extends Node

# Player Stats
var money: int = 2000
var study_score: int = 0
var happy: int = 40
var energy: int = 100
var hunger: int = 50

var current_round: int = 1
var max_rounds: int = 5

var time_remaining: int = 24 # Let's assume 24 "hours" or units per round
var max_time: int = 24

# Event Modifiers
var travel_time_cost: int = 2
var travel_energy_cost: int = 0
var is_injured: bool = false
var is_sick: bool = false

# Quests
var sick_sleep_count: int = 0
var has_medicine: bool = false
var lost_item_active: bool = false
var class_join_count: int = 0  # Main quest: join class 10 times

# Card Event modifiers
var exam_bonus_pct: int = 0
var next_round_time_penalty_pct: int = 0

# Weather state — reset to "normal" each round
# "normal" | "hot" (more energy per travel) | "heavy_rain" (more time per travel)
var weather: String = "normal"

# Set by canteen_full "eat outside" choice to skip the Food Court activity UI once
var skip_next_activity_ui: bool = false

# Helper function to keep stats between 0 and 100 (except money/study)
func update_stat(stat_name: String, amount: int):
	match stat_name:
		"happy": happy = clampi(happy + amount, 0, 100)
		"energy": energy = clampi(energy + amount, 0, 100)
		"hunger": hunger = clampi(hunger + amount, 0, 100)
		"money": money += amount
		"study_score": study_score += amount
		
# Select Player
# player count
var player_count: int = 1

# Array สำหรับเก็บข้อมูล ของแต่ละคน
var player_data: Array = []

# ฟังก์ชันสำหรับรีเซ็ตและเตรียมข้อมูลผู้เล่น
func setup_players(count: int) -> void:
	player_count = count
	player_data.clear()
	
	for i in range(player_count):
		player_data.append({})
	print(player_count)

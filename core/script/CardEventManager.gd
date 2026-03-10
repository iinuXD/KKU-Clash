extends Node

# ---------------------------------------------------------------
# CARD EVENT MANAGER
# Triggered twice per round:
#   - 2 cards at the START of each round  (end-of-round trigger)
#   - 2 cards MID-ROUND (probabilistic, called from spend_time)
#
# Each event is a Dictionary:
#   id        : unique string
#   title     : short name shown on card
#   desc      : flavour text
#   category  : "study" | "money" | "health" | "social" | "environment" | "exam" | "rare"
#   weight    : relative draw weight (rare events have lower weight)
#   type      : "instant" | "choice"
#   -- for instant events --
#   effects   : Dictionary { stat: delta, โ€ฆ }
#               special keys: "time_pct" (reduce time by % of max), "next_round_time_pct"
#   -- for choice events --
#   choices   : Array of { "label": String, "effects": Dictionary }
# ---------------------------------------------------------------

signal card_event_requested(event_data: Dictionary)
signal time_depleted()

# ---- WEIGHT POOLS ----
const WEIGHT_NORMAL = 10
const WEIGHT_RARE   = 2

var _all_events: Array[Dictionary] = []

func _ready() -> void:
	_build_event_pool()

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------

## Called at end of round โ’ draw 2 events from the Any-location pool
func draw_end_of_round_cards() -> void:
	var pool: Array[Dictionary] = []
	for ev in _all_events:
		if ev.get("location", "Any") == "Any":
			pool.append(ev)
	var drawn = _draw_cards(2, pool)
	for ev in drawn:
		card_event_requested.emit(ev)

## Called at start of each round โ’ draw 1-2 start-of-round events
func draw_start_round_events() -> void:
	var pool = _get_start_pool()
	if pool.is_empty():
		return
	var count = randi_range(1, 2)
	var drawn = _draw_cards(count, pool)
	for ev in drawn:
		card_event_requested.emit(ev)

## Called after player arrives at a location (not the return-to-dorm trip). ~40% chance.
## Returns true if an event fired.
func check_travel_event(location: String) -> bool:
	if randi() % 100 >= 40:
		return false
	var pool = _get_mid_pool(location)
	if pool.is_empty():
		return false
	card_event_requested.emit(_weighted_pick(pool))
	return true

## Called after player completes an activity. ~30% chance.
## Returns true if an event fired.
func check_activity_event(location: String) -> bool:
	if randi() % 100 >= 30:
		return false
	var pool = _get_act_pool(location)
	if pool.is_empty():
		return false
	card_event_requested.emit(_weighted_pick(pool))
	return true

# ---------------------------------------------------------------
# APPLY EFFECTS  (called by card_event_ui after player decides)
# ---------------------------------------------------------------
func apply_effects(effects: Dictionary) -> void:
	for key in effects:
		match key:
			"study":
				Global.update_stat("study_score", effects[key])
			"happy":
				Global.update_stat("happy", effects[key])
			"energy":
				Global.update_stat("energy", effects[key])
			"money":
				Global.update_stat("money", effects[key])
			"hunger":
				Global.update_stat("hunger", effects[key])
			"time":
				Global.time_remaining = maxi(Global.time_remaining + effects[key], 0)
			"time_pct":
				# Reduce current time remaining by a percentage of max_time
				var reduction = int(Global.max_time * effects[key] / 100.0)
				Global.time_remaining = maxi(Global.time_remaining - reduction, 0)
			"next_round_time_pct":
				# Applied at start of next round โ€” store in Global
				Global.next_round_time_penalty_pct += effects[key]
			"set_sick":
				Global.is_sick = effects[key]
			"set_injured":
				Global.is_injured = effects[key]
			"exam_bonus":
				Global.exam_bonus_pct += effects[key]
			"set_weather":
				Global.weather = effects[key]
			"skip_activity_ui":
				Global.skip_next_activity_ui = true
	if Global.time_remaining <= 0:
		time_depleted.emit()

# ---------------------------------------------------------------
# INTERNAL HELPERS
# ---------------------------------------------------------------
func _draw_cards(count: int, pool: Array[Dictionary]) -> Array[Dictionary]:
	if pool.is_empty():
		return []
	var result: Array[Dictionary] = []
	var remaining_pool = pool.duplicate()
	for i in count:
		if remaining_pool.is_empty():
			break
		var picked = _weighted_pick(remaining_pool)
		result.append(picked)
		remaining_pool.erase(picked)
	return result

func _get_start_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for ev in _all_events:
		if ev.get("round", "mid") == "start":
			pool.append(ev)
	return pool

## Events with round == "mid" or "both", filtered by location
func _get_mid_pool(location: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for ev in _all_events:
		var r = ev.get("round", "mid")
		if r not in ["mid", "both"]:
			continue
		var loc = ev.get("location", "Any")
		if loc == "Any" or loc == location:
			pool.append(ev)
	return pool

## Events with round == "act" or "both", filtered by location
func _get_act_pool(location: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for ev in _all_events:
		var r = ev.get("round", "mid")
		if r not in ["act", "both"]:
			continue
		var loc = ev.get("location", "Any")
		if loc == "Any" or loc == location:
			pool.append(ev)
	return pool

func _weighted_pick(pool: Array[Dictionary]) -> Dictionary:
	var total_weight = 0
	for ev in pool:
		total_weight += ev.get("weight", WEIGHT_NORMAL)
	var roll = randi() % total_weight
	var cumulative = 0
	for ev in pool:
		cumulative += ev.get("weight", WEIGHT_NORMAL)
		if roll < cumulative:
			return ev
	return pool[-1]  # fallback

# ---------------------------------------------------------------
# EVENT POOL DEFINITION
#
# Fields per event:
#   id       : unique string
#   title    : display name shown on card
#   desc     : flavour text
#   category : "money" | "health" | "environment" | "rare"
#   weight   : WEIGHT_NORMAL (10) or WEIGHT_RARE (2)
#   round    : "start" | "mid" | "act" | "both"
#              start = fires at start of round  (draw_start_round_events)
#              mid   = fires after arriving at a location (check_travel_event)
#              act   = fires after completing an activity (check_activity_event)
#              both  = fires in BOTH mid AND act contexts
#   location : "Any" | "Food Court" | "Study Hall" | etc.
#   type     : "instant" | "choice"
#   effects / choices : see header
# ---------------------------------------------------------------
func _build_event_pool() -> void:
	_all_events.clear()

# --------------------------------------------------------------
# START-OF-ROUND EVENTS  (round: "start")
# --------------------------------------------------------------

	_all_events.append({
		"id": "storm",
		"title": "พายุเข้า! 🌪️",
		"desc": "พายุพัดถล่มทั้งวัน การเดินทางช้าลงมากและเหนื่อยง่ายขึ้น",
		"category": "environment",
		"weight": WEIGHT_RARE,
		"round": "start",
		"location": "Any",
		"type": "instant",
		"effects": {"set_weather": "heavy_rain"}
	})

	_all_events.append({
		"id": "hot_weather",
		"title": "อากาศร้อนจัด! ☀️",
		"desc": "แดดแผดเผา เดินแป๊บเดียวก็เหนื่อยแล้ว การเดินทางเสียพลังงานมากขึ้น",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"round": "start",
		"location": "Any",
		"type": "instant",
		"effects": {"set_weather": "hot"}
	})

	_all_events.append({
		"id": "wake_up_late",
		"title": "ตื่นสาย!",
		"desc": "นาฬิกาไม่ดัง... เวลาในวันนี้หายไปหลายชั่วโมงเลย",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"round": "start",
		"location": "Any",
		"type": "instant",
		"effects": {"time_pct": 25}
	})

	_all_events.append({
		"id": "get_sick",
		"title": "ป่วยกะทันหัน!",
		"desc": "ตื่นมาเช้านี้รู้สึกไม่สบายเลย จะทำอย่างไรดี?",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"round": "start",
		"location": "Any",
		"type": "choice",
		"choices": [
			{"label": "ไปโรงพยาบาลทันที (-฿200, -2ชม.)", "effects": {"set_sick": false, "money": -200, "time": -2}}, # แก้ false เป็น False
			{"label": "ฝืนทนไปก่อน",                       "effects": {"set_sick": true, "energy": -20}}, # แก้ true เป็น True
		]
	})

	_all_events.append({
		"id": "money_from_family",
		"title": "ผู้ปกครองโอนเงินให้! 💸",
		"desc": "โทรศัพท์ดัง มีเงินโอนมาจากบ้าน 3,000 บาท!",
		"category": "money",
		"weight": WEIGHT_RARE,
		"round": "start",
		"location": "Any",
		"type": "choice",
		"choices": [
			{"label": "รับไว้ใช้เอง",     "effects": {"money": 3000, "happy": 10}},
			{"label": "แบ่งบริจาคเพื่อน", "effects": {"money": 1500, "happy": 30}},
		]
	})

	# --------------------------------------------------------------
	# MID-ROUND EVENTS — after travel  (round: "mid")
	# --------------------------------------------------------------

	_all_events.append({
		"id": "canteen_full",
		"title": "โรงอาหารเต็ม!",
		"desc": "คนแน่นมากเลย ต้องรอคิวนานหรือหาซื้อที่อื่นแทน",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"round": "mid",
		"location": "Food Court",
		"type": "choice",
		"choices": [
			{"label": "ซื้อกินข้างนอก 7-11 (-฿200)", "effects": {"money": -200, "hunger": 25, "skip_activity_ui": true}}, # แก้ true เป็น True
			{"label": "รอคิว (-1ชม.)",                "effects": {"time": -1}},
		]
	})

	_all_events.append({
		"id": "minor_accident",
		"title": "อุบัติเหตุระหว่างทาง!",
		"desc": "สะดุดล้มข้างถนน เข่าถลอก การเดินทางต่อไปใช้เวลานานขึ้น",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"round": "mid",
		"location": "Any",
		"type": "instant",
		"effects": {"set_injured": true, "energy": -10} # แก้ true เป็น True
	})

	_all_events.append({
		"id": "money_lost",
		"title": "เงินหาย!",
		"desc": "หยิบกระเป๋าเช็คดู เงินหายไป 300 บาท คงตกระหว่างเดินทาง",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"round": "mid",
		"location": "Any",
		"type": "instant",
		"effects": {"money": -300}
	})

	# --------------------------------------------------------------
	# ACTIVITY EVENTS — after activity done  (round: "act")
	# --------------------------------------------------------------

	_all_events.append({
		"id": "food_poison",
		"title": "อาหารเป็นพิษ!",
		"desc": "ท้องเสียหลังทานข้าวที่โรงอาหาร ร่างกายอ่อนแอมาก",
		"category": "health",
		"weight": WEIGHT_RARE,
		"round": "act",
		"location": "Food Court",
		"type": "instant",
		"effects": {"set_sick": true, "hunger": -20, "energy": -15} # แก้ true เป็น True
	})

	# --------------------------------------------------------------
	# BOTH — after travel OR after activity  (round: "both")
	# --------------------------------------------------------------

	_all_events.append({
		"id": "heavy_rain",
		"title": "ฝนตกอย่างหนัก! 🌧️",
		"desc": "ฝนถล่มกะทันหัน การเดินทางต่อไปจะช้าลงมาก",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"round": "both",
		"location": "Any",
		"type": "instant",
		"effects": {"set_weather": "heavy_rain"}
	})

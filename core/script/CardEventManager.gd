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
#   effects   : Dictionary { stat: delta, … }
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
var _mid_round_pending: Array[Dictionary] = []  # queue for mid-round cards

# % chance per spend_time call to pop the next pre-queued mid-round card.
# Max 2 events possible per round (limited by queue size from queue_mid_round_cards).
const _MID_ROUND_TRIGGER_PCT: int = 15

func _ready() -> void:
	_build_event_pool()

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------

## Called by GameMananger at end of each round → show 2 end-of-round cards
func draw_end_of_round_cards() -> void:
	var drawn = _draw_cards(2, _get_pool_excluding([]))
	for ev in drawn:
		card_event_requested.emit(ev)

## Called by GameMananger.spend_time() → pops one pre-queued mid-round card (15% chance).
## At most 2 mid-round events per round because the queue holds exactly 2 cards.
func check_mid_round_cards() -> bool:
	if _mid_round_pending.is_empty():
		return false
	if randi() % 100 >= _MID_ROUND_TRIGGER_PCT:
		return false
	var ev = _mid_round_pending.pop_front()
	card_event_requested.emit(ev)
	return true

## Called by GameMananger at the start of a ROUND to queue 2 cards shown during play
func queue_mid_round_cards() -> void:
	_mid_round_pending = _draw_cards(2, _get_pool_excluding([]))

## Called by GameMananger at the start of a round → draws 1 environment/start-of-round event
func draw_start_round_card() -> void:
	var pool = _get_pool_for_trigger("start_round")
	if pool.is_empty():
		pool = _get_pool_excluding([])  # fallback to general pool
	var drawn = _draw_cards(1, pool)
	for ev in drawn:
		card_event_requested.emit(ev)

## If a queued card is awaiting display, pop and emit it
func pop_queued_card() -> bool:
	if _mid_round_pending.size() == 0:
		return false
	var ev = _mid_round_pending.pop_front()
	card_event_requested.emit(ev)
	return true

## Fires one random event matching the trigger context (e.g. "travel", "eat", "start_round").
## Returns true if an event was emitted.
func check_contextual_event(trigger: String, chance_pct: int = 100) -> bool:
	if randi() % 100 >= chance_pct:
		return false
	var pool = _get_pool_for_trigger(trigger)
	if pool.is_empty():
		return false
	var ev = _weighted_pick(pool)
	card_event_requested.emit(ev)
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
				# Applied at start of next round — store in Global
				Global.next_round_time_penalty_pct += effects[key]
			"set_sick":
				Global.is_sick = effects[key]
			"set_injured":
				Global.is_injured = effects[key]
			"exam_bonus":
				Global.exam_bonus_pct += effects[key]
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

func _get_pool_excluding(excluded_categories: Array) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for ev in _all_events:
		# Exclude trigger-specific events so they only fire in their context
		if not (ev["category"] in excluded_categories) and ev.get("trigger", "any") == "any":
			pool.append(ev)
	return pool

func _get_pool_for_trigger(trigger: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for ev in _all_events:
		if ev.get("trigger", "any") == trigger:
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
# ---------------------------------------------------------------
func _build_event_pool() -> void:
	_all_events.clear()

	# ──────────────────────────────────────────
	# STUDY EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "study_random_question",
		"title": "อาจารย์สุ่มถามในห้อง",
		"desc": "อาจารย์ชี้มาที่คุณ... คุณพร้อมตอบไหม?",
		"category": "study",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ตอบได้!",     "effects": {"study": 10, "happy": 5}},
			{"label": "ตอบไม่ได้", "effects": {}},
		]
	})

	_all_events.append({
		"id": "study_late_submission",
		"title": "ส่งงานไม่ทัน!",
		"desc": "งานที่ค้างอยู่ต้องส่งเดี๋ยวนี้เลย",
		"category": "study",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ส่งใหม่เดี๋ยวนี้", "effects": {"energy": -10}},
			{"label": "ไม่ส่ง",            "effects": {"study": -15}},
		]
	})

	_all_events.append({
		"id": "study_urgent_group",
		"title": "งานกลุ่มเร่งด่วน!",
		"desc": "เพื่อนส่งข้อความว่างานกลุ่มต้องส่งพรุ่งนี้เช้า",
		"category": "study",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ทำเลย!",  "effects": {"study": 15, "energy": -15}},
			{"label": "ปล่อยผ่าน", "effects": {"study": -20}},
		]
	})

	_all_events.append({
		"id": "study_friend_ditched",
		"title": "เพื่อนเทงาน",
		"desc": "เพื่อนร่วมกลุ่มหายไปไหนก็ไม่รู้ ต้องทำคนเดียว",
		"category": "study",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"energy": -20}
	})

	# ──────────────────────────────────────────
	# MONEY EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "money_parent_transfer",
		"title": "ผู้ปกครองโอนเงินพิเศษ!",
		"desc": "โทรศัพท์ดัง มีเงินเข้าบัญชี 1,000 บาท!",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"money": 1000}
	})

	_all_events.append({
		"id": "money_lost",
		"title": "เงินหาย!",
		"desc": "เช็คกระเป๋าสตังค์แล้วเงิน 500 บาทหายไป",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"money": -500}
	})

	_all_events.append({
		"id": "money_sale",
		"title": "เจอของลดราคา!",
		"desc": "ของที่อยากได้ลดราคา 50% วันนี้วันเดียว!",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ซื้อเลย!",     "effects": {"money": -300, "happy": 10}},
			{"label": "ไม่เป็นไร", "effects": {}},
		]
	})

	_all_events.append({
		"id": "money_part_time",
		"title": "งานพิเศษด่วน!",
		"desc": "มีงานพิเศษด่วนๆ ให้ทำ ค่าตอบแทน 200 บาท",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "รับงาน", "effects": {"money": 200, "energy": -20}},
			{"label": "ปฏิเสธ", "effects": {}},
		]
	})

	_all_events.append({
		"id": "money_library_fine",
		"title": "ค่าปรับห้องสมุด",
		"desc": "คืนหนังสือช้า โดนปรับ 100 บาท",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"money": -100}
	})

	_all_events.append({
		"id": "money_found_item",
		"title": "เจอของหาย",
		"desc": "เก็บของที่หล่นแล้วนำไปคืน ได้รับรางวัล 200 บาท!",
		"category": "money",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"money": 200}
	})

	# ──────────────────────────────────────────
	# HEALTH EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "health_sudden_sick",
		"title": "ป่วยกะทันหัน!",
		"desc": "รู้สึกไม่สบาย ต้องไปโรงพยาบาล",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ไปโรงพยาบาล + ซื้อยา", "effects": {"set_sick": false}},
			{"label": "ไปโรงพยาบาล ไม่ซื้อยา", "effects": {"energy": -10, "set_sick": true}},
			{"label": "อยู่บ้าน",                 "effects": {"energy": -30, "set_sick": true}},
		]
	})

	_all_events.append({
		"id": "health_food_poison",
		"title": "อาหารเป็นพิษ!",
		"desc": "ท้องเสียหลังทานข้าว ร่างกายอ่อนแอมาก",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"trigger": "eat",
		"effects": {"hunger": -30, "energy": -20}
	})

	_all_events.append({
		"id": "health_exercise_refresh",
		"title": "ออกกำลังกายแล้วสดชื่น!",
		"desc": "วิ่งรอบมหาลัยตอนเช้า รู้สึกสดใสมาก",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"happy": 10, "energy": 5}
	})

	_all_events.append({
		"id": "health_stress",
		"title": "เครียดสะสม",
		"desc": "ความกดดันสะสมมานาน ส่งผลต่อจิตใจ",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"happy": -20}
	})

	_all_events.append({
		"id": "health_leg_injury",
		"title": "วิ่งล้มขาเจ็บ!",
		"desc": "สะดุดหินล้มหัวเข่าถลอก เดินช้าลงทั้งวัน",
		"category": "health",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"trigger": "travel",
		"effects": {"time_pct": 15}
	})

	# ──────────────────────────────────────────
	# SOCIAL EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "social_friend_trip",
		"title": "เพื่อนชวนเที่ยว!",
		"desc": "เพื่อนชวนออกไปเที่ยวด้วยกัน จะไปไหม?",
		"category": "social",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ไปด้วย!",  "effects": {"happy": 25, "money": -300, "energy": -15}},
			{"label": "ไม่ไป",    "effects": {"happy": -5}},
		]
	})

	_all_events.append({
		"id": "social_concert",
		"title": "งานคอนเสิร์ตมหาลัย!",
		"desc": "มีคอนเสิร์ตในมหาวิทยาลัย บรรยากาศดีมาก",
		"category": "social",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "ไปชม!",  "effects": {"happy": 30, "energy": -15}},
			{"label": "ไม่ไป", "effects": {"happy": -5}},
		]
	})

	_all_events.append({
		"id": "social_heavy_activity",
		"title": "รับน้องกิจกรรมหนัก",
		"desc": "กิจกรรมรับน้องสุดเหนื่อย แต่ได้ความสัมพันธ์ที่ดี",
		"category": "social",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"happy": 20, "energy": -25}
	})

	_all_events.append({
		"id": "social_new_friend",
		"title": "ได้เพื่อนใหม่!",
		"desc": "นั่งคุยกับคนแปลกหน้าในโรงอาหาร กลายเป็นเพื่อนกัน",
		"category": "social",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"happy": 15}
	})

	_all_events.append({
		"id": "social_roommate_fight",
		"title": "ทะเลาะกับรูมเมท",
		"desc": "เรื่องเล็กน้อยลุกลามกลายเป็นเรื่องใหญ่",
		"category": "social",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"happy": -15, "energy": -5}
	})

	# ──────────────────────────────────────────
	# ENVIRONMENT EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "env_heavy_rain",
		"title": "ฝนตกหนัก!",
		"desc": "ฝนถล่มมหาลัย เดินลำบากมาก",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"trigger": "start_round",
		"effects": {"energy": -10}
	})

	_all_events.append({
		"id": "env_power_outage",
		"title": "ไฟหอดับ!",
		"desc": "ไฟฟ้าดับในหอ อ่านหนังสือไม่ได้ทั้งคืน",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"trigger": "start_round",
		"effects": {"energy": -5, "happy": -5}
	})

	_all_events.append({
		"id": "env_hot_weather",
		"title": "อากาศร้อนจัด!",
		"desc": "แดดแผดเผา เดินออกนอกอาคารแป๊บเดียวเหนื่อยแล้ว",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"trigger": "start_round",
		"effects": {"energy": -10, "hunger": -5}
	})

	_all_events.append({
		"id": "env_canteen_full",
		"title": "โรงอาหารเต็ม!",
		"desc": "โรงอาหารแน่น ต้องเดินหาร้านอื่นซื้อกิน",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"trigger": "eat",
		"effects": {"money": -50, "time": -1}
	})

	_all_events.append({
		"id": "env_shuttle_late",
		"title": "รถชัตเติลบัสมาช้า",
		"desc": "รถไม่มาซักที จะรอหรือจะเรียกแท็กซี่?",
		"category": "environment",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"trigger": "travel",
		"choices": [
			{"label": "รอ",            "effects": {"time": -2}},
			{"label": "เรียกแท็กซี่", "effects": {"money": -30}},
		]
	})

	# ──────────────────────────────────────────
	# EXAM EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "exam_forgot_id",
		"title": "ลืมบัตรนักศึกษา!",
		"desc": "ถึงสนามสอบแล้วถึงได้รู้ว่าลืมบัตร",
		"category": "exam",
		"weight": WEIGHT_NORMAL,
		"type": "choice",
		"choices": [
			{"label": "กลับไปเอา",  "effects": {"energy": -20}},
			{"label": "ฝากเข้า",    "effects": {"study": -10}},
		]
	})

	_all_events.append({
		"id": "exam_sit_near_smart",
		"title": "นั่งใกล้เพื่อนเก่ง",
		"desc": "โชคดีได้นั่งติดเพื่อนที่เตรียมตัวมาอย่างดี",
		"category": "exam",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"study": 5}
	})

	_all_events.append({
		"id": "exam_pre_stress",
		"title": "เครียดก่อนสอบ",
		"desc": "ยิ่งใกล้สอบยิ่งกังวล นอนไม่หลับทั้งคืน",
		"category": "exam",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"happy": -20}
	})

	_all_events.append({
		"id": "exam_did_great",
		"title": "ทำข้อสอบได้ดี!",
		"desc": "ข้อสอบออกตรงที่ท่อง ทำได้ลื่นมาก!",
		"category": "exam",
		"weight": WEIGHT_NORMAL,
		"type": "instant",
		"effects": {"exam_bonus": 10, "happy": 10}
	})

	# ──────────────────────────────────────────
	# RARE EVENTS
	# ──────────────────────────────────────────
	_all_events.append({
		"id": "rare_scholarship",
		"title": "ได้ทุนการศึกษา! ✨",
		"desc": "ประกาศผลทุน ชื่อคุณอยู่ในรายชื่อ!",
		"category": "rare",
		"weight": WEIGHT_RARE,
		"type": "instant",
		"effects": {"money": 3000, "happy": 20}
	})

	_all_events.append({
		"id": "rare_health_crash",
		"title": "สุขภาพทรุดหนัก!",
		"desc": "ร่างกายสะสมความเครียดมานานจนพัง",
		"category": "rare",
		"weight": WEIGHT_RARE,
		"type": "instant",
		"effects": {"energy": -40}
	})

	_all_events.append({
		"id": "rare_theft",
		"title": "โดนขโมยของ!",
		"desc": "กลับมาที่หอแล้วของหายไปทั้งกอง",
		"category": "rare",
		"weight": WEIGHT_RARE,
		"type": "instant",
		"effects": {"money": -1000}
	})

	_all_events.append({
		"id": "rare_competition_win",
		"title": "ชนะการแข่งขันกิจกรรม! 🏆",
		"desc": "ส่งผลงานเข้าประกวด ปรากฏว่าได้รางวัลชนะเลิศ!",
		"category": "rare",
		"weight": WEIGHT_RARE,
		"type": "instant",
		"effects": {"happy": 30, "study": 10}
	})

	_all_events.append({
		"id": "rare_minor_accident",
		"title": "อุบัติเหตุเล็กน้อย",
		"desc": "สะดุดและล้มหัวเข่าฉีก ต้องแวะโรงพยาบาล",
		"category": "rare",
		"weight": WEIGHT_RARE,
		"type": "instant",
		"effects": {"energy": -20, "set_injured": true}
	})

	_all_events.append({
		"id": "rare_storm",
		"title": "พายุเข้า! 🌪",
		"desc": "พายุพัดถล่มทั้งวัน ออกนอกบ้านแทบไม่ได้",
		"category": "rare",
		"weight": WEIGHT_RARE,
		"type": "instant",
		"effects": {"time_pct": 40}
	})

	# ──────────────────────────────────────────
	# UNUSED — pending trigger assignment
	# These fire at wrong times without a trigger; add "trigger" key when ready.
	# ──────────────────────────────────────────

	#_all_events.append({
	#	"id": "study_wake_up_late",
	#	"title": "ตื่นสาย!",
	#	"desc": "นาฬิกาไม่ดัง... เวลาเรียนวันนี้หายไปเลย",
	#	"category": "study",
	#	"weight": WEIGHT_NORMAL,
	#	"type": "instant",
	#	"trigger": "start_round",  # TODO: uncomment trigger when ready
	#	"effects": {"time_pct": 20}
	#})

	#_all_events.append({
	#	"id": "health_sleep_late",
	#	"title": "นอนดึกหลายวัน",
	#	"desc": "สะสมการอดนอนมานาน ร่างกายเริ่มประท้วง",
	#	"category": "health",
	#	"weight": WEIGHT_NORMAL,
	#	"type": "instant",
	#	"trigger": "start_round",  # TODO: uncomment trigger when ready
	#	"effects": {"energy": -20}
	#})

	#_all_events.append({
	#	"id": "env_lost_in_campus",
	#	"title": "หลงทางใน ม.!",
	#	"desc": "ตึกใหม่ ป้ายไม่ชัด หลงอยู่นานมาก",
	#	"category": "environment",
	#	"weight": WEIGHT_NORMAL,
	#	"type": "instant",
	#	"trigger": "travel",  # TODO: uncomment trigger when ready
	#	"effects": {"time_pct": 15}
	#})

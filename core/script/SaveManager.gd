extends Node

signal save_written(slot: int, success: bool, message: String)

const SAVE_SCHEMA_VERSION := 1
const SLOT_COUNT := 4
const SAVE_DIRECTORY := "user://"

var active_slot: int = -1
var checkpoint: Dictionary = {}
var pending_load: Dictionary = {}
var last_error: String = ""


func start_new_game() -> void:
	active_slot = -1
	checkpoint.clear()
	pending_load.clear()
	last_error = ""
	if Global.has_method("reset_game_state"):
		Global.reset_game_state()


func set_checkpoint(state: Dictionary) -> void:
	checkpoint = state.duplicate(true)


func has_checkpoint() -> bool:
	return not checkpoint.is_empty()


func has_pending_load() -> bool:
	return not pending_load.is_empty()


func take_pending_load() -> Dictionary:
	var state := pending_load.duplicate(true)
	pending_load.clear()
	return state


func prepare_load(slot: int) -> bool:
	last_error = ""
	var payload := _read_slot(slot)
	if payload.is_empty():
		return false

	var game_state = payload.get("game", {})
	if not game_state is Dictionary or game_state.is_empty():
		last_error = "ไฟล์เซฟไม่มีข้อมูลการเล่น"
		return false

	active_slot = slot
	pending_load = game_state.duplicate(true)
	checkpoint = game_state.duplicate(true)
	return true


func save_checkpoint(slot: int) -> bool:
	last_error = ""
	if not _is_valid_slot(slot):
		last_error = "ช่องเซฟไม่ถูกต้อง"
		save_written.emit(slot, false, last_error)
		return false
	if checkpoint.is_empty():
		last_error = "ยังไม่มีจุดจบเทิร์นที่สามารถบันทึกได้"
		save_written.emit(slot, false, last_error)
		return false

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SAVE_DIRECTORY)
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		last_error = "ไม่สามารถสร้างโฟลเดอร์เซฟได้"
		save_written.emit(slot, false, last_error)
		return false

	var payload := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"metadata": _make_metadata(slot),
		"game": checkpoint.duplicate(true)
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		last_error = "ไม่สามารถเขียนไฟล์เซฟได้"
		save_written.emit(slot, false, last_error)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	active_slot = slot
	save_written.emit(slot, true, "บันทึกช่อง %d แล้ว" % slot)
	return true


func autosave_checkpoint() -> bool:
	if active_slot < 1:
		return false
	return save_checkpoint(active_slot)


func get_slot_info(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"slot": slot, "exists": false, "valid": false}
	if not FileAccess.file_exists(_slot_path(slot)):
		return {"slot": slot, "exists": false, "valid": true}

	var payload := _read_slot(slot)
	if payload.is_empty():
		return {
			"slot": slot,
			"exists": true,
			"valid": false,
			"error": last_error
		}

	var metadata = payload.get("metadata", {})
	if not metadata is Dictionary:
		metadata = {}
	var info: Dictionary = metadata.duplicate(true)
	info["slot"] = slot
	info["exists"] = true
	info["valid"] = true
	return info


func get_all_slot_info() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		slots.append(get_slot_info(slot))
	return slots


func _make_metadata(slot: int) -> Dictionary:
	var map_state: Dictionary = checkpoint.get("map", {})
	var minutes_list: Array = map_state.get("player_minutes", [])
	var player_index := int(map_state.get("current_player_index", 0))
	var minutes := 360
	if player_index >= 0 and player_index < minutes_list.size():
		minutes = int(minutes_list[player_index])

	return {
		"slot": slot,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"saved_unix": int(Time.get_unix_time_from_system()),
		"round": int(map_state.get("current_round", 1)),
		"max_rounds": int(map_state.get("max_rounds", 11)),
		"current_player": player_index + 1,
		"player_count": int(checkpoint.get("global", {}).get("player_count", 1)),
		"minutes": minutes
	}


func _read_slot(slot: int) -> Dictionary:
	last_error = ""
	if not _is_valid_slot(slot):
		last_error = "ช่องเซฟไม่ถูกต้อง"
		return {}

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		last_error = "ไม่พบไฟล์เซฟ"
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "ไม่สามารถเปิดไฟล์เซฟได้"
		return {}

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		last_error = "ไฟล์เซฟเสียหายหรืออ่านไม่ได้"
		return {}

	var payload: Dictionary = json.data
	var version := int(payload.get("schema_version", 0))
	if version <= 0 or version > SAVE_SCHEMA_VERSION:
		last_error = "เวอร์ชันไฟล์เซฟไม่รองรับ"
		return {}
	return payload


func _slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIRECTORY, slot]


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT

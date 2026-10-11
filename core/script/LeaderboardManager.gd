extends Node

const LEADERBOARD_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 10

var entries: Array[Dictionary] = []


func _ready() -> void:
	_load_entries()


func record_scores(scores: Array[Dictionary]) -> void:
	for score_entry in scores:
		var score := int(score_entry.get("score", 0))
		entries.append({
			"name": str(score_entry.get("name", "ผู้เล่น")),
			"score": score,
			"recorded_at": int(Time.get_unix_time_from_system())
		})

	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first.get("score", 0)) == int(second.get("score", 0)):
			return int(first.get("recorded_at", 0)) < int(second.get("recorded_at", 0))
		return int(first.get("score", 0)) > int(second.get("score", 0))
	)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	_save_entries()


func get_entries() -> Array[Dictionary]:
	return entries.duplicate(true)


func _load_entries() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return

	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open leaderboard settings")
		return

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Array:
		push_error("Unable to parse leaderboard data")
		return

	entries.clear()
	for entry in json.data:
		if entry is Dictionary:
			entries.append({
				"name": str(entry.get("name", "ผู้เล่น")),
				"score": int(entry.get("score", 0)),
				"recorded_at": int(entry.get("recorded_at", 0))
			})
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first.get("score", 0)) > int(second.get("score", 0))
	)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)


func _save_entries() -> void:
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save leaderboard data")
		return
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()

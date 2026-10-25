extends SceneTree

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	var sandbox := OS.get_environment("KKU_TEST_SANDBOX").replace("\\", "/").to_lower()
	if sandbox.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox + "/"):
		quit(3)
		return
	var saves = root.get_node("SaveManager")
	var state = root.get_node("Global")
	if not saves.prepare_load(3):
		print("LOAD PROBE ERROR: ", saves.last_error)
		quit(3)
		return
	var game = load("res://locations/NewMap.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var output := FileAccess.open("user://load_probe.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"players": state.player_data, "round": game.current_round, "player": game.current_player_index, "minutes": game.current_minutes, "speeds": game.player_time_speed_multipliers, "scenarios": game.occurred_scenarios}))
	output.close()
	quit()

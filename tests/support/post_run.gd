extends GutHookScript

func run() -> void:
	# Allow the headless audio thread to release its looping MP3 decoder
	# before the runner quits. This is test-process teardown only.
	var audio = gut.get_node("/root/AudioManager")
	audio.music_player.stop()
	audio.music_player.stream = null
	await gut.get_tree().create_timer(0.15, true, false, true).timeout
	var output := OS.get_environment("KKU_TEST_RESULTS")
	if output.is_empty():
		return
	var exporter = load("res://addons/gut/result_exporter.gd").new()
	var result: Dictionary = exporter.get_results_dictionary(gut)
	result["engine_version"] = Engine.get_version_info()["string"]
	result["seed"] = 20261026
	result["user_data_dir"] = OS.get_user_data_dir()
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	if file == null:
		gut.logger.error("Cannot write test results")
		set_exit_code(2)
		return
	file.store_string(JSON.stringify(result, "\t"))

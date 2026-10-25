extends GutHookScript

func run() -> void:
	var output := OS.get_environment("KKU_TEST_RESULTS")
	if output.is_empty():
		return
	var exporter = load("res://addons/gut/result_exporter.gd").new()
	var result: Dictionary = exporter.get_results_dictionary(gut)
	result["engine_version"] = Engine.get_version_info()["string"]
	result["seed"] = 20261025
	result["user_data_dir"] = OS.get_user_data_dir()
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	if file == null:
		gut.logger.error("Cannot write test results")
		set_exit_code(2)
		return
	file.store_string(JSON.stringify(result, "\t"))

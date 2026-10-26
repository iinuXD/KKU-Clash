extends GutHookScript

func run() -> void:
	var sandbox := OS.get_environment("KKU_TEST_SANDBOX").replace("\\", "/").to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if sandbox.is_empty() or not user_path.begins_with(sandbox + "/"):
		gut.logger.error("Run tests using run-tests.cmd or tools/run-tests.ps1 so saves stay in the test sandbox.")
		set_exit_code(2)
		abort()
		return
	seed(20261026)
	gut.get_tree().root.size = Vector2i(1280, 720)
	print("TEST SANDBOX: ", OS.get_user_data_dir())

extends "res://tests/support/player_flow_test.gd"

func test_PLAY_END_01_menu_to_end_single_player() -> void:
	var result := probe("journey1")
	assert_true(result.get("end_visible", false))
	assert_eq(result.get("exam_scores", []).size(), 1)
	assert_eq(int(result.get("exam_scores", [-1])[0]), 1000)
	assert_true(result.get("loaded_midgame", false))

func test_PLAY_END_02_menu_to_end_multiple_players() -> void:
	for count in [2, 3, 4]:
		var result := probe("journey%d" % count)
		assert_true(result.get("end_visible", false))
		assert_eq(result.get("exam_scores", []).size(), count)
		assert_true(result.get("loaded_midgame", false))

func test_PLAY_END_03_score_from_play() -> void:
	await complete_game()
	var player: Dictionary = Global.player_data[0]
	var status := 0
	for key in ["study", "happiness", "stamina", "hunger"]:
		status += int(player["stats"][key])
	var missions := 0
	for score in player.get("mission_scores", {}).values(): missions += int(score)
	var exam: int = int(player["exam_result"]["correct"]) * 50
	var expected := status + missions + exam
	assert_between(expected, 0, 3000)
	assert_true(game.endgame_ui.final_score_label.text.contains(str(expected)))
	var rating := "ดีมาก" if expected >= 2100 else ("พอใช้" if expected >= 1200 else "ต้องปรับปรุง")
	assert_true(game.endgame_ui.rating_label.text.contains(rating))

func test_PLAY_END_04_leaderboard_after_reopen() -> void:
	var result := probe("journey4")
	assert_true(result.get("end_visible", false))
	LeaderboardManager._load_entries()
	var entries: Array = LeaderboardManager.get_entries()
	assert_between(entries.size(), 4, 10)
	for index in range(1, entries.size()):
		assert_gte(int(entries[index - 1]["score"]), int(entries[index]["score"]))

func test_PLAY_END_05_restart_clears_progress() -> void:
	for count in range(1, 5):
		var result := probe("restart" if count == 1 else "restart%d" % count)
		assert_eq(int(result.get("round", -1)), 1)
		assert_eq(int(result.get("minutes", -1)), 360)
		assert_eq(int(result["count"]), count)
		assert_eq(result["players"].size(), count)
		assert_eq(int(result["active_slot"]), -1)
		assert_false(result["has_pending_load"])
		assert_true(result["saved_files_unchanged"], "Restart preserves existing save files")
		assert_true(result["leaderboard_unchanged"], "Restart preserves recorded scores")
		for index in range(count):
			var player: Dictionary = result["players"][index]
			var previous: Dictionary = result["previous_players"][index]
			assert_eq(int(player["money"]), 1000)
			for sample in [["study", 0], ["happiness", 50], ["stamina", 70], ["hunger", 50]]:
				assert_eq(int(player["stats"][sample[0]]), sample[1], "Fresh player stats: " + sample[0])
			assert_false(player.get("exam_result", {}).get("completed", false), "Must not retain the previous exam")
			for field in ["subject_progress", "mission_scores", "event_missions", "event_history"]:
				assert_true(player.get(field, {}).is_empty(), "Must clear old progress: " + field)
			assert_eq(player["faculty_id"], previous["faculty_id"])
			assert_eq(player["avatar_settings"], previous["avatar_settings"])
			assert_eq(player["timetable"]["faculty_id"], player["faculty_id"])
			for classes in player["timetable"]["daily_subjects"].values():
				for entry in classes: assert_false(entry["is_completed"])

func test_PLAY_END_06_exit_to_menu() -> void:
	var result := probe("exit")
	assert_eq(result.get("scene"), "res://ui/MainMenu.tscn")
	assert_false(result.get("paused", true))

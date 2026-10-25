extends "res://tests/support/game_test.gd"

func write_slot(slot: int, contents: String) -> void:
	var file := FileAccess.open(SaveManager._slot_path(slot), FileAccess.WRITE)
	file.store_string(contents)

func test_S01_new_game_clears_previous_session() -> void:
	SaveManager.set_checkpoint({"old": true})
	SaveManager.pending_load = {"old": true}
	SaveManager.active_slot = 2
	Global.money = 9999
	SaveManager.start_new_game()
	assert_false(SaveManager.has_checkpoint())
	assert_false(SaveManager.has_pending_load())
	assert_eq(SaveManager.active_slot, -1)
	assert_eq(Global.money, 2000)
	assert_true(Global.player_data.is_empty())

func test_S02_global_json_roundtrip_preserves_faculty_progress_and_timetable() -> void:
	Global.player_data[0]["faculty_id"] = "law"
	Global.player_data[0]["subject_progress"]["กฎหมายเบื้องต้น"] = 4
	Global.ensure_random_timetables()
	Global.tutorial_seen = true
	var saved := canonical(Global.export_save_data())
	Global.reset_game_state()
	Global.import_save_data(JSON.parse_string(saved))
	assert_eq(canonical(Global.export_save_data()), saved)

func test_S03_checkpoints_are_independent_copies() -> void:
	var game = make_map()
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	Global.player_data[0]["money"] = 1
	assert_eq(SaveManager.checkpoint["global"]["player_data"][0]["money"], 1000)

func test_S04_disk_save_load_and_pending_load_is_consumed_once() -> void:
	var game = make_map()
	game.current_round = 4
	game.current_player_index = 1
	game.player_minutes[1] = 900
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	assert_true(SaveManager.save_checkpoint(1), SaveManager.last_error)
	assert_true(SaveManager.prepare_load(1), SaveManager.last_error)
	var loaded: Dictionary = SaveManager.take_pending_load()
	assert_eq(int(loaded["map"]["current_round"]), 4)
	assert_eq(int(loaded["map"]["player_minutes"][1]), 900)
	assert_eq(SaveManager.active_slot, 1)
	assert_true(SaveManager.take_pending_load().is_empty())
	var info: Dictionary = SaveManager.get_slot_info(1)
	assert_true(info["valid"])
	assert_eq(int(info["current_player"]), 2)

func test_S05_invalid_slots_and_missing_checkpoint_are_rejected() -> void:
	assert_false(SaveManager.save_checkpoint(0))
	assert_false(SaveManager.save_checkpoint(5))
	assert_false(SaveManager.save_checkpoint(1))
	assert_false(SaveManager.last_error.is_empty())
	assert_false(SaveManager.autosave_checkpoint(), "No active slot means no autosave")

func test_S06_corrupt_and_future_version_saves_are_rejected() -> void:
	write_slot(4, "invalid json")
	assert_false(SaveManager.prepare_load(4))
	assert_false(SaveManager.get_slot_info(4)["valid"])
	write_slot(4, JSON.stringify({"schema_version": 999, "game": {"example": true}}))
	assert_false(SaveManager.prepare_load(4))
	assert_false(SaveManager.has_pending_load())

func test_S07_autosave_writes_updated_checkpoint() -> void:
	var game = make_map()
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	assert_true(SaveManager.save_checkpoint(2))
	Global.player_data[0]["money"] = 1234
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	assert_true(SaveManager.autosave_checkpoint())
	assert_true(SaveManager.prepare_load(2))
	assert_eq(int(SaveManager.take_pending_load()["global"]["player_data"][0]["money"]), 1234)

func test_C01_final_score_maximum_is_three_thousand() -> void:
	var endgame = autofree(load("res://ui/endgame_ui.gd").new())
	var missions := {}
	for day in range(1, 11):
		missions[str(day)] = 100
	var scores: Dictionary = endgame._calculate_player_scores({"stats": {"study": 400, "stamina": 200, "hunger": 200, "happiness": 200}, "mission_scores": missions, "exam_result": {"score": 1000}})
	assert_eq(scores["total"], 3000)
	assert_eq(scores["rating"], "ดีมาก")

func test_C02_score_ratings_at_boundaries() -> void:
	var endgame = autofree(load("res://ui/endgame_ui.gd").new())
	for sample in [[1199, "ต้องปรับปรุง"], [1200, "พอใช้"], [2099, "พอใช้"], [2100, "ดีมาก"]]:
		var target: int = sample[0]
		var missions := {}
		for day in range(1, 11):
			missions[str(day)] = 100 if day <= 2 else 0
		var scores: Dictionary = endgame._calculate_player_scores({"stats": {"study": 400, "stamina": 200, "hunger": 200, "happiness": 199 if target % 2 == 1 else 200}, "mission_scores": missions, "exam_result": {"score": 0 if target < 2000 else 900}})
		assert_eq(scores["total"], target)
		assert_eq(scores["rating"], sample[1])

func test_C03_leaderboard_keeps_top_ten_and_persists() -> void:
	LeaderboardManager.entries.clear()
	var entries: Array[Dictionary] = []
	for index in range(15):
		entries.append({"name": "Test %d" % index, "score": index * 100})
	LeaderboardManager.record_scores(entries)
	var result: Array = LeaderboardManager.get_entries()
	assert_eq(result.size(), 10)
	assert_eq(result[0]["score"], 1400)
	assert_eq(result[9]["score"], 500)
	result[0]["score"] = -1
	assert_eq(LeaderboardManager.get_entries()[0]["score"], 1400, "Caller cannot mutate leaderboard")
	LeaderboardManager.entries.clear()
	LeaderboardManager._load_entries()
	assert_eq(LeaderboardManager.get_entries()[0]["score"], 1400)

func test_C04_music_volume_is_clamped_and_persisted() -> void:
	AudioManager.set_music_volume(2.0)
	assert_eq(AudioManager.get_music_volume(), 1.0)
	AudioManager.set_music_volume(-1.0)
	assert_eq(AudioManager.get_music_volume(), 0.0)
	AudioManager.set_music_volume(0.42)
	AudioManager.music_volume = 0.0
	AudioManager._load_settings()
	assert_almost_eq(AudioManager.get_music_volume(), 0.42, 0.001)

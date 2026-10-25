extends GutTest

const MAP_SCRIPT = preload("res://locations/new_map.gd")

func before_each() -> void:
	get_tree().paused = false
	SaveManager.start_new_game()
	Global.setup_players(2)
	Global.ensure_random_timetables()

func after_each() -> void:
	get_tree().paused = false
	for action in ["move_up", "move_down", "move_left", "move_right", "interact"]:
		Input.action_release(action)

func make_map():
	# Real production logic without adding the map to the tree: no UI startup,
	# live clock, random popups or scene transitions during isolated logic tests.
	var game = autofree(MAP_SCRIPT.new())
	game._setup_mock_data()
	game.player_minutes.assign([360, 360])
	game.player_time_speed_multipliers.assign([1.0, 1.0])
	game.late_wake_players.assign([false, false])
	return game

func make_quiz():
	var quiz = add_child_autofree(load("res://ui/learning_popup.tscn").instantiate())
	quiz.set_process(false)
	return quiz

func canonical(value) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

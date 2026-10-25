extends "res://tests/support/game_test.gd"

const MAP_SCENE = preload("res://locations/NewMap.tscn")

func open_game():
	Global.tutorial_seen = true
	var game = add_child_autofree(MAP_SCENE.instantiate())
	game.set_process(false)
	for player in game.player_nodes:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	return game

func activity_button(popup, action: String) -> TextureButton:
	for card in popup.btn_container.get_children():
		if card.get_meta("activity_name", "") == action:
			return card.get_child(0).get_child(0) as TextureButton
	return null

func answer_current_question(quiz, correctly: bool) -> void:
	for index in range(4):
		if (quiz.choice_buttons[index].text == quiz.current_correct_answer) == correctly:
			quiz.choice_buttons[index].pressed.emit()
			return

extends "res://tests/support/live_game_test.gd"

func test_U01_insufficient_money_rejected_through_actual_activity_button() -> void:
	var game = open_game()
	Global.player_data[0]["money"] = 39
	var before := canonical(Global.player_data[0])
	var popup = game.get_node("UILayer/ActivityPopup")
	game._handle_activity_popup(game.get_node("location/Shop"))
	var button := activity_button(popup, "ซื้อกาแฟ")
	assert_not_null(button)
	button.pressed.emit()
	await wait_seconds(0.25)
	assert_eq(canonical(Global.player_data[0]), before, "No money or stats charged")
	assert_eq(game.current_minutes, 360, "No time charged")

func test_U02_cancel_activity_keeps_money_stats_and_time() -> void:
	var game = open_game()
	var before := canonical(Global.player_data[0])
	game._handle_activity_popup(game.get_node("location/Food"))
	game.get_node("UILayer/ActivityPopup").close_btn.pressed.emit()
	assert_eq(canonical(Global.player_data[0]), before)
	assert_eq(game.current_minutes, 360)

func test_U03_library_borrow_button_applies_money_study_happiness_and_time() -> void:
	var game = open_game()
	var popup = game.get_node("UILayer/ActivityPopup")
	game._handle_activity_popup(game.get_node("location/Library"))
	activity_button(popup, "ยืมหนังสือ").pressed.emit()
	await wait_seconds(0.25)
	assert_eq(Global.player_data[0]["money"], 980)
	assert_eq(Global.player_data[0]["stats"]["study"], 3)
	assert_eq(Global.player_data[0]["stats"]["happiness"], 55)
	assert_eq(game.current_minutes, 370)

func test_U04_repeated_activity_button_presses_should_emit_one_choice() -> void:
	var game = open_game()
	var popup = game.get_node("UILayer/ActivityPopup")
	popup.open_popup("Shop", 0, game.activity_effects["Shop"])
	watch_signals(popup)
	var button := activity_button(popup, "ซื้อกาแฟ")
	button.pressed.emit()
	assert_true(button.disabled, "Disable activity buttons while confirming")
	assert_true(popup.close_btn.disabled, "Do not cancel a selection mid-animation")
	# Force duplicate signals too, so the handler itself must be idempotent.
	button.pressed.emit()
	popup.close_btn.pressed.emit()
	await wait_seconds(0.3)
	assert_signal_emit_count(popup, "activity_chosen", 1, "One user decision should resolve once even if pressed repeatedly")
	assert_signal_emitted_with_parameters(popup, "activity_chosen", ["ซื้อกาแฟ"])
	popup.open_popup("Shop", 0, game.activity_effects["Shop"])
	var reopened_button := activity_button(popup, "ซื้อกาแฟ")
	assert_false(reopened_button.disabled, "Reopening allows a new decision")
	assert_false(popup.close_btn.disabled)
	reopened_button.pressed.emit()
	await wait_seconds(0.25)
	assert_signal_emit_count(popup, "activity_chosen", 2, "One choice per opening")

func test_U05_tutorial_navigation_stops_clock_and_restores_movement() -> void:
	var game = open_game()
	Global.tutorial_seen = false
	game._show_initial_tutorial_if_needed()
	await wait_process_frames(2)
	var tutorial = game.tutorial_popup
	assert_true(tutorial.visible)
	assert_false(game.player_nodes[0].movement_enabled)
	game._process(3.0)
	assert_eq(game.current_minutes, 360)
	assert_true(tutorial.back_button.disabled)
	tutorial.next_button.pressed.emit()
	assert_eq(tutorial.current_page, 1)
	tutorial.back_button.pressed.emit()
	assert_eq(tutorial.current_page, 0)
	for page in range(tutorial.PAGES.size()):
		tutorial.next_button.pressed.emit()
	assert_false(tutorial.visible)
	assert_true(Global.tutorial_seen)
	assert_true(game.player_nodes[0].movement_enabled)

func test_U06_scenarios_excluded_for_location_cannot_recur() -> void:
	var popup = add_child_autofree(load("res://ui/scenario_popup.tscn").instantiate())
	var excluded := {}
	for scenario in popup.scenarios_db["Library"]:
		excluded[popup._get_scenario_key("Library", scenario)] = true
	assert_false(popup.try_start_scenario("Library", excluded))
	assert_false(popup.visible)
	assert_false(popup.try_start_scenario("unknown_place"))

func test_U07_all_scenario_choices_dispatch_correct_effects_once_under_repeated_presses() -> void:
	var scenarios: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios.json"))
	var checked := 0
	for place in scenarios:
		for scenario in scenarios[place]:
			for choice_index in range(scenario["choices"].size()):
				print("SCENARIO CHECK ", checked + 1, ": ", place, " choice ", choice_index)
				var popup = add_child_autofree(load("res://ui/scenario_popup.tscn").instantiate())
				popup.scenarios_db = {place: [scenario]}
				var resolved: Array = []
				popup.scenario_resolved.connect(func(effects): resolved.append(effects))
				assert_true(popup.try_start_scenario(place))
				await get_tree().process_frame
				await get_tree().process_frame
				var button: Button = popup.vbox.get_child(choice_index)
				button.pressed.emit()
				button.pressed.emit()
				await get_tree().create_timer(0.4).timeout
				assert_eq(resolved.size(), 1, "Scenario resolves once despite repeated press")
				if not resolved.is_empty():
					assert_eq(resolved[0], scenario["choices"][choice_index].get("effects", {}))
				assert_false(popup.visible)
				popup.queue_free()
				await get_tree().process_frame
				checked += 1
	assert_eq(checked, 43, "All current scenario choices exercised; update inventory if content changes")

func test_U08_cards_require_all_reveals_and_deliver_selected_events_once() -> void:
	var popup = add_child_autofree(load("res://ui/random_event_popup.tscn").instantiate())
	watch_signals(popup)
	popup.show_random_events(3)
	await wait_seconds(1.0)
	assert_eq(popup.selected_events.size(), 3)
	var ids: Array = []
	for event in popup.selected_events:
		assert_false(ids.has(event["id"]), "No duplicate card in same draw")
		ids.append(event["id"])
	popup.close_button.pressed.emit()
	assert_signal_not_emitted(popup, "events_resolved")
	for index in range(3):
		popup._flip_card(index)
		await wait_seconds(0.45)
	assert_false(popup.close_button.disabled)
	popup._show_detail(0)
	assert_true(popup.detail_panel.visible)
	popup.detail_confirm.pressed.emit()
	assert_false(popup.detail_panel.visible)
	popup.close_button.pressed.emit()
	assert_signal_emitted_with_parameters(popup, "events_resolved", [popup.selected_events])
	assert_signal_emit_count(popup, "events_resolved", 1)

func test_U09_overwrite_cancel_preserves_previous_save_file() -> void:
	var game = open_game()
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	assert_true(SaveManager.save_checkpoint(1))
	var old := FileAccess.get_file_as_string(SaveManager._slot_path(1))
	SaveManager.active_slot = -1
	var menu = game.save_slot_menu
	menu.open_menu(SaveSlotMenu.MenuMode.SAVE)
	menu.slot_buttons[0].pressed.emit()
	assert_true(menu.confirmation_layer.visible)
	menu._on_overwrite_canceled()
	assert_eq(FileAccess.get_file_as_string(SaveManager._slot_path(1)), old)
	assert_eq(menu.pending_overwrite_slot, -1)

func test_U10_overwrite_confirm_writes_new_checkpoint() -> void:
	var game = open_game()
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	assert_true(SaveManager.save_checkpoint(2))
	SaveManager.active_slot = -1
	Global.player_data[0]["money"] = 2468
	SaveManager.set_checkpoint(game._build_checkpoint_state())
	var menu = game.save_slot_menu
	menu.open_menu(SaveSlotMenu.MenuMode.SAVE)
	menu.slot_buttons[1].pressed.emit()
	assert_true(menu.confirmation_layer.visible)
	menu.confirmation_confirm_button.pressed.emit()
	await wait_seconds(0.5)
	assert_true(SaveManager.prepare_load(2))
	assert_eq(int(SaveManager.take_pending_load()["global"]["player_data"][0]["money"]), 2468)

func test_U11_nearest_place_switches_on_exit_and_handles_freed_area() -> void:
	var game = open_game()
	var player = game.player_nodes[0]
	# Isolate the proximity algorithm from the real dorm's physics overlap.
	# Shape overlap behavior itself remains a separate manual-test gap.
	player.interaction_area.monitoring = false
	await wait_physics_frames(2)
	var near: Area2D = add_child_autofree(Area2D.new())
	var far: Area2D = add_child_autofree(Area2D.new())
	near.global_position = player.global_position + Vector2(10, 0)
	far.global_position = player.global_position + Vector2(100, 0)
	player.nearby_areas.clear()
	player._on_area_entered(far)
	player._on_area_entered(near)
	assert_eq(player.nearby_place, near)
	player._on_area_exited(near)
	assert_eq(player.nearby_place, far)
	far.queue_free()
	await wait_process_frames(2)
	player._refresh_nearest_place()
	assert_null(player.nearby_place)

func test_U12_paused_interaction_and_key_repeat_do_not_trigger_activity() -> void:
	var game = open_game()
	var player = game.player_nodes[0]
	player.activity_requested.disconnect(game._on_player_activity_requested)
	player.nearby_place = game.get_node("location/Food")
	watch_signals(player)
	game._pause_game()
	var action := InputEventAction.new()
	action.action = "interact"
	action.pressed = true
	player._unhandled_input(action)
	game._resume_game()
	var repeated := InputEventKey.new()
	repeated.keycode = KEY_E
	repeated.pressed = true
	repeated.echo = true
	player._unhandled_input(repeated)
	assert_signal_not_emitted(player, "activity_requested")

func test_U13_all_blocking_popups_stop_live_clock() -> void:
	var game = open_game()
	for popup in [game.learning_popup, game.scenario_popup, game.random_event_popup, game.class_time_popup, game.save_slot_menu, game.tutorial_popup, game.get_node("UILayer/ActivityPopup")]:
		popup.show()
		game._process(3.0)
		assert_eq(game.current_minutes, 360, "Clock stopped while " + popup.name + " is open")
		popup.hide()

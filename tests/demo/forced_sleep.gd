extends SceneTree

var game
var state
var saves
var result_label: Label
var run_button: Button

func _initialize() -> void:
	call_deferred("open_demo")

func open_demo() -> void:
	var sandbox := OS.get_environment("KKU_TEST_SANDBOX").replace("\\", "/").to_lower()
	if sandbox.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox + "/"):
		push_error("Launch this reproduction using run-tests.cmd -Demo forced-sleep")
		quit(2)
		return
	state = root.get_node("Global")
	saves = root.get_node("SaveManager")
	saves.start_new_game()
	state.setup_players(1)
	state.tutorial_seen = true
	game = load("res://locations/NewMap.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player_nodes[0].set_physics_process(false)
	game.player_nodes[0].set_process_unhandled_input(false)
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(330, 220)
	panel.size = Vector2(620, 270)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff3d9")
	style.set_content_margin_all(24)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := Label.new()
	title.text = "ทดสอบ: พลังงานหลังถูกบังคับนอนเวลา 03:00"
	title.add_theme_color_override("font_color", Color("#5f2418"))
	title.add_theme_font_size_override("font_size", 25)
	content.add_child(title)
	result_label = Label.new()
	result_label.add_theme_color_override("font_color", Color("#38251c"))
	result_label.add_theme_font_size_override("font_size", 21)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result_label)
	run_button = Button.new()
	run_button.text = "ข้ามเวลาไป 03:00 และดูผล"
	run_button.pressed.connect(run_reproduction)
	content.add_child(run_button)
	var close := Button.new()
	close.text = "ปิดการทดสอบ"
	close.pressed.connect(func(): quit())
	content.add_child(close)
	prepare_state()
	if OS.get_cmdline_user_args().has("--auto"):
		await run_reproduction()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("KKU_TEST_RESULTS").path_join("forced-sleep.png"))
		quit()

func prepare_state() -> void:
	game.current_round = 1
	game.current_player_index = 0
	game.current_minutes = 1619
	game.player_minutes[0] = 1619
	game.random_event_turns["2:0"] = true
	state.player_data[0]["stats"]["stamina"] = 150
	state.player_data[0]["stats"]["hunger"] = 100
	game.player_panel.setup_players_ui()
	game.player_panel.update_time_ui(1619, 360, 1620)
	result_label.text = "ก่อนนอน: พลังงาน 150 / 200 เวลา 02:59\nเมื่อฟื้นพลังงาน +30 คาดหวัง 180 / 200\nกดปุ่มด้านล่างเพื่อเรียกระบบนอนจริงของเกม"

func run_reproduction() -> void:
	run_button.disabled = true
	prepare_state()
	game._advance_time(1)
	var actual: int = state.player_data[0]["stats"]["stamina"]
	await create_timer(0.6).timeout
	result_label.text = "ก่อนนอน: 150 / 200\nคาดหวังหลังฟื้น +30: 180 / 200\nผลจริงหลังถูกบังคับนอน: %d / 200\n%s" % [actual, "ผ่าน: พลังงานฟื้นตามที่คาดหวัง" if actual == 180 else "ไม่ผ่าน: พลังงานต่างจากค่าที่คาดหวัง"]
	print("REPRO forced-sleep: before=150 expected=180 actual=", actual)
	run_button.text = "ทดลองซ้ำ"
	run_button.disabled = false

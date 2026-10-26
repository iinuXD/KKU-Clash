extends "res://tests/support/player_flow_test.gd"

func check_action(place: String, action: String, delta: Dictionary, minutes: int) -> void:
	var before: Dictionary = Global.player_data[0].duplicate(true)
	var start: int = game.current_minutes
	await choose_action(place, action)
	assert_eq(Global.player_data[0]["money"], int(before["money"]) + int(delta.get("money", 0)), action + " money")
	for key in ["study", "stamina", "hunger", "happiness"]:
		var maximum := 400 if key == "study" else 200
		assert_eq(int(Global.player_data[0]["stats"][key]), clampi(int(before["stats"][key]) + int(delta.get(key, 0)), 0, maximum), action + " " + key)
	assert_eq(game.current_minutes, start + minutes)

func test_PLAY_ACT_01_dorm() -> void:
	open_game()
	await check_action("Dorm", "นอนพัก", {"stamina":40}, 120)
	await check_action("Dorm", "อ่านหนังสือ", {"study":5,"stamina":-10,"happiness":-5}, 120)

func test_PLAY_ACT_02_library() -> void:
	open_game()
	await check_action("Library", "อ่านหนังสือ", {"study":8,"stamina":-10,"hunger":-5}, 120)
	await check_action("Library", "ยืมหนังสือ", {"money":-20,"study":3,"happiness":5}, 10)
	await check_action("Library", "นั่งเล่น", {"happiness":15,"stamina":5}, 60)

func test_PLAY_ACT_03_food() -> void:
	open_game()
	await check_action("Food", "กินข้าวจานธรรมดา", {"money":-40,"hunger":30}, 30)
	await check_action("Food", "กินข้าวจานพิเศษ", {"money":-60,"hunger":45,"happiness":10}, 30)
	await check_action("Food", "กินของทานเล่น", {"money":-25,"hunger":15,"happiness":15}, 30)
	await check_action("Food", "ทำ Parttime", {"money":500,"stamina":-20,"hunger":-15}, 240)

func test_PLAY_ACT_04_shop() -> void:
	open_game()
	await check_action("Shop", "ซื้อกาแฟ", {"money":-40,"stamina":15,"hunger":5}, 10)
	await check_action("Shop", "ซื้อขนม", {"money":-30,"hunger":10,"happiness":10}, 10)
	await check_action("Shop", "ซื้อยา", {"money":-100,"stamina":30}, 10)
	await check_action("Shop", "ทำ Parttime", {"money":500,"stamina":-20,"happiness":-5}, 240)

func test_PLAY_ACT_05_hospital() -> void:
	open_game()
	await check_action("Hospital", "เข้ารับการรักษา", {"money":-500,"stamina":100,"happiness":20}, 60)
	await check_action("Hospital", "ซื้อยา", {"money":-150,"stamina":30}, 10)
	await check_action("Hospital", "ตรวจสุขภาพ", {"money":-250,"stamina":20,"happiness":10}, 60)

func test_PLAY_ACT_06_sport_and_fun() -> void:
	open_game()
	await check_action("Sport", "วิ่ง", {"happiness":15,"stamina":-15,"hunger":-10}, 120)
	await check_action("Sport", "เล่นกีฬา", {"happiness":25,"stamina":-25,"hunger":-15}, 180)
	await check_action("Sport", "ออกกำลังกาย", {"happiness":10,"stamina":-10,"hunger":-5}, 120)
	# This plan explicitly uses separate play sessions for each venue.
	game.queue_free()
	await frames()
	SaveManager.start_new_game()
	Global.setup_players(1)
	Global.tutorial_seen = true
	open_game()
	await check_action("Fun", "ร้องคาราโอเกะ", {"money":-150,"happiness":40,"stamina":-10}, 180)
	await check_action("Fun", "ปาร์ตี้", {"money":-300,"happiness":60,"stamina":-25,"study":-5}, 240)
	await check_action("Fun", "ทำ Parttime", {"money":500,"stamina":-30,"hunger":-20}, 240)

func spend_to_twenty() -> void:
	for index in range(49):
		await choose_action("Library", "ยืมหนังสือ")
	assert_eq(Global.player_data[0]["money"], 20, "Reached by 49 actual 20-baht purchases")

func test_PLAY_ACT_07_insufficient_funds_from_play() -> void:
	open_game()
	await spend_to_twenty()
	var before := snapshot()
	var start: int = game.current_minutes
	await choose_action("Shop", "ซื้อกาแฟ")
	assert_eq(snapshot(), before)
	assert_eq(game.current_minutes, start)

func test_PLAY_ACT_08_exact_price_from_play() -> void:
	open_game()
	await spend_to_twenty()
	await choose_action("Library", "ยืมหนังสือ")
	assert_eq(Global.player_data[0]["money"], 0)
	assert_eq(Global.player_data[0]["stats"]["study"], 150)

func test_PLAY_ACT_09_cancel() -> void:
	open_game()
	for place in ["Dorm", "Library", "Food", "Shop", "Hospital", "Sport", "Fun"]:
		var before := snapshot()
		var start: int = game.current_minutes
		await visit(place)
		press(game.get_node("UILayer/ActivityPopup").close_btn)
		await frames()
		assert_eq(snapshot(), before)
		assert_eq(game.current_minutes, start)

func test_PLAY_ACT_10_repeated_choices() -> void:
	open_game()
	await visit("Shop")
	var coffee := action_button("ซื้อกาแฟ")
	var snack := action_button("ซื้อขนม")
	press(coffee)
	press(coffee)
	press(snack)
	press(game.get_node("UILayer/ActivityPopup").close_btn)
	await until(func(): return not game.is_walking, "one activity")
	assert_eq(Global.player_data[0]["money"], 960)
	await choose_action("Shop", "ซื้อกาแฟ")
	assert_eq(Global.player_data[0]["money"], 920)

func test_PLAY_ACT_11_faint_and_stat_caps_from_play() -> void:
	open_game()
	for repeat in range(5):
		await choose_action("Sport", "วิ่ง")
	assert_eq(game.current_round, 2, "Fainted from running rather than setting stats")
	assert_eq(Global.player_data[0]["stats"]["stamina"], 50)
	assert_eq(Global.player_data[0]["stats"]["hunger"], 20)
	assert_eq(game.player_nodes[0].global_position, game.dorm_marker.global_position)
	for repeat in range(5): await choose_action("Dorm", "นอนพัก")
	for repeat in range(6): await choose_action("Food", "กินข้าวจานธรรมดา")
	assert_eq(Global.player_data[0]["stats"]["stamina"], 200)
	assert_eq(Global.player_data[0]["stats"]["hunger"], 200)

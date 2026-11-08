extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const SaveManager = preload("res://scripts/save_manager.gd")
const TrafficSpawner = preload("res://scripts/traffic_spawner.gd")
var failures: int = 0
var endings: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("traffic-dodge-smoke-"):
		_check(false, "use an isolated traffic-dodge-smoke-* data directory")
		_finish()
		return
	if "--check-save" in OS.get_cmdline_user_args():
		var saved := SaveManager.new()
		root.add_child(saved)
		saved.load_data()
		_check(int(saved.data.best_score) > 0, "best score persists across processes")
		_check(int(saved.data.selected) == 1 and bool(saved.data.unlocked[1]), "garage unlock and selection persist")
		_check(is_equal_approx(float(saved.data.music), 0.25) and not bool(saved.data.shadows), "settings persist")
		_finish()
		return

	var app := MainScene.instantiate()
	root.add_child(app)
	_check(app.state == app.State.MENU, "main scene starts at the menu")
	_check(InputMap.event_is_action(_key(KEY_LEFT), &"move_left"), "Left Arrow is mapped")
	_check(InputMap.event_is_action(_key(KEY_RIGHT), &"move_right"), "Right Arrow is mapped")
	_check(InputMap.event_is_action(_key(KEY_A), &"move_left"), "A is mapped")
	_check(InputMap.event_is_action(_key(KEY_D), &"move_right"), "D is mapped")
	_check_waves()
	app.game.random_seed = 873
	app.game.run_ended.connect(func(_distance: float, _score: int, _coins: int) -> void: endings += 1)
	_press(app, "Play")
	_check(app.state == app.State.PLAYING and app.game._player.lane == 1, "Play starts in the middle lane")
	for index in 5:
		_send_key(KEY_LEFT)
	await _frames(28)
	_check(app.game._player.lane == 0 and is_equal_approx(app.game._player.position.x, -app.game.lane_width), "left lane clamps")
	_send_key(KEY_D, true)
	_check(app.game._player.lane == 0, "held key does not repeat")
	for index in 5:
		_send_key(KEY_D)
	await _frames(50)
	_check(app.game._player.lane == 2 and is_equal_approx(app.game._player.position.x, app.game.lane_width), "right lane clamps")
	_press(app, "Pause")
	var frozen := float(app.game.progress.distance)
	await _frames(30)
	_check(is_equal_approx(float(app.game.progress.distance), frozen), "pause freezes travel")
	_press(app, "Settings")
	_check(app.state == app.State.SETTINGS, "settings opens from pause")
	var sliders: Array[Node] = app.screen.find_children("*", "HSlider", true, false)
	sliders[1].value = 0.25
	var shadow_toggle: CheckButton = app.screen.find_children("*", "CheckButton", true, false)[0]
	shadow_toggle.set_pressed_no_signal(false)
	shadow_toggle.toggled.emit(false)
	_press(app, "Back")
	_press(app, "Resume")
	await _frames(3)
	_check(app.state == app.State.PLAYING and float(app.game.progress.distance) > frozen, "resume continues travel")
	_check(not app.game.find_children("*", "DirectionalLight3D", true, false)[0].shadow_enabled, "shadow option applies in game")

	if app.game._traffic.is_empty():
		_check(false, "first wave spawned")
		_finish()
		return
	var target: Area3D = app.game._traffic[0]
	var lane := 1 + roundi(target.position.x / app.game.lane_width)
	_move_to_lane(app.game, lane)
	for index in 420:
		if app.state == app.State.GAME_OVER:
			break
		await physics_frame
	_check(app.state == app.State.GAME_OVER, "real Area3D contact triggers game over")
	_check(endings == 1 and int(app.profile.data.best_score) > 0, "one crash signal and saved best score")
	await _frames(25)
	_check(endings == 1, "crash remains latched")
	_press(app, "Restart")
	_check(app.game._player.lane == 1 and float(app.game.progress.distance) < 1.0, "restart clears run state")
	var peak_traffic: int = 0
	var peak_coins: int = 0
	for index in 10000:
		await physics_frame
		if app.state != app.State.PLAYING:
			_check(false, "following the seeded route survives all waves")
			break
		for token: Area3D in app.game._coins:
			if token.position.z < -15.0 and token.position.z > -20.0:
				_move_to_lane(app.game, 1 + roundi(token.position.x / app.game.lane_width))
				break
		peak_traffic = maxi(peak_traffic, app.game._traffic.size())
		peak_coins = maxi(peak_coins, app.game._coins.size())
	_check(peak_traffic <= 12 and peak_coins <= 16 and app.game._road.segments.size() == 4, "world object counts remain bounded")
	_check(app.game.progress.distance > 3500.0 and app.game.progress.coins >= 30 and app.game.progress.score > int(app.game.progress.distance), "distance, coins and overtake score advance")
	_press(app, "Pause")
	_press(app, "Main Menu")
	_press(app, "Garage")
	_press(app, "02")
	_press(app, "Unlock  /  30 coins")
	_check(app.profile.data.selected == 1 and app.profile.data.unlocked[1], "garage purchase unlocks and selects the vehicle")
	_press(app, "Back")
	_finish()


func _check_waves() -> void:
	var spawner := TrafficSpawner.new()
	for seed_value in range(100):
		spawner.reset(seed_value, 100.0)
		var prior_lane: int = 1
		var prior_arrival: float = 0.0
		for index in range(100):
			var wave := spawner.next_wave(1.0)
			if wave.safe_lane in wave.lanes or absi(wave.safe_lane - prior_lane) > 1 or wave.arrival - prior_arrival < 42.99:
				_check(false, "fair wave spacing and reachable open lane")
				return
			prior_lane = wave.safe_lane
			prior_arrival = wave.arrival
	print("Checked 10,000 seeded waves.")


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _move_to_lane(game: Node, lane: int) -> void:
	for index in absi(int(game._player.lane) - lane):
		_send_key(KEY_A if lane < int(game._player.lane) else KEY_D)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _send_key(code: Key, echo: bool = false) -> void:
	var event := _key(code)
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press(app: Node, title: String) -> void:
	for button: Button in app.screen.find_children("*", "Button", true, false):
		if button.text == title and not button.disabled:
			button.pressed.emit()
			return
	_check(false, "available button: " + title)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	print("Traffic Dodge smoke failures: ", failures)
	quit(0 if failures == 0 else 1)


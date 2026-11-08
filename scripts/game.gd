extends Node3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const RoadGenerator = preload("res://scripts/road_generator.gd")
const TrafficSpawner = preload("res://scripts/traffic_spawner.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const TrafficCar = preload("res://scripts/traffic_car.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const ScoreManager = preload("res://scripts/score_manager.gd")
const TRAFFIC_PAINTS: Array[Color] = [Color("#e76e57"), Color("#e6d4a2"), Color("#668abb"), Color("#abbd9a")]
const START_SPEED: float = 18.0
const TOP_SPEED: float = 32.0

signal stats_changed(distance: float, score: int, coins: int, speed: float)
signal run_ended(distance: float, score: int, coins: int)

@export_range(2.8, 3.6) var lane_width: float = 3.2
@export_range(8.0, 14.0) var lane_change_speed: float = 9.0
@export var random_seed: int = -1
@export_range(80.0, 160.0) var spawn_distance: float = 100.0

var playing: bool = false
var speed: float = START_SPEED
var progress := ScoreManager.new()
var _spawner := TrafficSpawner.new()
var _rng := RandomNumberGenerator.new()
var _player: PlayerCar
var _camera := CameraController.new()
var _road := RoadGenerator.new()
var _traffic: Array[TrafficCar] = []
var _coins: Array[Area3D] = []
var _world: Node3D


func _ready() -> void:
	_build_world()
	if get_parent() is Window:
		start_run(0)


func show_backdrop(car_index: int) -> void:
	playing = false
	_reset_world(car_index)


func start_run(car_index: int) -> void:
	_spawner.reset(random_seed, spawn_distance)
	_rng.seed = _spawner.rng.seed
	_reset_world(car_index)
	progress.reset()
	speed = START_SPEED
	playing = true
	_emit_stats()


func resume_run() -> void:
	playing = true
	var overlapping := _player.get_overlapping_areas()
	for area in overlapping:
		if area is TrafficCar and area in _traffic:
			_on_player_area_entered(area, _player)
			return
	for area in overlapping:
		if area in _coins:
			_on_player_area_entered(area, _player)


func _unhandled_input(event: InputEvent) -> void:
	if playing:
		_player.handle_input(event)


func _physics_process(delta: float) -> void:
	if not playing:
		return
	var travel := speed * delta
	progress.distance += travel
	speed = minf(TOP_SPEED, START_SPEED + progress.distance * 0.003)
	var difficulty := clampf(progress.distance / 2100.0, 0.0, 1.0)
	_player.advance(delta, travel, lane_width, lane_change_speed)
	_camera.follow(delta, _player.position.x, difficulty)
	_road.advance(travel)
	for index in range(_traffic.size() - 1, -1, -1):
		var vehicle := _traffic[index]
		progress.bonus += vehicle.advance(travel, _player.position.x)
		if vehicle.position.z > 24.0:
			_traffic.remove_at(index)
			vehicle.queue_free()
	for index in range(_coins.size() - 1, -1, -1):
		var coin := _coins[index]
		coin.position.z += travel
		coin.rotate_y(delta * 3.0)
		if coin.position.z > 24.0:
			_coins.remove_at(index)
			coin.queue_free()
	while _spawner.next_arrival <= progress.distance + spawn_distance:
		_spawn_wave(difficulty)
	_emit_stats()


func _emit_stats() -> void:
	stats_changed.emit(progress.distance, progress.score, progress.coins, speed)


func _reset_world(car_index: int) -> void:
	for vehicle in _traffic:
		vehicle.hide()
		vehicle.queue_free()
	for coin in _coins:
		coin.hide()
		coin.queue_free()
	_traffic.clear()
	_coins.clear()
	if is_instance_valid(_player):
		_player.hide()
		_player.queue_free()
	_player = PlayerCar.new()
	_player.build(car_index)
	_world.add_child(_player)
	_player.area_entered.connect(_on_player_area_entered.bind(_player))
	_road.reset()
	_camera.reset()


func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4699d0")
	sky_material.sky_horizon_color = Color("#d7f1f1")
	sky_material.ground_bottom_color = Color("#81a991")
	sky_material.ground_horizon_color = Color("#d7f1f1")
	sky.sky_material = sky_material
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color("#c2dedc")
	env.fog_density = 0.0038
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9e1ee")
	env.ambient_light_energy = 0.42
	environment.environment = env
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_color = Color("#ffefdb")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 86.0
	_world.add_child(sun)
	_world.add_child(_camera)
	_world.add_child(_road)
	_road.build(lane_width)


func _spawn_wave(difficulty: float) -> void:
	var wave := _spawner.next_wave(difficulty)
	var lead := float(wave.arrival) - progress.distance
	var factor := float(wave.relative_speed)
	for lane: int in wave.lanes:
		_spawn_vehicle(lane, lead * factor, factor)
	for offset in [-3.5, 0.0, 3.5]:
		_spawn_coin(int(wave.safe_lane), lead + offset)


func _spawn_vehicle(lane: int, lead: float, factor: float) -> void:
	var kind := _rng.randi_range(0, 2)
	var color := TRAFFIC_PAINTS[_rng.randi_range(0, TRAFFIC_PAINTS.size() - 1)]
	var vehicle := TrafficCar.new()
	vehicle.position = Vector3(float(lane - 1) * lane_width, 0, -lead)
	vehicle.build(kind, color, factor)
	_world.add_child(vehicle)
	_traffic.append(vehicle)


func _spawn_coin(lane: int, lead: float) -> void:
	var coin := Area3D.new()
	coin.name = "Coin"
	coin.collision_layer = 4
	coin.collision_mask = 0
	coin.monitoring = false
	coin.position = Vector3(float(lane - 1) * lane_width, 1.1, -lead)
	_world.add_child(coin)
	var shape := SphereShape3D.new()
	shape.radius = 0.85
	var collision := CollisionShape3D.new()
	collision.shape = shape
	coin.add_child(collision)
	_coin_face(coin, 0.50, 0.17, Color("#e7a333"))
	_coin_face(coin, 0.38, 0.19, Color("#ffdb63"))
	_coins.append(coin)


func _coin_face(coin: Area3D, radius: float, depth: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 12
	var visual := VehicleVisual.attach(coin, mesh, Vector3.ZERO, color)
	visual.rotation_degrees.x = 90.0


func _on_player_area_entered(area: Area3D, player: PlayerCar) -> void:
	if not playing or player != _player:
		return
	if area in _coins:
		_coins.erase(area)
		area.queue_free()
		progress.collect_coin()
		_emit_stats()
	elif area is TrafficCar and area in _traffic:
		playing = false
		run_ended.emit(progress.distance, progress.score, progress.coins)


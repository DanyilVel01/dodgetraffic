extends Area3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const WIDTH: float = 1.65
const LENGTH: float = 3.3

var lane: int = 1
var visual: Node3D
var wheels: Array[Node3D] = []


func build(car_index: int) -> void:
	name = "Player"
	collision_layer = 1
	collision_mask = 2 | 4
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 1.2, LENGTH)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	hitbox.position.y = 0.8
	add_child(hitbox)
	visual = VehicleVisual.create(self, 0, VehicleVisual.PLAYER_PAINTS[car_index], car_index)
	wheels = VehicleVisual.find_wheels(visual)


func handle_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"move_left"):
		lane = maxi(0, lane - 1)
	elif event.is_action_pressed(&"move_right"):
		lane = mini(2, lane + 1)


func advance(delta: float, travel: float, lane_width: float, lane_speed: float) -> void:
	var target := float(lane - 1) * lane_width
	position.x = move_toward(position.x, target, lane_speed * delta)
	var tilt := clampf((position.x - target) * 0.09, -0.18, 0.18)
	visual.rotation.z = lerpf(visual.rotation.z, tilt, 1.0 - exp(-delta * 7.0))
	for wheel in wheels:
		wheel.rotate_x(travel / 0.36)


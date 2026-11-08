extends Area3D

const VehicleVisual = preload("res://scripts/vehicle_visual.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const LENGTHS: Array[float] = [3.7, 5.0, 6.2]
const HEIGHTS: Array[float] = [1.2, 2.0, 2.6]
const WIDTH: float = 1.8

var relative_speed: float
var length: float
var passed: bool
var near_miss: bool
var wheels: Array[Node3D] = []


func build(kind: int, color: Color, factor: float) -> void:
	name = "Traffic"
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	relative_speed = factor
	length = LENGTHS[kind]
	var height := HEIGHTS[kind]
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, height, length)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	hitbox.position.y = height * 0.5 + 0.25
	add_child(hitbox)
	var visual := VehicleVisual.create(self, kind, color)
	wheels = VehicleVisual.find_wheels(visual)


func advance(travel: float, player_x: float) -> int:
	position.z += travel * relative_speed
	for wheel in wheels:
		wheel.rotate_x(travel * (1.0 - relative_speed) / 0.36)
	if passed:
		return 0
	if absf(position.z) < (length + PlayerCar.LENGTH) * 0.5:
		var clearance := absf(position.x - player_x) - (WIDTH + PlayerCar.WIDTH) * 0.5
		near_miss = near_miss or (clearance >= 0.0 and clearance < 1.2)
	if position.z > 5.5:
		passed = true
		return 35 if near_miss else 25
	return 0


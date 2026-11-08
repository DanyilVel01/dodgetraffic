extends Camera3D


func _ready() -> void:
	position = Vector3(0, 5.0, 10.2)
	rotation_degrees.x = -15.5
	current = true
	reset()


func reset() -> void:
	position.x = 0.0
	fov = 58.0


func follow(delta: float, player_x: float, difficulty: float) -> void:
	position.x = lerpf(position.x, player_x * 0.35, 1.0 - exp(-delta * 3.0))
	fov = lerpf(fov, 58.0 + 6.0 * difficulty, 1.0 - exp(-delta * 2.5))


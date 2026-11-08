extends Node3D

const Shapes = preload("res://scripts/vehicle_visual.gd")
const SEGMENT_LENGTH: float = 60.0
const SEGMENT_COUNT: int = 4
const STONE: Color = Color("#617a71")
const METAL: Color = Color("#879e9e")
const LINE: Color = Color("#f5f1d7")
const CANOPY: Array[Color] = [Color("#397756"), Color("#4a8a58"), Color("#5b965f")]

var segments: Array[Node3D] = []


func build(lane_width: float) -> void:
	for index in SEGMENT_COUNT:
		var segment := Node3D.new()
		segment.name = "RoadSegment%d" % index
		add_child(segment)
		segments.append(segment)
		_build_segment(segment, index, lane_width)
	reset()


func reset() -> void:
	for index in segments.size():
		segments[index].position.z = SEGMENT_LENGTH * float(index - 2)


func advance(travel: float) -> void:
	for segment in segments:
		segment.position.z += travel
		if segment.position.z > SEGMENT_LENGTH:
			segment.position.z -= SEGMENT_LENGTH * SEGMENT_COUNT


func _build_segment(segment: Node3D, variant: int, lane_width: float) -> void:
	var shoulder := lane_width * 1.5
	Shapes.box(segment, Vector3(100, 0.2, SEGMENT_LENGTH), Vector3(0, -0.18, 0), Color("#749c64"))
	Shapes.box(segment, Vector3((shoulder + 0.62) * 2.0, 0.14, SEGMENT_LENGTH), Vector3(0, -0.04, 0), Color("#303b46"))
	for edge in [-shoulder, shoulder]:
		Shapes.box(segment, Vector3(0.13, 0.022, SEGMENT_LENGTH), Vector3(edge, 0.043, 0), LINE)
	for x in [-lane_width / 2.0, lane_width / 2.0]:
		for index in range(6):
			Shapes.box(segment, Vector3(0.12, 0.022, 4.3), Vector3(x, 0.043, -25.0 + index * 10.0), LINE)
	for side in [-1.0, 1.0]:
		var rail_x: float = side * (shoulder + 0.94)
		Shapes.box(segment, Vector3(0.15, 0.20, SEGMENT_LENGTH), Vector3(rail_x, 0.64, 0), METAL)
		for index in range(6):
			Shapes.box(segment, Vector3(0.13, 0.7, 0.13), Vector3(rail_x, 0.35, -25.0 + index * 10.0), STONE)
		for index in range(4):
			var z := -24.0 + 14.0 * index + float(variant % 2) * 4.0
			var x: float = side * (shoulder + 3.1 + float((index + variant) % 3) * 1.6)
			_tree(segment, Vector3(x, 0, z), (index + variant) % CANOPY.size())
			_foliage(segment, Vector3(x + side * 2.4, 0.5, z - 6.0), Vector3(1.4, 0.65, 1.05), CANOPY[(index + 1) % CANOPY.size()])
		_foliage(segment, Vector3(side * (shoulder + 18.0), -2.1, -8.0), Vector3(16.0, 8.0 + variant, 22.0), Color("#64916b"))
		var pole_x: float = side * (shoulder + 1.52)
		var pole_z: float = 13.0 if side > 0.0 else -12.0
		Shapes.box(segment, Vector3(0.14, 5.6, 0.14), Vector3(pole_x, 2.8, pole_z), METAL)
		Shapes.box(segment, Vector3(1.18, 0.17, 0.28), Vector3(pole_x - side * 0.52, 5.51, pole_z), METAL)
		Shapes.box(segment, Vector3(0.52, 0.06, 0.21), Vector3(pole_x - side * 0.82, 5.39, pole_z), LINE)
	if variant % 2 == 0:
		_sign(segment, shoulder + 1.7, -22.0, "COASTAL ROUTE" if variant == 0 else "SCENIC HIGHWAY")


func _tree(parent: Node3D, position: Vector3, variant: int) -> void:
	Shapes.box(parent, Vector3(0.36, 2.5, 0.36), position + Vector3(0, 1.15, 0), Color("#664f41"))
	_foliage(parent, position + Vector3(0, 2.9, 0), Vector3(1.43, 1.77, 1.31), CANOPY[variant])
	_foliage(parent, position + Vector3(0.7, 2.62, 0.2), Vector3(0.85, 1.03, 0.85), CANOPY[variant].lightened(0.06))


func _foliage(parent: Node3D, position: Vector3, scale_factor: Vector3, color: Color) -> void:
	var shape := SphereMesh.new()
	shape.radial_segments = 7
	shape.rings = 3
	shape.radius = 1.0
	shape.height = 2.0
	var part := Shapes.attach(parent, shape, position, color)
	part.scale = scale_factor


func _sign(parent: Node3D, x: float, z: float, title: String) -> void:
	for post_x in [x - 0.75, x + 0.75]:
		Shapes.box(parent, Vector3(0.12, 2.85, 0.12), Vector3(post_x, 1.42, z), METAL)
	Shapes.box(parent, Vector3(2.60, 0.78, 0.12), Vector3(x, 2.83, z), Color("#d6ecdc"))
	Shapes.box(parent, Vector3(2.49, 0.67, 0.13), Vector3(x, 2.83, z + 0.008), Color("#195663"))
	var label := Label3D.new()
	label.text = title
	label.font_size = 44
	label.outline_size = 0
	label.pixel_size = 0.0035
	label.position = Vector3(x, 2.83, z + 0.085)
	parent.add_child(label)


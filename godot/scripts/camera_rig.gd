## Камера от третьего лица: вращение пальцем, приближение щипком.
## SpringArm3D сам подтягивает камеру ближе, если сзади стена, дом или склон.
extends Node3D

var target: Node3D
var yaw := 0.0
var pitch := 0.35
var dist := 8.0
var camera: Camera3D

var _arm: SpringArm3D
var _snapped := false

func _ready() -> void:
	top_level = true
	_arm = SpringArm3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	_arm.shape = sh
	_arm.margin = 0.3
	_arm.collision_mask = 1
	_arm.spring_length = dist
	add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 1500.0
	_arm.add_child(camera)
	camera.current = true

func _process(dt: float) -> void:
	if not target:
		return
	var tp := target.global_position + Vector3(0, 1.7, 0)
	if not _snapped:
		global_position = tp
		_snapped = true
	else:
		global_position = global_position.lerp(tp, 1.0 - exp(-dt * 14.0))
	rotation = Vector3(-pitch, yaw, 0)
	_arm.spring_length = dist

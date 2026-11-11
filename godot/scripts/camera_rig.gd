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
var _shake := 0.0           # сила тряски (м), гаснет со временем
var _shake_t := 0.0
var _len := 8.0             # текущая длина руки (м): укорачивается быстро, возвращается плавно
var canopy: Callable        # (точка) → внутри кроны дерева? Задаёт мир; у крон нет столкновений
const LEN_MIN := 1.2
const LEN_IN := 18.0        # скорость приближения к препятствию (1/с)
const LEN_OUT := 3.0        # скорость возврата на свою дальность (1/с)

## Тряска камеры (удар, падение босса)
func shake(amount: float, time := 0.25) -> void:
	_shake = maxf(_shake, amount)
	_shake_t = maxf(_shake_t, time)

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
	add_child(camera)   # не внутри SpringArm: длину руки ведём сами — плавно и с учётом крон деревьев
	camera.position = Vector3(0, 0, dist)
	camera.current = true

## Сразу перенести камеру к герою (после перехода в подземелье и обратно)
func snap() -> void:
	_snapped = false

func _process(dt: float) -> void:
	if not target:
		return
	var tp := target.global_position + Vector3(0, 1.7, 0)
	var snap_now := not _snapped
	if snap_now:
		global_position = tp
		_snapped = true
	else:
		global_position = global_position.lerp(tp, 1.0 - exp(-dt * 14.0))
	rotation = Vector3(-pitch, yaw, 0)
	_arm.spring_length = dist
	# Длина руки: до стены/склона (SpringArm), а в кроне дерева — ближе, пока камера не выйдет из неё
	var wall := minf(dist, _arm.get_hit_length())
	var want := wall
	if canopy.is_valid():
		var back := global_transform.basis.z
		while want > LEN_MIN and canopy.call(global_position + back * want):
			want -= 0.5
		want = maxf(want, LEN_MIN)
	if snap_now:
		_len = want
	else:
		_len = lerpf(_len, want, 1.0 - exp(-dt * (LEN_IN if want < _len else LEN_OUT)))
		_len = minf(_len, wall)   # за стену камера не заходит ни на кадр
	camera.position = Vector3(0, 0, _len)
	if _shake_t > 0.0:
		# Тряска по настоящему времени: замедление времени её не растягивает
		var rdt := dt / maxf(Engine.time_scale, 0.01)
		_shake_t -= rdt
		var a := _shake * clampf(_shake_t / 0.25, 0.0, 1.0)
		camera.h_offset = randf_range(-a, a)
		camera.v_offset = randf_range(-a, a)
	elif camera.h_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

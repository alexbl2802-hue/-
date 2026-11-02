## Управление временем: стоп-кадр при попадании (мгновенная пауза — удар ощущается тяжёлым)
## и короткое замедление на последнем ударе серии. Работает через Engine.time_scale,
## а возвращает время по настоящим часам, чтобы замедление не замедляло само себя.
class_name TimeFx
extends RefCounted

const STOP_SCALE := 0.04
const SLOW_SCALE := 0.35
static var _stop_end := 0
static var _slow_end := 0
static var enabled := true

static func hitstop(sec: float) -> void:
	_stop_end = maxi(_stop_end, Time.get_ticks_msec() + int(sec * 1000.0))
	_schedule(sec)

static func slowmo(sec: float) -> void:
	_slow_end = maxi(_slow_end, Time.get_ticks_msec() + int(sec * 1000.0))
	_schedule(sec)

static func reset() -> void:
	_stop_end = 0
	_slow_end = 0
	Engine.time_scale = 1.0

static func _schedule(sec: float) -> void:
	_apply()
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(sec + 0.005, true, false, true).timeout.connect(_apply)

static func _apply() -> void:
	if not enabled:
		Engine.time_scale = 1.0
		return
	var now := Time.get_ticks_msec()
	if now < _stop_end:
		Engine.time_scale = STOP_SCALE
	elif now < _slow_end:
		Engine.time_scale = SLOW_SCALE
	else:
		Engine.time_scale = 1.0

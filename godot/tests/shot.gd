## Проверка без телефона: снимки экрана из разных мест и проверка касаний.
## Запуск: godot --path godot res://tests/shot.tscn -- <папка для снимков>
extends Node

var main: Node
var out := "user://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()  # закрываем главное меню
	await _frames(30)
	await _shot("g_spawn.png", func(): pass)
	# Джойстик: касание слева и сдвиг вверх — герой должен пойти вперёд
	var p0: Vector3 = main.hero.global_position
	_touch(0, Vector2(150, 280), true)
	for k in 6:
		_drag(0, Vector2(150, 280 - k * 12))
		await _frames(1)
	await _frames(60)
	_touch(0, Vector2(150, 220), false)
	var p1: Vector3 = main.hero.global_position
	print("JOYSTICK moved: ", snappedf(p0.distance_to(p1), 0.01), " from ", p0, " to ", p1)
	# Кнопка прыжка (справа внизу) — герой должен подпрыгнуть
	var vp := get_viewport().get_visible_rect().size
	var y0: float = main.hero.global_position.y
	_touch(1, Vector2(vp.x - 159, vp.y - 53), true)
	await _frames(8)
	print("JUMP rise: ", snappedf(main.hero.global_position.y - y0, 0.01))
	_touch(1, Vector2(vp.x - 159, vp.y - 53), false)
	await _frames(40)
	await _shot("g_manor.png", func(): _place(Vector3(-19, 4, -4), 0.2, 0.22, 12.0))
	await _shot("g_square.png", func(): _place(Vector3(2, 4, 14), -0.5, 0.35, 10.0))
	await _shot("g_gate.png", func(): _place(Vector3(0, 0, 52), 0.0, 0.3, 14.0))
	var e: Dictionary = main.world.entrances[1]
	var door: Vector3 = e["door"] + e["dir"] * 5.0
	await _shot("g_cave.png", func(): _place(door, atan2(e["dir"].x, e["dir"].z), 0.3, 9.0))
	await _shot("g_far.png", func(): _place(Vector3(-60, 0, -120), 2.6, 0.5, 16.0))
	print("SHOTS DONE")
	get_tree().quit()

func _place(p: Vector3, yaw: float, pitch: float, dist: float) -> void:
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z) if p.y == 0 else p + Vector3(0, 0.2, 0)
	main.hero.velocity = Vector3.ZERO
	main.rig.yaw = yaw
	main.rig.pitch = pitch
	main.rig.dist = dist
	main.rig.global_position = main.hero.global_position + Vector3(0, 1.7, 0)

func _shot(name: String, setup: Callable) -> void:
	setup.call()
	await _frames(45)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + name)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## pos — в координатах игрового экрана; переводим в координаты окна
func _win(pos: Vector2) -> Vector2:
	return pos * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = _win(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _drag(idx: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = _win(pos)
	Input.parse_input_event(ev)

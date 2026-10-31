## Раскадровка движений кролика: ходьба, бег, прыжок, джеб, прямой, крюк, комбо, удар в прыжке.
## Время останавливаем и ведём движения вручную, снимаем сбоку.
## Запуск: godot --path godot res://tests/bunny_moves.tscn -- <папка>
extends Node

var main: Node
var out := ""
var cam: Camera3D
var e: Node3D

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud.visible = false
	var p := Vector3(-60, 0, -120)
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z + 40) + 0.2, p.z + 40)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true
	main.rig.target = null
	e = main.enemies.list.filter(func(x): return x.type == "rabbit")[0]
	e.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z), p.z)
	e.reset_home()
	e.set_active(true)
	for i in 20:
		await get_tree().process_frame
	main.enemies.set_process(false)
	e.set_physics_process(false)
	e.facing = PI * 0.5            # смотрит вдоль +X
	e._model.rotation.y = e.facing
	e._ap.play(e.B_PUNCH)
	e._ap.seek(0.5, true)
	e._ap.speed_scale = 0.0        # стойка неподвижна: видно только движения BunnyMoves
	var m: BunnyMoves = e._moves
	print("moves: ", m != null)
	# Ходьба и бег
	await _row("walk", 8, 1.0 / 1.4 / 8.0, func(dt): m.update(dt, true, 0.9, false))
	await _row("run", 8, 1.0 / 3.5 / 8.0, func(dt): m.update(dt, true, 7.8, false))
	m.update(1.0, false, 0.0, false)
	# Прыжок и удар в прыжке
	m.start_leap(3.0, false)
	await _row("leap", 8, m.LEAP_DUR / 8.0, func(dt): m.update(dt, false, 0.0, false))
	m.update(1.0, false, 0.0, false)
	for kind in ["jab", "straight", "hook", "combo"]:
		m.start_attack(kind)
		var n := 8 if kind == "combo" else 4
		var dur: float = m.attack_dur(kind)
		await _row(kind, n, dur * 0.85 / n, func(dt): m.update(dt, false, 0.0, false))
		m.update(2.0, false, 0.0, false)
	m.start_leap(2.4, true)
	await _row("smash", 6, m.LEAP_DUR / 6.0, func(dt): m.update(dt, false, 0.0, false))
	get_tree().quit()

## Ряд кадров: перед каждым — шаг движений, затем снимок сбоку
func _row(name: String, n: int, step: float, advance: Callable) -> void:
	for k in n:
		advance.call(step)
		var c := Vector3(e.global_position.x, WorldGen.ground_at(e.global_position.x, e.global_position.z), e.global_position.z)
		cam.global_position = c + Vector3(0.9, 0.6, 3.0)
		cam.look_at(c + Vector3(0, 0.55, 0))
		for i in 2:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "%s_%d.png" % [name, k])

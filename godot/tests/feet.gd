## Ноги на склоне: герой стоит поперёк склона — обе стопы на земле, таз опущен.
## Запуск: godot --path godot res://tests/feet.tscn -- <папка>
extends Node

var main: Node
var ok := true
var cam: Camera3D

func _process(_dt: float) -> void:
	if cam and main and main.hero:
		var hp: Vector3 = main.hero.global_position
		var f: float = main.hero.facing
		var side := Vector3(cos(f), 0, -sin(f))
		cam.global_position = hp + Vector3(sin(f), 0, cos(f)) * 3.6 + Vector3(0, 0.9, 0)
		cam.look_at(hp + Vector3(0, 0.6, 0))

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	main.hud.visible = false
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	var h: Node3D = main.hero
	_check("foot IK ready", h._feet != null, "")
	# Ищем склон ~20–28° без деревьев рядом
	var best := Vector3.ZERO
	for x in range(-200, 200, 6):
		for z in range(-200, 200, 6):
			if WorldGen.town_dist(x, z) < 45:
				continue
			var ny := WorldGen.normal_y_at(x, z)
			if ny > 0.88 and ny < 0.93 and WorldGen.ground_at(x, z) > 2.0:
				best = Vector3(x, WorldGen.ground_at(x, z), z)
				break
		if best != Vector3.ZERO:
			break
	_check("slope found", best != Vector3.ZERO, str(best))
	# Смотрим поперёк склона: направление вдоль горизонтали
	var gx := WorldGen.ground_at(best.x + 1, best.z) - WorldGen.ground_at(best.x - 1, best.z)
	var gz := WorldGen.ground_at(best.x, best.z + 1) - WorldGen.ground_at(best.x, best.z - 1)
	var down := Vector2(gx, gz).normalized()
	h.global_position = best + Vector3(0, 0.3, 0)
	h.facing = atan2(-down.y, down.x)   # вдоль склона (горизонталь), склон сбоку
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	main.rig.target = null
	# Где стопы на самом деле (после IK) — по прикреплённым к костям узлам
	var sk0: Skeleton3D = h._feet.sk
	var marks := []
	for l in h._feet._legs:
		var ba := BoneAttachment3D.new()
		sk0.add_child(ba)
		ba.bone_idx = l["foot"]
		marks.append(ba)
	for i in 60:
		await get_tree().physics_frame
	h.facing = atan2(-down.y, down.x)
	for i in 30:
		await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "feet_on.png")
	var sk: Skeleton3D = h._feet.sk
	var gaps := []
	for ba in marks:
		var fp: Vector3 = ba.global_position
		gaps.append(fp.y - WorldGen.ground_at(fp.x, fp.z))
	print("offset ", h._feet.offset, " weight ", h._feet.weight, " foot gaps ", gaps)
	_check("feet near ground", absf(gaps[0] - gaps[1]) < 0.12, str(gaps))
	# Для сравнения — без IK
	h._feet.set_process(false)
	var keep = h._feet
	h._feet = null
	for l in keep._legs:
		l["ik"].active = false
	for i in 10:
		await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "feet_off.png")
	var gaps2 := []
	for ba in marks:
		var fp: Vector3 = ba.global_position
		gaps2.append(fp.y - WorldGen.ground_at(fp.x, fp.z))
	print("without IK foot gaps ", gaps2)
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond

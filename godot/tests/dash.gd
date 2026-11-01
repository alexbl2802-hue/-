## Рывок и его эволюция: числа по уровням, эволюция в Скользящий шаг, прорыв в Мерцание,
## урон сквозь врагов 20% и дальность в игре, окно профиля для каждой формы.
## Запуск: godot --path godot res://tests/dash.tscn -- <папка>
extends Node

var main: Node
var out := ""
var ok := true

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	# 1. Числа
	var st := func(sk: Dictionary) -> Dictionary: return SkillDefs.dash_stats(sk)
	var a: Dictionary = st.call({"dash": 1})
	var b: Dictionary = st.call({"dash": 10})
	var c: Dictionary = st.call({"dash": 10, "dash_slide": 5})
	var d: Dictionary = st.call({"dash": 10, "dash_slide": 5, "dash_blink": 1})
	_check("dash lvl1: +10%, 10 s", is_equal_approx(a["speed"], 1.1) and is_equal_approx(a["cd"], 10.0), str(a))
	_check("dash lvl10: +100%, 5.5 s", is_equal_approx(b["speed"], 2.0) and is_equal_approx(b["cd"], 5.5), str(b))
	_check("slide lvl5: +150%, 4.5 s", is_equal_approx(c["speed"], 2.5) and is_equal_approx(c["cd"], 4.5), str(c))
	_check("blink: +200%, 3 s", is_equal_approx(d["speed"], 3.0) and is_equal_approx(d["cd"], 3.0), str(d))
	# 2. Эволюция и прорыв
	Game.level = 10
	Game.skills = {"dash": 9}
	_check("no evolution before 10", not Game.can_evolve("dash"), "")
	Game.skills = {"dash": 10}
	_check("evolve to slide", Game.evolve("dash") and SkillDefs.dash_form(Game.skills) == "slide" and Game.rank("dash_slide") == 1, str(Game.skills))
	Game.skills["dash_slide"] = 4
	_check("no breakthrough before 5", not Game.can_evolve("dash"), "")
	await _profile("dash_slide.png")
	Game.skills["dash_slide"] = 5
	_check("breakthrough to blink", Game.evolve("dash") and SkillDefs.dash_form(Game.skills) == "blink", str(Game.skills))
	await _profile("dash_blink.png")
	Game.skills = {"dash": 10}
	await _profile("dash_max.png")
	Game.skills = {"dash": 3}
	await _profile("dash_3.png")
	# 3. В игре: урон сквозь врага 20% и дальность по скорости
	for sk in [{"dash": 1}, {"dash": 10, "dash_slide": 5, "dash_blink": 1}]:
		Game.skills = sk
		Game.refresh()
		var h: Node3D = main.hero
		var p := Vector3(-60, 0, -120)
		h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
		h.facing = 0.0
		h.cd["dash"] = 0.0
		var gob: Node3D = main.enemies.list.filter(func(e): return e.type == "goblin" and not e.dead)[0]
		gob.home = h.global_position + Vector3(0, 0, 2.5)
		gob.reset_home()
		gob.set_active(true)
		for i in 10:
			await get_tree().physics_frame
		var hp0: float = gob.hp
		var p0: Vector3 = h.global_position
		h.use_skill("dash")
		var peak := 0.0
		var k := 0
		for i in 40:
			await get_tree().physics_frame
			peak = maxf(peak, h._model.position.y)
			if SkillDefs.dash_form(sk) == "dash" and i % 6 == 2 and k < 4:
				main.rig.yaw = PI * 0.5
				main.rig.pitch = 0.1
				main.rig.dist = 7.0
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png(out + "jump_%d.png" % k)
				k += 1
		_check("dash %s: long jump %.2f m high" % [SkillDefs.dash_form(sk), peak], peak > 1.0, "")
		var dist := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
		var want: float = h.DASH_SPEED * SkillDefs.dash_stats(sk)["speed"] * h.DASH_TIME
		_check("dash %s: 20%% damage" % SkillDefs.dash_form(sk), absf((hp0 - gob.hp) - roundf(Game.dmg * 0.2)) <= 2.0, "hp %d → %d, dmg %d" % [hp0, gob.hp, Game.dmg])
		_check("dash %s: distance %.1f m (≈%.1f)" % [SkillDefs.dash_form(sk), dist, want], absf(dist - want) < want * 0.25, "")
		_check("dash %s: cooldown %.1f" % [SkillDefs.dash_form(sk), h.cd["dash"] + 40.0 / 60.0], absf(h.cooldown_total("dash") - SkillDefs.dash_stats(sk)["cd"]) < 0.01, "")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _profile(name: String) -> void:
	main.hud.open_skills()
	main.hud.skills._sel = "dash"
	main.hud.skills._render()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + name)
	main.hud.skills.close()
	for i in 3:
		await get_tree().process_frame

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond

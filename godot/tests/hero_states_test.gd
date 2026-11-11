## Этап 4: машина состояний героя, прерывания, перезарядки, root motion, синхронизация урона с
## активными кадрами, стойка с одним мечом, блок щитом/мечом и крепление щита к руке.
## Запуск: godot --headless --path godot res://tests/hero_states_test.tscn
extends Node

var main: Node
var h: Node
var ok := true

func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _place(p: Vector3) -> void:
	h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.3, p.z)
	h.velocity = Vector3.ZERO
	h.facing = 0.0

func _reset() -> void:
	h.touch.move = Vector2.ZERO
	h.touch.run = false
	h.touch.block = false
	h.touch.jump = false
	h._move = ""
	h.attack_t = -1.0
	h._dash_t = -1.0
	h._art_t = -1.0
	h._model.visible = true
	for k in h.cd:
		h.cd[k] = 0.0
	await _frames(30)

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	h = main.hero
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
		e.T["dmg"] = 0
	Game.level = 20
	Game.skills = {"dash": 1, "horizontal": 1, "art_sword": 1}
	Game.equip["weapon"] = Items.make("sword_iron")
	Game.equip["shield"] = null
	Game.refresh()
	h.update_look()
	var p := Vector3(-60, 0, -120)
	_place(p)
	await _reset()
	# ---- 1. Состояния передвижения
	var seen := {}
	for c in [[Vector2(0, 0.25), false], [Vector2(0, 1), false], [Vector2(0, 1), true]]:
		_place(p)
		h.touch.move = c[0]
		h.touch.run = c[1]
		for i in 90:
			await _frames(1)
			seen[h.states.current] = true
	await _reset()
	_check("states: walk, run, sprint reached", seen.has("walk") and seen.has("run") and seen.has("sprint"), str(seen.keys()))
	_check("state: idle/combat at rest", h.states.current in ["idle", "combat"], h.states.current)
	_place(Vector3(0, 0, 8))   # у стартовой точки — суша (в низине у p может быть вода)
	await _frames(20)
	h.touch.jump = true
	await _frames(2)
	h.touch.jump = false
	var air := false
	var landed := false
	for i in 120:
		await _frames(1)
		air = air or h.states.current == "jump"
		landed = landed or (air and h.states.current == "land")
	_check("state: jump then land", air and landed, str(h.states.log.slice(-6).map(func(x): return x[1])))
	await _reset()
	# ---- 2. Прерывания
	h.touch.block = true
	await _frames(10)
	_check("state: block", h.states.current == "block", h.states.current)
	h.attack()
	_check("block: attack rejected", h.attack_t < 0.0)
	await _reset()
	h._start_move("stun", Vector3.ZERO)
	await _frames(2)
	_check("state: stagger", h.states.current == "stagger", h.states.current)
	h.attack()
	h.use_skill("dash")
	h.use_skill("art_sword")
	h.use_skill("horizontal")
	h.dodge()
	_check("stagger: attack/dash/art/horizontal/dodge rejected", h.attack_t < 0.0 and h._dash_t < 0.0 and h._art_t < 0.0 and h._move == "stun",
		"attack %.2f dash %.2f art %.2f move %s" % [h.attack_t, h._dash_t, h._art_t, h._move])
	await _reset()
	h.use_skill("dash")
	await _frames(2)
	_check("state: dash", h.states.current == "dash", h.states.current)
	h.use_skill("art_sword")
	h.attack()
	_check("dash: art and attack rejected", h._art_t < 0.0 and h.attack_t < 0.0)
	_check("dash: cooldown started", h.cd["dash"] > 0.0, "%.2f" % h.cd["dash"])
	while h._dash_t >= 0.0:
		await _frames(1)
	h.use_skill("dash")
	_check("dash: second dash rejected on cooldown", h._dash_t < 0.0)
	h.cd["dash"] = 0.0
	h.use_skill("dash")
	_check("dash: allowed after cooldown", h._dash_t >= 0.0)
	await _reset()
	h.use_skill("art_sword")
	await _frames(2)
	_check("state: skill (art)", h.states.current == "skill", h.states.current)
	h.use_skill("dash")
	_check("art: dash rejected (no overlap)", h._dash_t < 0.0)
	await _reset()
	h.attack()
	await _frames(3)
	_check("state: attack", h.states.current == "attack", h.states.current)
	h.dodge()
	await _frames(2)
	_check("attack: dodge cancels the swing", h.attack_t < 0.0 and h.states.current in ["dodge", "roll"], h.states.current)
	await _reset()
	# ---- 3. Root motion: клипы ударов не двигают таз вперёд (иначе с движением тела было бы двойное)
	var worst := 0.0
	var worst_clip := ""
	var sk: Skeleton3D = h._sk
	var hips_name := sk.get_bone_name(PoseLib.bone(sk, "Hips"))
	for clip in h._rm:
		var a: Animation = h._anim.get_animation(clip) if h._anim.has_animation(clip) else null
		if a == null:
			continue
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(hips_name):
				var p0: Vector3 = a.position_track_interpolate(t, 0.0)
				var mx := 0.0
				for i in 30:
					var q: Vector3 = a.position_track_interpolate(t, a.length * i / 29.0)
					mx = maxf(mx, Vector2(q.x - p0.x, q.z - p0.z).length())
				if mx > worst:
					worst = mx
					worst_clip = clip
	_check("root motion: attack clips keep hips in place (no double move)", worst <= 0.06, "клипов %d, наибольший сдвиг таза %.3f м (%s)" % [h._rm.size(), worst, worst_clip])
	# ---- 4. Урон — в активных кадрах
	var gob: Node3D = main.enemies.list.filter(func(e): return e.type == "goblin" and not e.dead)[0]
	gob.T["hp"] = 99999
	gob.hp = 99999
	gob.set_active(true)
	_place(p)
	gob.global_position = h.global_position + Vector3(0, 0, 1.6)
	gob.home = gob.global_position
	await _frames(5)
	var hp0: float = gob.hp
	h.attack()
	var hit_t := -1.0
	for i in 90:
		await _frames(1)
		if gob.hp < hp0 and hit_t < 0.0:
			hit_t = h.attack_t
	_check("attack: damage inside blade window [%.2f, %.2f]" % [h.BLADE_FROM, h.BLADE_TO], hit_t >= h.BLADE_FROM - 0.02 and hit_t <= h.BLADE_TO + 0.02, "первый урон при t=%.3f" % hit_t)
	await _reset()
	_place(p)
	gob.global_position = h.global_position + Vector3(0, 0, 1.6)
	await _frames(5)
	hp0 = gob.hp
	h.use_skill("horizontal")
	var hz_t := -1.0
	for i in 120:
		await _frames(1)
		if gob.hp < hp0 and hz_t < 0.0:
			hz_t = h._move_t
	_check("horizontal: damage inside sweep window [%.2f, %.2f]" % [h.HZ_SWEEP[0], h.HZ_SWEEP[1]], hz_t >= h.HZ_SWEEP[0] - 0.02 and hz_t <= h.HZ_SWEEP[1] + 0.02, "первый урон при t=%.3f" % hz_t)
	await _reset()
	_place(p)
	gob.global_position = h.global_position + Vector3(0, 0, 2.0)
	await _frames(5)
	hp0 = gob.hp
	h.use_skill("dash")
	var dash_t := -1.0
	for i in 90:
		await _frames(1)
		if gob.hp < hp0 and dash_t < 0.0:
			dash_t = h._dash_t
	_check("dash: damage only while dashing", dash_t >= 0.0 and dash_t <= h.DASH_TIME + 0.02, "урон при t=%.3f (рывок %.2f с)" % [dash_t, h.DASH_TIME])
	await _reset()
	# ---- 5. Стойка с одним мечом, блок мечом/щитом, щит на руке
	var loco: AnimationNodeBlendSpace1D = (h._ha.tree.tree_root as AnimationNodeBlendTree).get_node("loco")
	var p0name := func(): return String((loco.get_blend_point_node(0) as AnimationNodeAnimation).animation)
	_check("stance: calm Idle without enemies, Combat_Stance in a fight", p0name.call() == (h.A_STANCE if h._in_fight else h.A_IDLE), "%s (в бою: %s)" % [p0name.call(), h._in_fight])
	_check("block: no shield -> sword block clip", h._ha._names.get("block", "") == h.BLOCK_CLIP[0], h._ha._names.get("block", ""))
	Game.equip["shield"] = Items.make("shield_wood")
	h.update_look()
	_check("block: shield -> shield block clip", h._ha._names.get("block", "") == h.A4_BLOCK_SHIELD, h._ha._names.get("block", ""))
	h.touch.block = true
	await _frames(40)
	_check("block with shield: block action plays", h._ha.current() == "block", h._ha.current())
	var shield: Node3D = null
	for k in h._shields:
		if h._shields[k].visible:
			shield = h._shields[k]
	var att := shield.get_parent().get_parent() as BoneAttachment3D if shield else null
	var fa := PoseLib.bone(sk, "LeftForeArm")
	var mid := (sk.global_transform * sk.get_bone_global_pose(fa).origin).lerp(sk.global_transform * sk.get_bone_global_pose(PoseLib.bone(sk, "LeftHand")).origin, 0.5)
	var dist: float = shield.global_position.distance_to(mid) if shield else 99.0
	_check("shield: attached to left forearm", att != null and att.bone_idx == fa and dist < 0.2,
		"кость %s, от середины предплечья %.3f м" % [sk.get_bone_name(att.bone_idx) if att else "-", dist])
	Game.equip["shield"] = null
	h.update_look()
	await _reset()
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)

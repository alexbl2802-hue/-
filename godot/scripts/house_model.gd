## Здания из присланных моделей Meshy (как есть, без упрощения): коттедж, особняк, колодец,
## кузница и лавка алхимика.
## Модель ставится по размеру участка, дверью (сторона +Z модели) в нужную сторону, на землю.
class_name HouseModel
extends RefCounted

const COTTAGE := "res://models/house_cottage.glb"
const MANOR := "res://models/house_manor.glb"
const WELL := "res://models/town_well.glb"            # колодец на площади
const FORGE := "res://models/town_forge.glb"          # кузница (The Emberforge Workshop)
const ALCHEMIST := "res://models/town_alchemist.glb"  # лавка алхимика (The Alchemist's Cottage)
const STALL := "res://models/town_stall.glb"          # торговая лавка на площади (Market Stall)
const NPC_BLACKSMITH := "res://models/npc_blacksmith.glb"   # кузнец (Ironclad Blacksmith)
const NPC_ALCHEMIST := "res://models/npc_alchemist.glb"     # алхимик (The Stoic Alchemist)
static var _cache := {}

static func _scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func exists(path: String) -> bool:
	return ResourceLoader.exists(path)

## Поставить дом: size — больший размер участка (м), yaw — куда смотрит дверь.
## Возвращает узел дома; столкновения — коробка по габаритам, если передан body.
static func place(parent: Node3D, path: String, pos: Vector3, yaw: float, size: float, body: StaticBody3D = null) -> Node3D:
	var ps := _scene(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	var aabb := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var bb := _xf_to(n, mi) * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in mi.mesh.get_surface_count():
			Mats.toon(mi.get_active_material(si))
	var s := size / maxf(aabb.size.x, aabb.size.z)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	root.add_child(n)
	n.scale = Vector3.ONE * s
	n.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	if body:
		var sh := BoxShape3D.new()
		sh.size = Vector3(aabb.size.x * s * 0.8, aabb.size.y * s, aabb.size.z * s * 0.8)
		var cs := CollisionShape3D.new()
		cs.shape = sh
		cs.position = pos + Vector3(0, aabb.size.y * s / 2.0, 0)
		cs.rotation.y = yaw
		body.add_child(cs)
	root.set_meta("size", aabb.size * s)
	return root

static func _xf_to(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D()
	var cur: Node = n
	while cur != root and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

## Житель: модель в натуральный рост, лицом (ось +Z модели) по yaw, стоит и дышит (клип «Idle»).
static func npc(parent: Node3D, path: String, pos: Vector3, yaw: float) -> Node3D:
	var ps := _scene(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in mi.mesh.get_surface_count():
			Mats.toon(mi.get_active_material(si))
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Боевой модуль (addons/combat_pack): у жителя есть блок и удары модуля поверх его стойки
	var sk := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if ap and sk:
		if not ap.has_animation("sword_block_loop"):
			var b := AdventureAnimationBuilder.new()
			b.skeleton = sk
			b.animation_player = ap
			b.base_clip = "Idle"
			n.add_child(b)
			b.build()
			b.queue_free()
		var combat := AdventureCombatController.new()
		combat.name = "CombatPack"
		combat.animation_player = ap
		n.add_child(combat)
	if ap:
		var clip := "Idle" if ap.has_animation("Idle") else ""
		if clip != "":
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			ap.play(clip)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	body.add_child(cs)
	n.add_child(body)
	return n

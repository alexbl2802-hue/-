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

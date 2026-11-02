## Лавка алхимика: каменный дом с куполом, вывеска с колбой, полки с цветными зельями,
## котёл у входа с зелёным варевом. Ставится в каждом городе (Камнеград, деревня Плато ветров).
## Дверь смотрит по локальной оси +Z; yaw разворачивает дом.
class_name Alchemist
extends RefCounted

const SHOP_RADIUS := 3.6      # подойти ближе — появится «⚗ Алхимик»

static func build(parent: Node3D, pos: Vector3, yaw: float, body: StaticBody3D) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	var stone := Mats.tiled(Mats.brick_texture(), 0x9a92a0, 0.25)
	var plaster := Mats.lp(0x6a4a8a)
	var trim := Mats.lp(0x3a2a4a)
	var gold := Mats.lp(0xe0b040, 0.35, 0.7, 0xa07010, 0.4)
	var w := 6.0
	var d := 5.0
	_box(n, Vector3(w + 0.4, 0.5, d + 0.4), stone, Vector3(0, 0.25, 0))
	_box(n, Vector3(w, 3.4, d), plaster, Vector3(0, 2.2, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(n, Vector3(0.3, 3.6, 0.3), trim, Vector3(sx * w / 2.0, 2.2, sz * d / 2.0))
	# Купол с колбой на макушке
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.6
	sm.height = 3.0
	sm.radial_segments = 16
	sm.rings = 8
	dome.mesh = sm
	dome.material_override = Mats.lp(0x3a7a6a, 0.5)
	dome.position = Vector3(0, 3.9, 0)
	dome.scale = Vector3(1.1, 1.0, 0.95)
	n.add_child(dome)
	_box(n, Vector3(w + 0.5, 0.35, d + 0.5), trim, Vector3(0, 3.95, 0))
	var flask := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.35
	fm.height = 0.7
	flask.mesh = fm
	flask.material_override = Mats.glow(0x60ffa0)
	flask.position = Vector3(0, 5.75, 0)
	n.add_child(flask)
	# Дверь, окна, вывеска
	_box(n, Vector3(1.2, 2.2, 0.12), Mats.lp(0x3a2414), Vector3(0, 1.6, d / 2.0 + 0.05))
	var glass := Mats.lp(0x7a9a6a, 0.15, 0.3, 0x40ff80, 0.8)
	for sx in [-1.9, 1.9]:
		_box(n, Vector3(1.0, 1.0, 0.12), glass, Vector3(sx, 2.3, d / 2.0 + 0.05))
	_box(n, Vector3(0.1, 0.1, 1.2), trim, Vector3(1.0, 3.3, d / 2.0 + 0.6))
	var sign := _box(n, Vector3(0.9, 0.7, 0.08), Mats.lp(0x5a3a22), Vector3(1.0, 2.85, d / 2.0 + 1.1))
	sign.rotation.y = PI / 2.0
	var bottle := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.18
	bm.height = 0.36
	bottle.mesh = bm
	bottle.material_override = Mats.glow(0xff60d0)
	bottle.position = Vector3(1.0, 2.85, d / 2.0 + 1.1)
	n.add_child(bottle)
	# Прилавок у двери с рядами цветных зелий
	_box(n, Vector3(2.4, 0.9, 0.7), Mats.lp(0x6a4a2a), Vector3(-1.6, 0.45, d / 2.0 + 0.8))
	var colors := [0xff4060, 0x4080ff, 0x60ff80, 0xffc040, 0xc060ff]
	for k in 6:
		var b := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.11
		cm.height = 0.28
		cm.radial_segments = 8
		b.mesh = cm
		b.material_override = Mats.lp(colors[k % colors.size()], 0.15, 0.2, colors[k % colors.size()], 0.6)
		b.position = Vector3(-2.5 + k * 0.36, 1.04, d / 2.0 + 0.8)
		n.add_child(b)
	# Котёл с бурлящим зельем
	var pot := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.6
	pm.height = 0.9
	pot.mesh = pm
	pot.material_override = Mats.lp(0x2a2a2e, 0.4, 0.8)
	pot.position = Vector3(2.0, 0.55, d / 2.0 + 1.4)
	n.add_child(pot)
	var brew := MeshInstance3D.new()
	var brm := CylinderMesh.new()
	brm.top_radius = 0.5
	brm.bottom_radius = 0.5
	brm.height = 0.05
	brew.mesh = brm
	brew.material_override = Mats.glow(0x50ff70)
	brew.position = Vector3(2.0, 0.92, d / 2.0 + 1.4)
	n.add_child(brew)
	var l := OmniLight3D.new()
	l.light_color = WorldGen.hex(0x70ff90)
	l.light_energy = 1.4
	l.omni_range = 6.0
	l.position = Vector3(2.0, 1.6, d / 2.0 + 1.4)
	n.add_child(l)
	l.add_to_group("night_lights")
	# Столкновения: дом и котёл
	var basis := Basis(Vector3.UP, yaw)
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, 4.0, d)
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.transform = Transform3D(basis, pos + Vector3(0, 2.0, 0))
	body.add_child(cs)
	var sh2 := CylinderShape3D.new()
	sh2.radius = 0.6
	sh2.height = 1.0
	var cs2 := CollisionShape3D.new()
	cs2.shape = sh2
	cs2.position = pos + basis * Vector3(2.0, 0.5, d / 2.0 + 1.4)
	body.add_child(cs2)

## Где стоять у лавки (перед дверью)
static func front(pos: Vector3, yaw: float) -> Vector3:
	return pos + Basis(Vector3.UP, yaw) * Vector3(-0.5, 0, 4.0)

static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

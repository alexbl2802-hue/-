## Город Камнеград: крепостная стена, ворота, улицы, 10 домов, поместье, кузница.
## Координаты те же, что в веб-версии; земля внутри стен ровная на высоте TOWN_Y.
class_name Town
extends RefCounted

const G := WorldGen.TOWN_Y
const W := WorldGen.TOWN_WALL
const GATE := 3.5

static var _root: Node3D
static var _body: StaticBody3D
static var _map: Array = []

## Строит город и возвращает прямоугольники построек для миникарты
static func build(parent: Node3D) -> Array:
	_root = Node3D.new()
	_root.name = "Town"
	parent.add_child(_root)
	_body = StaticBody3D.new()
	_body.name = "TownBody"
	_root.add_child(_body)
	_map = []
	var stone := Mats.tiled(Mats.brick_texture(), 0xc2b9a8)
	_walls(stone)
	_towers_and_gates(stone)
	_streets()
	var houses := [
		[-11, 12, 7, 6, 1, "+x"], [-11, 24, 6.5, 7, 2, "+x"], [-23, 14, 7.5, 6, 1, "+x"], [-24, 26, 7, 6.5, 2, "+x"],
		[11, 12, 7, 6.5, 2, "-x"], [11, 24, 6.5, 6, 1, "-x"], [23, 15, 7, 6, 1, "-x"], [24, 26.5, 7.5, 6.5, 2, "-x"],
		[11, -12, 7, 6, 2, "+z"], [23, -12, 7.5, 6, 1, "+z"],
	]
	for k in houses.size():
		var h: Array = houses[k]
		_house(h[0], h[1], h[2], h[3], h[4], h[5], k, stone)
	_garden()
	_forge(stone)
	_plaza(stone)
	_manor(stone)
	_lanterns()
	return _map

# ---------- Помощники
static func _mesh(mesh: Mesh, mat: Material, pos: Vector3, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi

static func _box(w: float, h: float, d: float, mat: Material, x: float, y: float, z: float) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	return _mesh(b, mat, Vector3(x, y, z))

static func _cyl(top: float, bottom: float, h: float, segs: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 0
	return m

static func _blob(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	return m

## Прямоугольное препятствие (и отметка на миникарте, если указан цвет)
static func _solid(x0: float, x1: float, z0: float, z1: float, map_color := "") -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1 - x0, 10.0, z1 - z0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3((x0 + x1) / 2.0, G + 5.0, (z0 + z1) / 2.0)
	_body.add_child(cs)
	if map_color != "":
		_map.append({"x0": x0, "x1": x1, "z0": z0, "z1": z1, "c": Color(map_color)})

static func _round(x: float, z: float, r: float, h := 10.0) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(x, G + h / 2.0, z)
	_body.add_child(cs)

## Двускатная крыша: конёк вдоль длинной стороны
static func _roof(w: float, d: float, rh: float, mat: Material, x: float, y: float, z: float) -> MeshInstance3D:
	var p := PrismMesh.new()
	p.size = Vector3(minf(w, d) + 0.9, rh, maxf(w, d) + 0.8)
	var mi := _mesh(p, mat, Vector3(x, y + rh / 2.0, z))
	if w > d:
		mi.rotation.y = PI / 2
	return mi

# ---------- Крепостная стена из блоков 4 м с зубцами
static func _walls(stone: Material) -> void:
	var segs := []
	var t := -W + 2.0
	while t < W:
		segs.append([t, -W, false])
		segs.append([t, W, false])
		segs.append([-W, t, true])
		segs.append([W, t, true])
		t += 4.0
	var wall_segs := segs.filter(func(s): return not (not s[2] and absf(s[0]) < GATE + 1.0))
	var merlons := []
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var seg_mesh := BoxMesh.new()
	seg_mesh.size = Vector3(4, 5, 1.6)
	mm.mesh = seg_mesh
	mm.instance_count = wall_segs.size()
	for i in wall_segs.size():
		var s: Array = wall_segs[i]
		var b := Basis(Vector3.UP, PI / 2 if s[2] else 0.0)
		mm.set_instance_transform(i, Transform3D(b, Vector3(s[0], G + 2.5, s[1])))
		for o in [-1.0, 1.0]:
			merlons.append([s[0] if s[2] else s[0] + o, s[1] + o if s[2] else s[1], s[2]])
	_multi(mm, stone)
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	var mer := BoxMesh.new()
	mer.size = Vector3(1, 0.9, 1.7)
	mm2.mesh = mer
	mm2.instance_count = merlons.size()
	for i in merlons.size():
		var m: Array = merlons[i]
		mm2.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI / 2 if m[2] else 0.0), Vector3(m[0], G + 5.45, m[1])))
	_multi(mm2, stone)
	var th := 0.8
	_solid(-W - th, -W + th, -W, W)
	_solid(W - th, W + th, -W, W)
	for zz in [-W, W]:
		_solid(-W, -GATE - 1.0, zz - th, zz + th)
		_solid(GATE + 1.0, W, zz - th, zz + th)

static func _multi(mm: MultiMesh, mat: Material) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_root.add_child(mmi)

# ---------- Башни: 4 угловые и по две у ворот; арки и открытые створки
static func _towers_and_gates(stone: Material) -> void:
	var tower_mat := Mats.tiled(Mats.brick_texture(), 0xc2b9a8)
	var roof_red := Mats.lp(0x9a3b2a)
	var dark_wood := Mats.lp(0x3a2414)
	var tower := func(x: float, z: float, r: float, h: float) -> void:
		_mesh(_cyl(r, r * 1.08, h, 12), tower_mat, Vector3(x, G + h / 2.0, z))
		_mesh(_cyl(0.0, r * 1.25, r * 1.5, 12), roof_red, Vector3(x, G + h + r * 0.75, z))
		_round(x, z, r)
	for x in [-W, W]:
		for z in [-W, W]:
			tower.call(x, z, 3.0, 8.5)
	for zz in [-W, W]:
		for x in [-GATE - 1.4, GATE + 1.4]:
			tower.call(x, zz, 2.0, 7.0)
		_box(9.4, 1.6, 2.2, stone, 0, G + 5.6, zz)
		var s := signf(zz)
		for side in [-1.0, 1.0]:
			var leaf := _box(2.6, 4.4, 0.2, dark_wood, side * (GATE - 0.3), G + 2.2, zz - s * 2.4)
			leaf.rotation.y = side * s * 1.25

# ---------- Улицы и площадь
static func _streets() -> void:
	var road := Mats.tiled(Mats.cobble_texture(), 0xa89f92, 0.25, 1.0)
	var main := PlaneMesh.new()
	main.size = Vector2(6, W * 2 + 4)
	_mesh(main, road, Vector3(0, G + 0.03, 0), false)
	var cross := PlaneMesh.new()
	cross.size = Vector2(W * 2 - 2, 5)
	_mesh(cross, road, Vector3(0, G + 0.035, 0), false)
	_mesh(_cyl(10.0, 10.0, 0.02, 28), road, Vector3(0, G + 0.04, 0), false)

# ---------- Дома с фахверком
static func _house(x: float, z: float, w: float, d: float, floors: int, face: String, k: int, stone: Material) -> void:
	var plasters := [0xeee4cf, 0xe8d8b0, 0xf2efe6, 0xdcc6a0, 0xe9d3c0]
	var roofs := [Mats.lp(0x9a3b2a), Mats.lp(0x7a4228), Mats.lp(0xb8913f), Mats.lp(0x4a5058)]
	var timber := Mats.lp(0x4a3220)
	var dark_wood := Mats.lp(0x3a2414)
	var glass := Mats.lp(0x6a8aa8, 0.15, 0.3, 0x30404c, 1.0)
	var hb := 3.1 * floors
	var wall_m := Mats.lp(plasters[k % plasters.size()])
	_box(w + 0.3, 0.5, d + 0.3, stone, x, G + 0.25, z)
	_box(w, hb, d, wall_m, x, G + hb / 2.0, z)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(0.26, hb, 0.26, timber, x + sx * w / 2.0, G + hb / 2.0, z + sz * d / 2.0)
	for f in range(1, floors + 1):
		var y := G + 3.1 * f - 0.1
		_box(w + 0.06, 0.22, 0.12, timber, x, y, z + d / 2.0)
		_box(w + 0.06, 0.22, 0.12, timber, x, y, z - d / 2.0)
		_box(0.12, 0.22, d + 0.06, timber, x + w / 2.0, y, z)
		_box(0.12, 0.22, d + 0.06, timber, x - w / 2.0, y, z)
	_roof(w, d, minf(w, d) * 0.55, roofs[k % roofs.size()], x, G + hb, z)
	_box(0.6, 1.8, 0.6, stone, x + (w * 0.3 if w > d else 0.6), G + hb + 1.3, z + (0.6 if w > d else d * 0.3))
	# Дверь и окна: дверь смотрит на улицу
	var fx := {"+x": 1, "-x": -1, "+z": 0, "-z": 0}[face] as int
	var fz := {"+x": 0, "-x": 0, "+z": 1, "-z": -1}[face] as int
	var half_f := w / 2.0 if fx != 0 else d / 2.0
	var along := d if fx != 0 else w
	var at := func(off: float, y: float, ww: float, hh: float, m: Material) -> void:
		_box(0.12 if fx != 0 else ww, hh, ww if fx != 0 else 0.12, m,
			x + fx * (half_f + 0.04) + (0.0 if fx != 0 else off), y, z + fz * (half_f + 0.04) + (off if fx != 0 else 0.0))
	at.call(0.0, G + 1.15, 1.1, 2.2, dark_wood)
	for off in [-along * 0.3, along * 0.3]:
		at.call(off, G + 1.6, 0.8, 0.8, glass)
	if floors > 1:
		for off in [-along * 0.3, 0.0, along * 0.3]:
			at.call(off, G + 4.6, 0.8, 0.8, glass)
	for sd in [-1, 1]:
		var sx: int = 0 if fx != 0 else sd
		var sz: int = sd if fx != 0 else 0
		var half := d / 2.0 if fx != 0 else w / 2.0
		_box(0.12 if sx != 0 else 0.8, 0.8, 0.8 if sx != 0 else 0.12, glass, x + sx * (half + 0.04), G + 1.6, z + sz * (half + 0.04))
	_solid(x - w / 2.0 - 0.15, x + w / 2.0 + 0.15, z - d / 2.0 - 0.15, z + d / 2.0 + 0.15, "#8a4a32")

# ---------- Огород на северо-востоке
static func _garden() -> void:
	var soil := Mats.lp(0x5a4028)
	var green := Mats.lp(0x4f8a32)
	var fence := Mats.lp(0x7a5a38)
	for i in 5:
		_box(16, 0.25, 1.4, soil, 20, G + 0.12, -29.5 + i * 2.2)
		for k in 10:
			_mesh(_blob(0.32), green, Vector3(13 + k * 1.55, G + 0.45, -29.5 + i * 2.2), false)
	for f in [[11, -31.5, 29, -31.5], [11, -19.6, 29, -19.6], [11, -31.5, 11, -19.6], [29, -31.5, 29, -19.6]]:
		var vert: bool = f[0] == f[2]
		var length := Vector2(f[2] - f[0], f[3] - f[1]).length()
		_box(0.12 if vert else length, 0.9, length if vert else 0.12, fence, (f[0] + f[2]) / 2.0, G + 0.45, (f[1] + f[3]) / 2.0)
	_map.append({"x0": 11, "x1": 29, "z0": -31.5, "z1": -19.6, "c": Color("#6a8a3a")})

# ---------- Кузница у поперечной улицы (окна улучшения пока закрыты)
static func _forge(stone: Material) -> void:
	var fx := 20.0
	var fz := -6.0
	var timber := Mats.lp(0x4a3220)
	var dark_wood := Mats.lp(0x3a2414)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(0.22, 3.2, 0.22, timber, fx + sx * 3, G + 1.6, fz + sz * 2.2)
			_round(fx + sx * 3, fz + sz * 2.2, 0.2, 3.2)
	var shed := _box(7, 0.18, 5.4, Mats.lp(0x7a4228), fx, G + 3.3, fz)
	shed.rotation.x = -0.14
	_box(3, 2.2, 1.8, stone, fx, G + 1.1, fz - 1.6)
	var mouth := BoxMesh.new()
	mouth.size = Vector3(1.1, 0.8, 0.1)
	_mesh(mouth, Mats.glow(0xff8a2a), Vector3(fx, G + 0.9, fz - 0.66), false)
	_box(0.9, 3.6, 0.9, stone, fx + 0.8, G + 3.8, fz - 1.9)
	_box(1.0, 0.6, 0.5, dark_wood, fx - 0.6, G + 0.3, fz + 0.6)
	var anvil := Mats.lp(0x3a3c40, 0.4, 0.7)
	_box(0.5, 0.5, 0.35, anvil, fx + 1.2, G + 0.25, fz + 0.6)
	_box(0.95, 0.25, 0.45, anvil, fx + 1.2, G + 0.62, fz + 0.6)
	_mesh(_cyl(0.45, 0.45, 0.8, 10), timber, Vector3(fx - 2.2, G + 0.4, fz - 1.2))
	_solid(fx - 1.6, fx + 1.6, fz - 2.6, fz - 0.6, "#6a5a4a")
	_round(fx + 1.2, fz + 0.6, 0.5, 1.0)
	_round(fx - 2.2, fz - 1.2, 0.5, 1.0)

# ---------- Площадь: колодец и торговые лавки (костёр ставит world.gd)
static func _plaza(stone: Material) -> void:
	var timber := Mats.lp(0x4a3220)
	_mesh(_cyl(1.1, 1.2, 1.0, 12), stone, Vector3(-6, G + 0.5, 6))
	_mesh(_cyl(0.9, 0.9, 0.02, 12), Mats.lp(0x1d4a6a, 0.1), Vector3(-6, G + 0.86, 6), false)
	for sx in [-1, 1]:
		_box(0.18, 2.4, 0.18, timber, -6 + sx * 1.05, G + 1.7, 6)
	_roof(2.6, 2.6, 0.9, Mats.lp(0x7a4228), -6, G + 2.8, 6)
	_round(-6, 6, 1.3, 3.0)
	var cloths := [Mats.lp(0xb83a32), Mats.lp(0x2f5f9a)]
	var goods := [0xd8402a, 0xe8b030, 0x6aa040, 0xa05a2a]
	var stalls := [[7.5, -7.0], [7.0, 7.5]]
	for i in 2:
		var x: float = stalls[i][0]
		var z: float = stalls[i][1]
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(0.14, 2.4, 0.14, timber, x + sx * 1.5, G + 1.2, z + sz * 1.1)
		_box(3.0, 0.9, 1.0, timber, x, G + 0.45, z + 0.6)
		var c := _box(3.6, 0.08, 2.8, cloths[i], x, G + 2.5, z)
		c.rotation.x = 0.18
		for k in 4:
			_mesh(_blob(0.2), Mats.lp(goods[k]), Vector3(x - 1 + k * 0.65, G + 1.05, z + 0.6), false)
		_solid(x - 1.6, x + 1.6, z - 1.2, z + 1.2)

# ---------- Поместье: двор с оградой, дом с крыльями, крыльцо, башенка, фонтан, сад
static func _manor(stone: Material) -> void:
	var mx0 := -31.0
	var mx1 := -7.0
	var mz0 := -31.0
	var mz1 := -7.0
	var low_wall := func(x0: float, z0: float, x1: float, z1: float) -> void:
		var vert := x0 == x1
		var length := Vector2(x1 - x0, z1 - z0).length()
		_box(0.6 if vert else length, 1.3, length if vert else 0.6, stone, (x0 + x1) / 2.0, G + 0.65, (z0 + z1) / 2.0)
		_solid(minf(x0, x1) - 0.3, maxf(x0, x1) + 0.3, minf(z0, z1) - 0.3, maxf(z0, z1) + 0.3)
	low_wall.call(mx0, mz0, mx1, mz0)
	low_wall.call(mx0, mz0, mx0, mz1)
	low_wall.call(mx1, mz0, mx1, mz1)
	low_wall.call(mx0, mz1, -21.5, mz1)
	low_wall.call(-16.5, mz1, mx1, mz1)
	var lamp := Mats.lp(0xffe0a0, 0.5, 0.0, 0xffb050, 1.6)
	for x in [-21.8, -16.2]:
		_box(0.9, 2.2, 0.9, stone, x, G + 1.1, mz1)
		_box(0.35, 0.45, 0.35, lamp, x, G + 2.45, mz1)
	_map.append({"x0": mx0, "x1": mx1, "z0": mz0, "z1": mz1, "c": Color("#7a9a50")})
	# Дорожка от площади к дому
	var path := PlaneMesh.new()
	path.size = Vector2(4, 10.5)
	_mesh(path, Mats.tiled(Mats.cobble_texture(), 0xa89f92, 0.25, 1.0), Vector3(-19, G + 0.03, -12.2), false)
	var white := Mats.lp(0xf4f0e6)
	var slate := Mats.lp(0x4a5058)
	var glass := Mats.lp(0x6a8aa8, 0.15, 0.3, 0x30404c, 1.0)
	var dark_wood := Mats.lp(0x3a2414)
	var mansion := func(x: float, z: float, w: float, d: float, h: float, rh: float) -> void:
		_box(w + 0.4, 0.6, d + 0.4, stone, x, G + 0.3, z)
		_box(w, h, d, white, x, G + h / 2.0, z)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(0.5, h, 0.5, stone, x + sx * w / 2.0, G + h / 2.0, z + sz * d / 2.0)
		_box(w + 0.1, 0.3, d + 0.1, stone, x, G + h - 0.15, z)
		_roof(w, d, rh, slate, x, G + h, z)
		_solid(x - w / 2.0 - 0.25, x + w / 2.0 + 0.25, z - d / 2.0 - 0.25, z + d / 2.0 + 0.25, "#4a5058")
	mansion.call(-19.0, -23.5, 13.0, 8.0, 7.0, 4.0)
	mansion.call(-27.5, -23.0, 4.5, 7.0, 5.2, 2.6)
	mansion.call(-10.5, -23.0, 4.5, 7.0, 5.2, 2.6)
	for k in range(-2, 3):
		for y in [1.8, 5.0]:
			if not (k == 0 and y < 3.0):
				_box(0.9, 1.3, 0.12, glass, -19 + k * 2.4, G + y, -19.45)
	for x in [-27.5, -10.5]:
		_box(0.9, 1.3, 0.12, glass, x, G + 2.2, -19.45)
	_box(1.6, 2.6, 0.14, dark_wood, -19, G + 1.3, -19.42)
	# Крыльцо с колоннами
	_box(4.4, 0.35, 2.2, stone, -19, G + 0.18, -18.3)
	for sx in [-1, 1]:
		_mesh(_cyl(0.22, 0.25, 3.2, 8), white, Vector3(-19 + sx * 1.8, G + 1.9, -17.5))
	_box(4.6, 0.3, 2.6, slate, -19, G + 3.6, -18.2)
	# Башенка с флагом
	_mesh(_cyl(1.8, 1.9, 10.0, 12), white, Vector3(-12.3, G + 5, -27.2))
	_mesh(_cyl(0.0, 2.3, 3.4, 12), slate, Vector3(-12.3, G + 11.7, -27.2))
	_box(0.08, 2.2, 0.08, dark_wood, -12.3, G + 14.3, -27.2)
	_box(1.3, 0.75, 0.04, Mats.lp(0x9a2a2a), -11.6, G + 15, -27.2)
	for k in 3:
		_box(0.12, 1.1, 0.7, glass, -10.45, G + 2.5 + k * 3, -27.2)
	_round(-12.3, -27.2, 1.9)
	# Фонтан
	_mesh(_cyl(2.4, 2.6, 0.7, 20), stone, Vector3(-19, G + 0.35, -12.5))
	_mesh(_cyl(2.15, 2.15, 0.02, 20), Mats.lp(0x3a8ac0, 0.1, 0.1), Vector3(-19, G + 0.62, -12.5), false)
	_mesh(_cyl(0.3, 0.4, 1.8, 10), stone, Vector3(-19, G + 1.3, -12.5))
	_mesh(_cyl(0.9, 0.4, 0.35, 14), stone, Vector3(-19, G + 2.2, -12.5))
	_round(-19, -12.5, 2.6, 2.0)
	# Сад: деревья и живая изгородь
	var timber := Mats.lp(0x4a3220)
	for p in [[-28, -10], [-28, -14.5], [-10, -10], [-10, -14.5]]:
		_box(0.35, 1.6, 0.35, timber, p[0], G + 0.8, p[1])
		_mesh(_blob(1.4), Mats.lp(0x4f8f3a), Vector3(p[0], G + 2.4, p[1]))
		_round(p[0], p[1], 0.5, 2.0)
	var hedge := Mats.lp(0x3f7a2e)
	for sx in [-1, 1]:
		_box(0.8, 0.9, 7, hedge, -19 + sx * 3.2, G + 0.45, -11.5)

# ---------- Фонари вдоль главной улицы (без источников света — бережём телефон)
static func _lanterns() -> void:
	var post := Mats.lp(0x3a2414)
	var lantern := Mats.lp(0xffe0a0, 0.5, 0.0, 0xffb050, 1.6)
	for z in [-28, -18, 18, 28]:
		for sx in [-1, 1]:
			_box(0.15, 3.2, 0.15, post, sx * 3.6, G + 1.6, z)
			var l := BoxMesh.new()
			l.size = Vector3(0.4, 0.5, 0.4)
			_mesh(l, lantern, Vector3(sx * 3.6, G + 3.4, z), false)
			_round(sx * 3.6, z, 0.25, 3.2)

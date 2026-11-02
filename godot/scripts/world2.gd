## Второй мир — новая местность над вершиной башни: Плато ветров. Свой рельеф (шум),
## золотая трава и скалы, деревья, деревня (лавка алхимика, кузница, костёр, портал вниз
## к подножию башни) и новые монстры. Лежит далеко от первого мира (смещение по X).
extends Node3D

const ORIGIN := Vector3(4000, 0, 0)   # центр плато в мире
const SIZE := 420.0                   # сторона квадрата, м
const STEP := 3.0                     # шаг сетки рельефа
const VILLAGE := Vector2(0, 0)        # деревня в центре (в координатах плато)
const NAME := "Плато ветров"

var start_pos := Vector3.ZERO         # где появляется герой (у портала)
var portal_pos := Vector3.ZERO
var forge_pos := Vector3.ZERO
var alchemist_pos := Vector3.ZERO
var campfire_pos := Vector3.ZERO
var spawns: Array = []                # [тип, позиция, уровень]
var _heights := PackedFloat32Array()
var _n := 0
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _portal: MeshInstance3D
var _time := 0.0

func build() -> void:
	name = "World2"
	position = ORIGIN
	_noise.seed = 2024
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_detail.seed = 77
	_detail.frequency = 0.03
	_build_terrain()
	_build_village()
	_build_trees_and_rocks()
	_build_border()
	_plan_monsters()

## Высота плато в точке (x, z — в координатах плато)
func height_at(x: float, z: float) -> float:
	var d := Vector2(x - VILLAGE.x, z - VILLAGE.y).length()
	var hills := _noise.get_noise_2d(x, z) * 22.0 + _detail.get_noise_2d(x, z) * 2.5 + 8.0
	# Деревня — ровная площадка, к краям плато — скалистые гряды
	var flat := smoothstep(28.0, 60.0, d)
	var edge := smoothstep(SIZE * 0.36, SIZE * 0.5, maxf(absf(x), absf(z)))
	return lerpf(6.0, hills, flat) + edge * 45.0

## Высота в мировых координатах
func ground_at_world(p: Vector3) -> float:
	return height_at(p.x - ORIGIN.x, p.z - ORIGIN.z) + ORIGIN.y

func _build_terrain() -> void:
	_n = int(SIZE / STEP) + 1
	_heights.resize(_n * _n)
	var half := SIZE / 2.0
	for j in _n:
		for i in _n:
			_heights[j * _n + i] = height_at(-half + i * STEP, -half + j * STEP)
	var mat := Mats.terrain()
	# Куски сетки по 40×40 клеток
	var chunk := 40
	for cj in range(0, _n - 1, chunk):
		for ci in range(0, _n - 1, chunk):
			var w := mini(chunk, _n - 1 - ci) + 1
			var d := mini(chunk, _n - 1 - cj) + 1
			var verts := PackedVector3Array()
			var cols := PackedColorArray()
			var norms := PackedVector3Array()
			var idx := PackedInt32Array()
			for j in d:
				for i in w:
					var gi := ci + i
					var gj := cj + j
					var x := -half + gi * STEP
					var z := -half + gj * STEP
					var y := _heights[gj * _n + gi]
					verts.append(Vector3(x, y, z))
					cols.append(_ground_color(x, z, y))
					var hl := _heights[gj * _n + maxi(gi - 1, 0)]
					var hr := _heights[gj * _n + mini(gi + 1, _n - 1)]
					var hd := _heights[maxi(gj - 1, 0) * _n + gi]
					var hu := _heights[mini(gj + 1, _n - 1) * _n + gi]
					norms.append(Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized())
			for j in d - 1:
				for i in w - 1:
					var a := j * w + i
					idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			add_child(mi)
	var body := StaticBody3D.new()
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = _n
	shape.map_depth = _n
	shape.map_data = _heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(cs)

## Цвет земли: золотая трава, рыжая на холмах, серый камень на гребнях
func _ground_color(x: float, z: float, y: float) -> Color:
	var v := _detail.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5
	var grass := Color8(118, 160, 58).lerp(Color8(86, 140, 46), v)
	var hill := Color8(176, 120, 58)
	var rock := Color8(128, 122, 116)
	var c := grass.lerp(hill, smoothstep(14.0, 26.0, y) * 0.7)
	return c.lerp(rock, smoothstep(30.0, 42.0, y))

# ---------- Деревня
func _build_village() -> void:
	var g := height_at(VILLAGE.x, VILLAGE.y)
	var c := Vector3(VILLAGE.x, g, VILLAGE.y)
	var stone := Mats.tiled(Mats.cobble_texture(), 0xb8ae9c, 0.25, 1.0)
	var plaza := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 16.0
	pm.bottom_radius = 16.0
	pm.height = 0.1
	pm.radial_segments = 32
	plaza.mesh = pm
	plaza.material_override = stone
	plaza.position = c + Vector3(0, 0.03, 0)
	add_child(plaza)
	# Портал вниз — к подножию башни
	portal_pos = c + Vector3(0, 0, -11)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 2.0
	tm.rings = 32
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = Mats.glow(0x7fd8ff)
	ring.rotation.x = PI / 2.0
	ring.position = portal_pos + Vector3(0, 2.2, 0)
	add_child(ring)
	_portal = ring
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 1.6
	dm.bottom_radius = 1.6
	dm.height = 0.02
	disc.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dmat.albedo_color = Color(0.5, 0.85, 1.0, 0.35)
	disc.material_override = dmat
	disc.rotation.x = PI / 2.0
	disc.position = ring.position
	add_child(disc)
	var pl := OmniLight3D.new()
	pl.light_color = WorldGen.hex(0x8fdcff)
	pl.light_energy = 2.0
	pl.omni_range = 10.0
	pl.position = ring.position
	add_child(pl)
	start_pos = portal_pos + Vector3(0, 0.3, 3.0)
	# Костёр в центре
	campfire_pos = c + Vector3(4, 0, 2)
	for i in 5:
		var a := i / 5.0 * TAU
		var lg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.12
		lm.bottom_radius = 0.12
		lm.height = 1.3
		lg.mesh = lm
		lg.material_override = Mats.lp(0x5a3b20)
		lg.position = campfire_pos + Vector3(cos(a) * 0.3, 0.25, -sin(a) * 0.3)
		lg.rotation = Vector3(0, a, PI / 2 - 0.35)
		add_child(lg)
	var fl := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.35
	fm.height = 1.0
	fl.mesh = fm
	fl.material_override = Mats.glow(0xffa233)
	fl.position = campfire_pos + Vector3(0, 0.6, 0)
	add_child(fl)
	var fire := OmniLight3D.new()
	fire.light_color = WorldGen.hex(0xff9a3c)
	fire.light_energy = 2.5
	fire.omni_range = 12.0
	fire.position = campfire_pos + Vector3(0, 1.2, 0)
	add_child(fire)
	# Дома по кругу, кузница и лавка алхимика
	var body := StaticBody3D.new()
	add_child(body)
	var homes := [[18, 8, 0.4], [-18, 6, -0.3], [14, -16, 0.9], [-16, -14, -0.8], [2, 20, 0.0]]
	for k in homes.size():
		var hp := Vector3(c.x + homes[k][0], 0, c.z + homes[k][1])
		hp.y = height_at(hp.x, hp.z)
		_house(hp, homes[k][2], k, body)
	forge_pos = c + Vector3(12, 0, 0)
	forge_pos.y = height_at(forge_pos.x, forge_pos.z)
	_forge(forge_pos, body)
	alchemist_pos = c + Vector3(-12, 0, 2)
	alchemist_pos.y = height_at(alchemist_pos.x, alchemist_pos.z)
	Alchemist.build(self, alchemist_pos, PI / 2.0, body)

func _box(size: Vector3, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi

func _col(body: StaticBody3D, pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	var sh := BoxShape3D.new()
	sh.size = size
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)

## Дом: каменный цоколь, деревянный сруб, высокая черепичная крыша
func _house(p: Vector3, yaw: float, k: int, body: StaticBody3D) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	var w := 6.0 + (k % 2)
	var d := 5.5
	var logs := Mats.lp([0x8a6a44, 0x7a5a3a, 0x9a7a50][k % 3])
	var roof_m := Mats.lp([0x5a6a7a, 0x7a3a2a, 0x4a5a3a][k % 3])
	_box(Vector3(w + 0.4, 0.6, d + 0.4), Mats.lp(0x7a746a), Vector3(0, 0.3, 0), n)
	_box(Vector3(w, 3.2, d), logs, Vector3(0, 2.2, 0), n)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(w + 1.0, 2.6, d + 1.0)
	roof.mesh = pr
	roof.material_override = roof_m
	roof.position = Vector3(0, 5.1, 0)
	n.add_child(roof)
	_box(Vector3(1.1, 2.0, 0.12), Mats.lp(0x3a2414), Vector3(0, 1.6, d / 2.0 + 0.05), n)
	for sx in [-1.8, 1.8]:
		_box(Vector3(0.8, 0.8, 0.12), Mats.lp(0x6a8aa8, 0.15, 0.3, 0x30404c, 1.0), Vector3(sx, 2.4, d / 2.0 + 0.05), n)
	_col(body, p + Vector3(0, 2.0, 0), Vector3(w, 4.0, d), yaw)

func _forge(p: Vector3, body: StaticBody3D) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var stone := Mats.lp(0x6a645c)
	_box(Vector3(4.0, 0.3, 4.0), stone, Vector3(0, 0.15, 0), n)
	for sx in [-1.8, 1.8]:
		for sz in [-1.8, 1.8]:
			_box(Vector3(0.3, 3.0, 0.3), Mats.lp(0x4a3220), Vector3(sx, 1.5, sz), n)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(4.6, 1.2, 4.6)
	roof.mesh = pr
	roof.material_override = Mats.lp(0x3a3a3a)
	roof.position = Vector3(0, 3.6, 0)
	n.add_child(roof)
	_box(Vector3(1.0, 0.6, 0.5), Mats.lp(0x2a2a2a, 0.5, 0.8), Vector3(0, 0.9, 0), n)   # наковальня
	_box(Vector3(1.4, 1.0, 1.4), stone, Vector3(1.0, 0.5, -1.0), n)                    # горн
	var glow := _box(Vector3(0.8, 0.2, 0.8), Mats.glow(0xff7020), Vector3(1.0, 1.05, -1.0), n)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = WorldGen.hex(0xff7a30)
	l.light_energy = 1.5
	l.omni_range = 6.0
	l.position = Vector3(1.0, 1.6, -1.0)
	n.add_child(l)
	_col(body, p + Vector3(1.0, 0.5, -1.0), Vector3(1.4, 1.0, 1.4))

# ---------- Деревья и скалы
func _build_trees_and_rocks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var path := "res://models/tree_ember_mid.glb"
	if not ResourceLoader.exists(path):
		path = "res://models/tree_ember.glb"
	if not ResourceLoader.exists(path):
		return
	var sc: Node3D = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	var aabb := mesh.get_aabb()
	sc.free()
	var items := []
	var half := SIZE / 2.0 - 30.0
	var body := StaticBody3D.new()
	add_child(body)
	while items.size() < 380:
		var x := r.randf_range(-half, half)
		var z := r.randf_range(-half, half)
		if Vector2(x - VILLAGE.x, z - VILLAGE.y).length() < 34.0:
			continue
		var y := height_at(x, z)
		if y > 30.0:
			continue
		var hgt := r.randf_range(7.0, 11.0)
		var k := hgt / aabb.size.y
		items.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * k), Vector3(x, y - aabb.position.y * k - 0.15, z)))
		var sh := CylinderShape3D.new()
		sh.radius = 0.4
		sh.height = 6.0
		var cs := CollisionShape3D.new()
		cs.shape = sh
		cs.position = Vector3(x, y + 2.0, z)
		body.add_child(cs)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i])
		var v := r.randf_range(0.8, 1.1)
		mm.set_instance_color(i, Color(v, v * r.randf_range(0.9, 1.05), v * 0.9))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m: Material = mesh.surface_get_material(0)
	if m is BaseMaterial3D:
		m = (m as BaseMaterial3D).duplicate()
		(m as BaseMaterial3D).vertex_color_use_as_albedo = true
		(m as BaseMaterial3D).metallic = 0.0
		(m as BaseMaterial3D).roughness = 1.0
		(m as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = m
	add_child(mmi)

## Края плато — невидимая стена, чтобы не уйти в пустоту
func _build_border() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var half := SIZE / 2.0
	for k in 4:
		var sh := BoxShape3D.new()
		sh.size = Vector3(SIZE + 4.0, 200.0, 2.0) if k < 2 else Vector3(2.0, 200.0, SIZE + 4.0)
		var cs := CollisionShape3D.new()
		cs.shape = sh
		cs.position = [Vector3(0, 100, -half), Vector3(0, 100, half), Vector3(-half, 100, 0), Vector3(half, 100, 0)][k]
		body.add_child(cs)

# ---------- Монстры плато: новые виды, ур. 22–28
const MONSTERS := [["stone_golem", 24], ["storm_wolf", 22], ["venom_spider", 23], ["thorn_beast", 26]]
func _plan_monsters() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var half := SIZE / 2.0 - 40.0
	while spawns.size() < 40:
		var x := r.randf_range(-half, half)
		var z := r.randf_range(-half, half)
		var dist := Vector2(x - VILLAGE.x, z - VILLAGE.y).length()
		if dist < 55.0 or height_at(x, z) > 30.0:
			continue
		var m: Array = MONSTERS[spawns.size() % MONSTERS.size()]
		var lvl: int = m[1] + int(dist / 60.0)   # дальше от деревни — сильнее
		spawns.append([m[0], ORIGIN + Vector3(x, height_at(x, z) + 0.3, z), lvl])

func _process(dt: float) -> void:
	if not visible:
		return
	_time += dt
	if _portal:
		_portal.rotation.z = _time * 0.8

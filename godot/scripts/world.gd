## Мир на поверхности: рельеф, вода, растительность, костёр, входы в подземелья и город.
extends Node3D

const CHUNK := 60
const TREE_SCALE := 1.2  # деревья крупнее, чем в веб-версии  # клеток рельефа в одном куске — куски вне экрана не рисуются

var entrances: Array = []   # [{name, door: Vector3, dir: Vector3}]
var town_map: Array = []    # прямоугольники построек для миникарты
var campfire: Node3D
var tower := {}             # башня этажей: {door, dir, pos}
const TOWER_POS := Vector2(-8.0, 66.0)   # к югу от городских ворот, на ровном месте
var _fire_light: OmniLight3D
var _fire_flame: MeshInstance3D
var _time := 0.0
var _rock_nodes: Array = []

## Дальность видимости камней (настройка «Дальность прорисовки»)
func set_rock_view(d: float) -> void:
	for n in _rock_nodes:
		(n as GeometryInstance3D).visibility_range_end = d
	for n in _tree_far_nodes:
		(n as GeometryInstance3D).visibility_range_end = maxf(d * 1.4, TREE_MID + 50.0)   # деревья видно дальше камней

## Деревья: какие модели у каждого вида (первая найденная; если модели нет — берётся другая)
const TREE_MODELS := {"pine": ["pine", "ember"], "oak": ["ember", "ancient"]}
const PINE_HEIGHT := 9.0        # высота ели при размере 1 (м)
const OAK_HEIGHT := 8.0
const TREE_CHUNK := 40.0        # деревья собраны по участкам 40×40 м
const TREE_NEAR := 45.0         # ближе — подробная модель (~60 тыс. треугольников)
const TREE_MID := 130.0         # до сюда — средняя (~8 тыс.), дальше — лёгкая (~1,5 тыс.)
var _tree_far_nodes: Array = []

## Модель дерева: lod 0 — вблизи, 1 — среднее расстояние, 2 — вдали
func _tree_path(name: String, lod: int) -> String:
	return "res://models/tree_%s%s.glb" % [name, ["", "_mid", "_far"][lod]]

func _build_tree_models(placed: Dictionary) -> void:
	# Какие модели есть
	var avail := {}
	for kind in TREE_MODELS:
		var list := []
		for nm in TREE_MODELS[kind]:
			if ResourceLoader.exists(_tree_path(nm, 0)) and not list.has(nm):
				list.append(nm)
		if kind == "oak" and list.is_empty() and ResourceLoader.exists(_tree_path("pine", 0)):
			list.append("pine")
		avail[kind] = list
	var meshes := {}
	for kind in avail:
		for nm in avail[kind]:
			if not meshes.has(nm):
				var lods := []
				for lod in 3:
					var path := _tree_path(nm, lod)
					lods.append(_model_mesh(path) if ResourceLoader.exists(path) else (lods[-1] if lod > 0 else _model_mesh(_tree_path(nm, 0))))
				meshes[nm] = lods
	# Участки: [x, z, модель] → [Transform3D, цвет]
	var chunks := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for kind in placed:
		var names: Array = avail[kind]
		if names.is_empty():
			continue
		var n := 0
		for it in placed[kind]:
			var nm: String = names[n % names.size()]
			n += 1
			var md: Dictionary = meshes[nm][0]
			var box: AABB = md["aabb"]
			var k: float = it[2] / box.size.y
			var pos: Vector3 = it[0]
			var y: float = pos.y - box.position.y * k - 0.15
			var tr := Transform3D(Basis(Vector3.UP, it[1]).scaled(Vector3.ONE * k), Vector3(pos.x, y, pos.z)) * (md["local"] as Transform3D)
			var key := [floori(pos.x / TREE_CHUNK), floori(pos.z / TREE_CHUNK), nm]
			if not chunks.has(key):
				chunks[key] = []
			var v := rng.randf_range(0.82, 1.08)   # деревья чуть разные по цвету
			chunks[key].append([tr, Color(v, v * rng.randf_range(0.96, 1.04), v)])
	for key in chunks:
		var list: Array = chunks[key]
		for lod in 3:
			var md: Dictionary = meshes[key[2]][lod]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = md["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				# Дальняя модель — та же посадка, своё смещение внутри файла
				var t0: Transform3D = list[i][0]
				if lod > 0:
					t0 = t0 * (meshes[key[2]][0]["local"] as Transform3D).affine_inverse() * (md["local"] as Transform3D)
				mm.set_instance_transform(i, t0)
				mm.set_instance_color(i, list[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _tree_material(md["mesh"])
			match lod:
				0:
					mmi.visibility_range_end = TREE_NEAR
				1:
					mmi.visibility_range_begin = TREE_NEAR
					mmi.visibility_range_end = TREE_MID
				2:
					mmi.visibility_range_begin = TREE_MID
					mmi.visibility_range_end = maxf(ROCK_VIEW * 1.4, TREE_MID + 50.0)
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					_tree_far_nodes.append(mmi)
			add_child(mmi)

## Материал дерева: текстура модели × цвет экземпляра (лёгкая разница оттенков), не металл
func _tree_material(mesh: Mesh) -> Material:
	var m: Material = mesh.surface_get_material(0)
	if m is BaseMaterial3D:
		m = (m as BaseMaterial3D).duplicate()
		(m as BaseMaterial3D).vertex_color_use_as_albedo = true
		(m as BaseMaterial3D).metallic = 0.0
		(m as BaseMaterial3D).roughness = 1.0
		(m as BaseMaterial3D).metallic_specular = 0.15   # листья и кора матовые, без блеска
		(m as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED   # листья видны с обеих сторон
	return m

## Камни и горы — модели Meshy (tools/prepare_models.py env)
const ROCK_SMALL := "res://models/rock_small.glb"                                  # Mossy Stone Outcrop
const ROCK_BIG := ["res://models/rock_big1.glb", "res://models/rock_big2.glb"]    # Mossclad Monolith, Mossbound Stone Steps
const ROCK_CHUNK := 120.0       # камни собраны по участкам — далёкие участки не рисуются
const ROCK_VIEW := 200.0
const WATER_SHADER := "res://shaders/water/water_mobile.gdshader"   # реалистичный читает глубину сцены — в GL Compatibility она недоступна

func build() -> void:
	_build_terrain()
	_build_water()
	_build_vegetation()
	_build_rocks()
	_build_campfire()
	_build_entrances()
	_build_tower()
	town_map = Town.build(self)

func _process(dt: float) -> void:
	_time += dt
	if _fire_light:
		_fire_light.light_energy = 3.0 * (0.8 + 0.2 * sin(_time * 13.0) * sin(_time * 7.3))
		_fire_flame.scale.y = 0.85 + 0.2 * sin(_time * 11.0)

# ---------- Рельеф
func _build_terrain() -> void:
	var seg := WorldGen.seg
	var n := seg + 1
	var step := WorldGen.step
	var h := WorldGen.heights
	var c := WorldGen.colors
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("detail", Mats.noise_texture("grain"))
	mat.set_shader_parameter("macro", Mats.noise_texture("macro"))
	mat.set_shader_parameter("rock", Mats.noise_texture("rock"))
	# Склоны гор — камень со мхом с модели Mossy Stone Peak
	mat.set_shader_parameter("mountain", load("res://textures/mountain_rock.jpg"))
	for cj in range(0, seg, CHUNK):
		for ci in range(0, seg, CHUNK):
			var w := mini(CHUNK, seg - ci) + 1
			var d := mini(CHUNK, seg - cj) + 1
			var verts := PackedVector3Array()
			var cols := PackedColorArray()
			var norms := PackedVector3Array()
			var idx := PackedInt32Array()
			verts.resize(w * d)
			cols.resize(w * d)
			norms.resize(w * d)
			for j in d:
				for i in w:
					var gi := ci + i
					var gj := cj + j
					var k := gj * n + gi
					var x := -WorldGen.HALF + gi * step
					var z := -WorldGen.HALF + gj * step
					verts[j * w + i] = Vector3(x, h[k], z)
					cols[j * w + i] = Color8(c[k * 3], c[k * 3 + 1], c[k * 3 + 2])
					norms[j * w + i] = Vector3.UP
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
	# Столкновения с землёй — карта высот
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = h
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)
	add_child(body)

## Вода — мобильный шейдер воды с бликами и волнами (shaders/water)
func _build_water() -> void:
	var m := ShaderMaterial.new()
	m.shader = load(WATER_SHADER)
	var plane := PlaneMesh.new()
	plane.size = Vector2(WorldGen.WORLD * 1.6, WorldGen.WORLD * 1.6)
	plane.subdivide_width = 160
	plane.subdivide_depth = 160
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.position.y = WorldGen.WATER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ---------- Деревья, камни, трава
func _cyl(top: float, bottom: float, height: float, segs: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segs
	m.rings = 0
	return m

func _blob(r: float, segs := 6, rings := 3) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = rings
	return m

## items: [[Vector3 pos, float rot, Vector3 scale, Color]]
func _multimesh(mesh: Mesh, mat: Material, items: Array, shadow := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var b := Basis(Vector3.UP, it[1]) * Basis.from_scale(it[2])
		mm.set_instance_transform(i, Transform3D(b, it[0]))
		mm.set_instance_color(i, it[3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_vegetation() -> void:
	var p: Dictionary = WorldGen.props
	var body := StaticBody3D.new()
	body.name = "Props"
	add_child(body)
	# Деревья — модели Meshy (tools/prepare_models.py trees): ели — Evergreen Sentinel,
	# лиственные — Autumn Ember и Ancient Woodland Guardian по очереди. Каждое дерево в двух
	# версиях: подробная вблизи и лёгкая вдали; деревья собраны по участкам, далёкие не рисуются.
	var placed := {"pine": [], "oak": []}   # [позиция, поворот, высота]
	for t in p["pines"]:
		var pos := Vector3(t[0], t[2], t[1])
		var s: float = t[3] * TREE_SCALE
		placed["pine"].append([pos, t[4], PINE_HEIGHT * s])
		_tree_collider(body, pos, 0.3 * s)
	for t in p["oaks"]:
		var pos := Vector3(t[0], t[2], t[1])
		var s: float = t[3] * TREE_SCALE
		placed["oak"].append([pos, t[4], OAK_HEIGHT * s])
		_tree_collider(body, pos, 0.33 * s)
	_build_tree_models(placed)
	# Трава
	var tufts := []
	for t in p["tufts"]:
		var s: float = t[3]
		tufts.append([Vector3(t[0], t[2] - 0.05, t[1]), t[4], Vector3(s, s, s) * 1.15, WorldGen.hex(int(t[5]))])
	var grass := ShaderMaterial.new()
	grass.shader = load("res://shaders/grass.gdshader")
	_multimesh(_grass_mesh(), grass, tufts, false)

## Пучок травы: семь тонких изогнутых травинок разной высоты, расходятся в стороны
func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for k in 7:
		var a := TAU * k / 7.0 + r.randf() * 0.5
		var h := 0.55 + r.randf() * 0.3
		var lean := Vector3(cos(a), 0, sin(a)) * (0.12 + r.randf() * 0.15)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.035
		var base := Vector3(cos(a), 0, sin(a)) * 0.06
		var mid := base + lean * 0.4 + Vector3(0, h * 0.55, 0)
		var top := base + lean + Vector3(0, h, 0)
		st.add_vertex(base - side)
		st.add_vertex(base + side)
		st.add_vertex(mid + side * 0.6)
		st.add_vertex(base - side)
		st.add_vertex(mid + side * 0.6)
		st.add_vertex(mid - side * 0.6)
		st.add_vertex(mid - side * 0.6)
		st.add_vertex(mid + side * 0.6)
		st.add_vertex(top)
	st.generate_normals()
	return st.commit()

## Сетка модели и её положение внутри файла (для MultiMesh и столкновений)
func _model_mesh(path: String) -> Dictionary:
	var sc: Node3D = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var t := Transform3D()
	var n: Node = mi
	while n != sc:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	var mesh: Mesh = mi.mesh.duplicate()
	sc.free()
	# Камень не металл: у моделей Meshy материал помечен металлическим и блестит, как хром
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m is BaseMaterial3D:
			m = m.duplicate()
			m.metallic = 0.0
			m.metallic_texture = null
			m.roughness = maxf(m.roughness, 0.85)
			mesh.surface_set_material(i, m)
	return {"mesh": mesh, "local": t, "aabb": t * mesh.get_aabb()}

## Камни: маленькие — Outcrop, большие — Monolith и Steps по очереди. Размер как у прежних камней,
## низ чуть утоплен в землю; большие мешают пройти
func _build_rocks() -> void:
	var models := [_model_mesh(ROCK_SMALL), _model_mesh(ROCK_BIG[0]), _model_mesh(ROCK_BIG[1])]
	var body := StaticBody3D.new()
	body.name = "Rocks"
	add_child(body)
	var chunks := {}   # [ключ участка, модель] → [Transform3D]
	var n_big := 0
	for r in WorldGen.props["rocks"]:
		var s: float = r[3]
		var kind := 0
		if s > 0.9:
			kind = 1 + n_big % 2
			n_big += 1
		var md: Dictionary = models[kind]
		var box: AABB = md["aabb"]
		var k := 2.4 * s / maxf(box.size.x, box.size.z)
		var y: float = r[2] - box.position.y * k - box.size.y * k * 0.15
		var tr := Transform3D(Basis(Vector3.UP, r[4]).scaled(Vector3.ONE * k), Vector3(r[0], y, r[1])) * (md["local"] as Transform3D)
		var key := Vector3i(floori(r[0] / ROCK_CHUNK), floori(r[1] / ROCK_CHUNK), kind)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(tr)
		if kind > 0:
			_tree_collider(body, Vector3(r[0], r[2], r[1]), s * 1.0)
	for key in chunks:
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = models[key.z]["mesh"]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = ROCK_VIEW
		add_child(mmi)
		_rock_nodes.append(mmi)

func _tree_collider(body: StaticBody3D, pos: Vector3, r: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 6.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos + Vector3(0, 2.0, 0)
	body.add_child(cs)

# ---------- Костёр на площади
func _build_campfire() -> void:
	campfire = Node3D.new()
	campfire.name = "Campfire"
	var logm := Mats.lp(0x5a3b20)
	for i in 5:
		var a := i / 5.0 * TAU
		var lg := MeshInstance3D.new()
		lg.mesh = _cyl(0.12, 0.12, 1.3, 6)
		lg.material_override = logm
		lg.position = Vector3(cos(a) * 0.3, 0.25, -sin(a) * 0.3)
		lg.rotation = Vector3(0, a, PI / 2 - 0.35)
		campfire.add_child(lg)
	var stone := Mats.lp(0x777777)
	for i in 9:
		var a := i / 9.0 * TAU
		var st := MeshInstance3D.new()
		st.mesh = _blob(0.22, 5, 2)
		st.material_override = stone
		st.position = Vector3(cos(a) * 0.85, 0.1, sin(a) * 0.85)
		campfire.add_child(st)
	_fire_flame = MeshInstance3D.new()
	_fire_flame.mesh = _cyl(0.0, 0.35, 1.0, 6)
	_fire_flame.material_override = Mats.glow(0xffa233)
	_fire_flame.position.y = 0.6
	_fire_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	campfire.add_child(_fire_flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = WorldGen.hex(0xff9a3c)
	_fire_light.omni_range = 14.0
	_fire_light.position.y = 1.2
	campfire.add_child(_fire_light)
	campfire.position = Vector3(4, WorldGen.ground_at(4, 3), 3)
	add_child(campfire)
	var body := StaticBody3D.new()
	add_child(body)
	_tree_collider(body, campfire.position, 1.0)

# ---------- Входы в подземелья
func _build_entrances() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	for idx in WorldGen.sites.size():
		var s: Dictionary = WorldGen.sites[idx]
		var g := Node3D.new()
		var stone := Mats.lp(0x8a8478 if idx == 0 else 0x6f6a66)
		for x in [-1.9, 1.9]:
			_box(g, Vector3(1.0, 4.2, 1.0), stone, Vector3(x, 2.1, 0))
		_box(g, Vector3(5.2, 0.9, 1.3), stone, Vector3(0, 4.6, 0))
		var dark := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.8, 4.2)
		dark.mesh = q
		dark.material_override = Mats.glow(0x000000)
		dark.position = Vector3(0, 2.1, -0.2)
		g.add_child(dark)
		var mound := MeshInstance3D.new()
		mound.mesh = _blob(6.0, 8, 4)
		mound.material_override = Mats.lp(0x5d7a3a if idx == 0 else 0x6d6862)
		mound.scale = Vector3(1.1, 0.85, 0.9)
		mound.position = Vector3(0, 1.2, -5.2)
		g.add_child(mound)
		for i in 3:
			_box(g, Vector3(2.8, 0.2, 0.6), stone, Vector3(0, 0.1 - i * 0.18, 0.9 - i * 0.6))
		for x in [-2.7, 2.7]:
			var post := MeshInstance3D.new()
			post.mesh = _cyl(0.08, 0.1, 1.8, 5)
			post.material_override = Mats.lp(0x4a3220)
			post.position = Vector3(x, 0.9, 1.0)
			g.add_child(post)
			var fl := MeshInstance3D.new()
			fl.mesh = _cyl(0.0, 0.17, 0.45, 5)
			fl.material_override = Mats.glow(0xffb040)
			fl.position = Vector3(x, 2.0, 1.0)
			g.add_child(fl)
		var light := OmniLight3D.new()
		light.light_color = WorldGen.hex(0xff9a3c)
		light.light_energy = 1.5
		light.omni_range = 10.0
		light.position = Vector3(0, 3, 2)
		g.add_child(light)
		var angle := atan2(-float(s["x"]), -float(s["z"]))  # лицом к городу
		g.rotation.y = angle
		g.position = Vector3(s["x"], s["h"], s["z"])
		add_child(g)
		var dir := Vector3(sin(angle), 0, cos(angle))
		var basis := Basis(Vector3.UP, angle)
		for x in [-1.9, 1.9]:
			_tree_collider(body, g.position + basis * Vector3(x, 0, 0), 0.7)
		_tree_collider(body, g.position + basis * Vector3(0, 0, -5.2), 4.8)
		entrances.append({"name": s["name"], "door": g.position + dir * 1.0, "dir": dir, "x": s["x"], "z": s["z"]})

# ---------- Башня этажей: высокая каменная башня, дверь смотрит на город
func _build_tower() -> void:
	var x := TOWER_POS.x
	var z := TOWER_POS.y
	var base := 99.0
	for a in 12:
		var ang := TAU * a / 12.0
		base = minf(base, WorldGen.ground_at(x + cos(ang) * 8.0, z + sin(ang) * 8.0))
	var g := Node3D.new()
	g.position = Vector3(x, base - 0.5, z)
	add_child(g)
	var stone := Mats.tiled(Mats.brick_texture(), 0x9a9288)
	var dark_stone := Mats.lp(0x5a544c)
	var R := 7.0
	var H := 38.0
	var body := MeshInstance3D.new()
	body.mesh = _cyl(R * 0.9, R, H, 16)
	body.material_override = stone
	body.position.y = H / 2.0
	g.add_child(body)
	# Пояса и зубцы наверху
	for yy in [10.0, 20.0, 30.0]:
		var belt := MeshInstance3D.new()
		belt.mesh = _cyl(R * (1.0 - yy / H * 0.1) + 0.3, R * (1.0 - yy / H * 0.1) + 0.3, 0.6, 16)
		belt.material_override = dark_stone
		belt.position.y = yy
		g.add_child(belt)
	var top := MeshInstance3D.new()
	top.mesh = _cyl(R * 0.95 + 0.6, R * 0.9, 1.6, 16)
	top.material_override = stone
	top.position.y = H + 0.8
	g.add_child(top)
	for k in 12:
		var a := TAU * k / 12.0
		_box(g, Vector3(1.4, 1.4, 0.8), stone, Vector3(cos(a) * (R * 0.95 + 0.2), H + 2.3, sin(a) * (R * 0.95 + 0.2))).rotation.y = -a + PI / 2.0
	var roof := MeshInstance3D.new()
	roof.mesh = _cyl(0.0, R * 0.8, 9.0, 16)
	roof.material_override = Mats.lp(0x3a4a6a)
	roof.position.y = H + 5.5
	g.add_child(roof)
	# Окна светятся тёплым светом
	var win := Mats.glow(0xffb860)
	for k in 8:
		var a := TAU * k / 8.0 + 0.4
		var yy := 8.0 + (k % 4) * 7.5
		var rr := R * (1.0 - yy / H * 0.1) + 0.02
		var w := _box(g, Vector3(0.9, 1.6, 0.1), win, Vector3(sin(a) * rr, yy, cos(a) * rr))
		w.rotation.y = a
	# Дверь со стороны города (на север, к −z), ступени и факелы
	var dir := Vector3(0, 0, -1)
	var door_pos := Vector3(0, 0, -R)
	var arch := Node3D.new()
	arch.position = door_pos
	arch.rotation.y = PI
	g.add_child(arch)
	for sx in [-1.7, 1.7]:
		_box(arch, Vector3(0.8, 4.4, 1.2), dark_stone, Vector3(sx, 2.2 + 0.5, 0.2))
	_box(arch, Vector3(4.2, 0.9, 1.3), dark_stone, Vector3(0, 5.1, 0.2))
	var dark := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 4.0)
	dark.mesh = q
	dark.material_override = Mats.glow(0x000000)
	dark.position = Vector3(0, 2.5, 0.75)
	arch.add_child(dark)
	for i in 3:
		_box(arch, Vector3(3.4, 0.3, 0.7), dark_stone, Vector3(0, 0.35 - i * 0.2, 1.1 + i * 0.6))
	for sx in [-2.5, 2.5]:
		var post := MeshInstance3D.new()
		post.mesh = _cyl(0.08, 0.1, 2.0, 5)
		post.material_override = Mats.lp(0x4a3220)
		post.position = Vector3(sx, 1.5, 1.3)
		arch.add_child(post)
		var fl := MeshInstance3D.new()
		fl.mesh = _cyl(0.0, 0.17, 0.45, 5)
		fl.material_override = Mats.glow(0xffb040)
		fl.position = Vector3(sx, 2.7, 1.3)
		arch.add_child(fl)
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xff9a3c)
	light.light_energy = 1.5
	light.omni_range = 10.0
	light.position = Vector3(0, 3.5, 2.5)
	arch.add_child(light)
	var sb := StaticBody3D.new()
	add_child(sb)
	var sh := CylinderShape3D.new()
	sh.radius = R
	sh.height = H
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = g.position + Vector3(0, H / 2.0, 0)
	sb.add_child(cs)
	var door := g.position + door_pos + dir * 1.2
	tower = {"door": Vector3(door.x, WorldGen.ground_at(door.x, door.z), door.z), "dir": dir, "pos": g.position}

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

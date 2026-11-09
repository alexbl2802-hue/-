## Мир на поверхности: рельеф, вода, растительность, костёр, входы в подземелья и город.
extends Node3D

const CHUNK := 60
const TREE_SCALE := 1.2  # деревья крупнее, чем в веб-версии  # клеток рельефа в одном куске — куски вне экрана не рисуются

var entrances: Array = []   # [{name, door: Vector3, dir: Vector3}]
var town_map: Array = []    # прямоугольники построек для миникарты
var campfire: Node3D
var tower := {}             # башня этажей: {door, dir, pos}
const TOWER_POS := Vector2(-8.0, 70.0)   # к югу от городских ворот, на ровном месте
const TOWER_R := 11.0
const TOWER_ABOVE_PEAKS := 15.0           # вершина башни на 15 м выше самой высокой горы
var _fire_light: OmniLight3D
var _fire_flame: MeshInstance3D
var _time := 0.0
var _rock_nodes: Array = []

## Дальность видимости камней (настройка «Дальность прорисовки»)
func set_rock_view(d: float) -> void:
	for n in _rock_nodes:
		(n as GeometryInstance3D).visibility_range_end = maxf(d, ROCK_MID + 40.0)
	for n in _tree_far_nodes:
		(n as GeometryInstance3D).visibility_range_end = maxf(d * 1.4, TREE_MID + 50.0)   # деревья видно дальше камней

## Деревья: какие модели у каждого вида (первая найденная; если модели нет — берётся другая)
## Каждое второе дерево — Evergreen Sentinel, каждое третье — Ancient Woodland Guardian
## (присланные модели, вблизи — как есть): прежний порядок через одно, затем каждое третье
## место — новое дерево; цикл из 12 мест
const TREE_MODELS := {
	"pine": ["pine", "sentinel", "woodland", "sentinel", "pine", "woodland", "ember", "sentinel", "woodland", "sentinel", "ember", "woodland"],
	"oak": ["ember", "sentinel", "woodland", "sentinel", "ember", "woodland", "ancient", "sentinel", "woodland", "sentinel", "ancient", "woodland"],
}
const PINE_HEIGHT := 9.0        # высота ели при размере 1 (м)
const OAK_HEIGHT := 8.0
const TREE_MIN_GAP := 0.45       # деревья ближе 0,45 их средней высоты (~4,7 м) друг к другу — одно убирается
const TREE_MAX_SLOPE := 0.88     # на склонах круче ~28° деревья не растут
const TREE_BASE_R := 0.28        # радиус основания с корнями — доля высоты дерева
const TREE_CHUNK := 40.0        # деревья собраны по участкам 40×40 м
const TREE_FULL := 25.0         # ближе — полная модель (у присланных деревьев — половина треугольников)
const TREE_NEAR := 60.0         # до сюда — подробная копия (~60 тыс. треугольников, файл *_near)
const TREE_MID := 130.0         # до сюда — средняя (~8 тыс.), дальше — лёгкая (~1,5 тыс.)
const TREE_FULL_CHUNK := 8.0    # ближние деревья — мелкими участками: дальность считается почти до каждого дерева
var _tree_far_nodes: Array = []

## Модель дерева: lod 0 — вблизи, 1 — среднее расстояние, 2 — вдали
## Внутри основания башни и у входа ничего не растёт
## Высота дерева на склоне: на крутом не растёт (-INF), на пологом опускается так, чтобы основание
## с корнями не висело над склоном, а уходило в землю нижним краем
func _tree_y(pos: Vector3, h: float) -> float:
	if WorldGen.normal_y_at(pos.x, pos.z) < TREE_MAX_SLOPE:
		return -INF
	var r := h * TREE_BASE_R
	var low := WorldGen.ground_at(pos.x, pos.z)
	for k in 8:
		var a := TAU * k / 8.0
		low = minf(low, WorldGen.ground_at(pos.x + cos(a) * r, pos.z + sin(a) * r))
	return minf(pos.y, low)

func _near_tower(p: Vector3) -> bool:   # и не внутри увеличенного города
	return Vector2(p.x - TOWER_POS.x, p.z - TOWER_POS.y).length() < TOWER_R + 6.0 \
		or WorldGen.town_dist(p.x, p.z) < WorldGen.TOWN_WALL + 3.0

func _tree_path(name: String, lod: int) -> String:
	return "res://models/tree_%s%s.glb" % [name, ["", "_near", "_mid", "_far"][lod]]

func _build_tree_models(placed: Dictionary, body: StaticBody3D = null) -> void:
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
				for lod in 4:
					var path := _tree_path(nm, lod)
					lods.append(_model_mesh(path) if ResourceLoader.exists(path) else (lods[-1] if lod > 0 else _model_mesh(_tree_path(nm, 0))))
				meshes[nm] = lods
	# Участки: [x, z, модель] → [Transform3D, цвет]
	var chunks := {}
	var full_chunks := {}   # полная модель — мелкие участки
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
			# Ствол не проходится насквозь: столкновение по настоящему стволу этой модели
			if body:
				var tk: Vector3 = _trunk_of(nm, meshes[nm])
				var c3: Vector3 = Transform3D(Basis(Vector3.UP, it[1]).scaled(Vector3.ONE * k), Vector3(pos.x, y, pos.z)) * Vector3(tk.x, box.position.y, tk.z)
				_tree_collider(body, Vector3(c3.x, pos.y, c3.z), maxf(0.3, tk.y * k), it[2] * 0.6)
			var v := rng.randf_range(0.82, 1.08)   # деревья чуть разные по цвету
			var item := [tr, Color(v, v * rng.randf_range(0.96, 1.04), v)]
			var key := [floori(pos.x / TREE_CHUNK), floori(pos.z / TREE_CHUNK), nm]
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(item)
			var fkey := [floori(pos.x / TREE_FULL_CHUNK), floori(pos.z / TREE_FULL_CHUNK), nm]
			if not full_chunks.has(fkey):
				full_chunks[fkey] = []
			full_chunks[fkey].append(item)
	for key in full_chunks:
		_tree_multimesh(meshes, key[2], full_chunks[key], 0)
	for key in chunks:
		var list: Array = chunks[key]
		for lod in range(1, 4):
			_tree_multimesh(meshes, key[2], list, lod)

## Одна ступень детализации деревьев одного вида на участке: MultiMesh с дальностью видимости
func _tree_multimesh(meshes: Dictionary, nm: String, list: Array, lod: int) -> void:
	var md: Dictionary = meshes[nm][lod]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = md["mesh"]
	mm.instance_count = list.size()
	for i in list.size():
		# Дальняя модель — та же посадка, своё смещение внутри файла
		var t0: Transform3D = list[i][0]
		if lod > 0:
			t0 = t0 * (meshes[nm][0]["local"] as Transform3D).affine_inverse() * (md["local"] as Transform3D)
		mm.set_instance_transform(i, t0)
		mm.set_instance_color(i, list[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _tree_material(md["mesh"])
	match lod:
		0:
			mmi.visibility_range_end = TREE_FULL
		1:
			mmi.visibility_range_begin = TREE_FULL
			mmi.visibility_range_end = TREE_NEAR
		2:
			mmi.visibility_range_begin = TREE_NEAR
			mmi.visibility_range_end = TREE_MID
		3:
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
const ROCK_CHUNK := 50.0        # камни собраны по участкам — далёкие участки не рисуются
const ROCK_NEAR := 50.0         # ближе — подробная версия (~40 тыс. треугольников)
const ROCK_MID := 130.0         # до сюда — средняя (~6 тыс.), дальше — простая (~1 тыс.)
const ROCK_VIEW := 200.0
const WATER_SHADER := "res://shaders/water/water_lake.gdshader"   # глубина у берега — из карты высот рельефа

func build() -> void:
	_build_terrain()
	_build_water()
	_build_vegetation()
	_build_rocks()
	_build_campfire()
	# Входов в склеп и пещеру больше нет — подземелья только в башне
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
	var mat := Mats.terrain()
	# Рельеф рисует Terrain3D (addons/terrain_3d), если плагин загружен; иначе — своя сетка
	# Terrain3D 1.1.0 падает в режиме Vulkan — там пока своя сетка рельефа
	var t3d_ok := RenderingServer.get_current_rendering_method() == "gl_compatibility" or OS.get_environment("T3D_FORCE") != ""
	if ClassDB.class_exists("Terrain3D") and t3d_ok and OS.get_environment("NO_T3D") == "":
		_build_terrain3d()
	for cj in range(0, seg, CHUNK):
		if terrain3d != null:
			break
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
					# Гладкая нормаль по соседним высотам
					var hl := h[gj * n + maxi(gi - 1, 0)]
					var hr := h[gj * n + mini(gi + 1, seg)]
					var hd := h[maxi(gj - 1, 0) * n + gi]
					var hu := h[mini(gj + 1, seg) * n + gi]
					norms[j * w + i] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
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

## Рельеф на Terrain3D: карта высот мира (в 2 раза подробнее, сглажена), текстуры — трава,
## земля, песок, камень гор; на лугах склоны сами становятся камнем (автошейдер).
## Столкновения остаются свои (HeightMapShape3D) — ходьба та же, что и раньше.
const T3D_UP := 2              # во сколько раз подробнее исходной сетки
const T3D_TEX := ["grass", "dirt", "sand", "rock"]
const T3D_UV := [0.31, 0.25, 0.22, 0.07]   # повторов текстуры на метр
var terrain3d: Node3D

func _build_terrain3d() -> void:
	var t: Node3D = ClassDB.instantiate("Terrain3D")
	t.name = "Terrain3D"
	t.set("free_editor_textures", false)
	t.set("region_size", 1024)
	t.set("vertex_spacing", WorldGen.step / T3D_UP)
	add_child(t)
	var col = t.get("collision")
	if col != null:
		col.set("mode", 0)   # DISABLED — столкновения свои
	var mat = t.get("material")
	mat.set("world_background", 0)
	mat.set("auto_shader_enabled", true)
	mat.set("max_regions", 64)
	mat.call("set_shader_param", "auto_slope", 1.6)
	mat.call("set_shader_param", "auto_height_reduction", 0.0)
	mat.call("set_shader_param", "auto_base_texture", 3)   # склон — камень
	mat.call("set_shader_param", "auto_overlay_texture", 0) # ровное — трава (вес наложения = ровность)
	mat.call("set_shader_param", "blend_sharpness", 0.9)
	var assets = t.get("assets")
	for i in T3D_TEX.size():
		var ta = ClassDB.instantiate("Terrain3DTextureAsset")
		ta.set("name", T3D_TEX[i])
		ta.set("albedo_texture", load("res://textures/t3d/%s_albedo_height.png" % T3D_TEX[i]))
		ta.set("normal_texture", load("res://textures/t3d/%s_normal_rough.png" % T3D_TEX[i]))
		ta.set("uv_scale", T3D_UV[i])
		if T3D_TEX[i] == "grass":
			ta.set("albedo_color", Color(0.52, 0.58, 0.42))   # луг естественнее, без «кислотной» зелени
		ta.set("detiling_rotation", 0.3)
		ta.set("detiling_shift", 0.3)
		assets.call("set_texture_asset", i, ta)
	# Карты высот и текстур (контроль) — из данных мира
	var n := WorldGen.seg + 1
	var hi := Image.create_from_data(n, n, false, Image.FORMAT_RF, WorldGen.heights.to_byte_array())
	var m := (n - 1) * T3D_UP + 1
	hi.resize(m, m, Image.INTERPOLATE_CUBIC)
	var ctrl := PackedByteArray()
	ctrl.resize(n * n * 4)
	var c := WorldGen.colors
	for k in n * n:
		var r := c[k * 3]
		var g := c[k * 3 + 1]
		var b := c[k * 3 + 2]
		var h := WorldGen.heights[k]
		var base := 1      # земля
		var auto := 0
		if g - maxi(r, b) > 8:
			base = 0       # луг; крутые склоны — камень (автошейдер)
			auto = 1
		elif r > 158:
			base = 2       # песок у воды
		elif h > 16.0 or (absi(r - g) < 10 and absi(g - b) < 10):
			base = 3       # камень гор
		ctrl.encode_u32(k * 4, (base & 0x1F) << 27 | auto)
	var ci := Image.create_from_data(n, n, false, Image.FORMAT_RF, ctrl)
	ci.resize(m, m, Image.INTERPOLATE_NEAREST)
	t.get("data").call("import_images", [hi, ci, null], Vector3(-WorldGen.HALF, 0, -WorldGen.HALF), 0.0, 1.0)
	terrain3d = t

## Вода — мобильный шейдер воды с бликами и волнами (shaders/water)
func _build_water() -> void:
	var m := ShaderMaterial.new()
	m.shader = load(WATER_SHADER)
	m.set_shader_parameter("normal_tex", load("res://textures/water_normal.png"))
	# Карта высот рельефа — по ней вода знает глубину: у берега светлее, прозрачнее, с пеной
	var n := WorldGen.seg + 1
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, WorldGen.heights.to_byte_array())
	m.set_shader_parameter("height_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("height_rect", Vector4(-WorldGen.HALF, -WorldGen.HALF, WorldGen.WORLD, WorldGen.WORLD))
	m.set_shader_parameter("use_height", true)
	m.set_shader_parameter("water_y", WorldGen.WATER)
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
	var cand := []   # [вид, позиция, поворот, высота, радиус ствола]
	for t in p["pines"]:
		var pos := Vector3(t[0], t[2], t[1])
		var h: float = PINE_HEIGHT * t[3] * TREE_SCALE
		pos.y = _tree_y(pos, h)
		if not _near_tower(pos) and pos.y > -INF:
			cand.append(["pine", pos, t[4], h, 0.3 * t[3] * TREE_SCALE])
	for t in p["oaks"]:
		var pos := Vector3(t[0], t[2], t[1])
		var h: float = OAK_HEIGHT * t[3] * TREE_SCALE
		pos.y = _tree_y(pos, h)
		if not _near_tower(pos) and pos.y > -INF:
			cand.append(["oak", pos, t[4], h, 0.33 * t[3] * TREE_SCALE])
	# Деревья, стоящие слишком близко друг к другу (кроны сливаются), — из пары остаётся одно, большее
	cand.sort_custom(func(a, b): return a[3] > b[3])
	var grid := {}   # участок 10 м → оставленные деревья [позиция, высота]
	for c in cand:
		var pos: Vector3 = c[1]
		var h: float = c[3]
		var gx := floori(pos.x / 10.0)
		var gz := floori(pos.z / 10.0)
		var close := false
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for o in grid.get(Vector2i(gx + dx, gz + dz), []):
					var lim: float = TREE_MIN_GAP * (h + float(o[1])) / 2.0
					if Vector2(pos.x - o[0].x, pos.z - o[0].z).length_squared() < lim * lim:
						close = true
		if close:
			continue
		var key := Vector2i(gx, gz)
		if not grid.has(key):
			grid[key] = []
		grid[key].append([pos, h])
		placed[c[0]].append([pos, c[2], h])
	_build_tree_models(placed, body)
	# Трава
	var tufts := []
	for t in p["tufts"]:
		if _near_tower(Vector3(t[0], 0, t[1])):
			continue
		var s: float = t[3]
		tufts.append([Vector3(t[0], t[2] - 0.05, t[1]), t[4], Vector3(s, s, s) * 1.15, WorldGen.hex(int(t[5]))])
	var grass := ShaderMaterial.new()
	grass.shader = load("res://shaders/grass.gdshader")
	_multimesh(_grass_mesh(), grass, tufts, false)
	_build_grass_field()

## Густая трава вокруг героя (shaders/grass_field.gdshader): сетка пучков ходит за камерой,
## растёт только на лугах — не на камне, песке, дорогах, в городе, у башни и в воде
const GRASS_SPACING := 0.45
const GRASS_RADIUS := 17.0

func _build_grass_field() -> void:
	var n := WorldGen.seg + 1
	var hi := Image.create_from_data(n, n, false, Image.FORMAT_RF, WorldGen.heights.to_byte_array())
	var mask := Image.create(n, n, false, Image.FORMAT_L8)
	var c := WorldGen.colors
	for j in n:
		for i in n:
			var k := j * n + i
			var x := -WorldGen.HALF + i * WorldGen.step
			var z := -WorldGen.HALF + j * WorldGen.step
			var r := c[k * 3]
			var g := c[k * 3 + 1]
			var b := c[k * 3 + 2]
			var h := WorldGen.heights[k]
			var ok := g - maxi(r, b) > 8 and h > WorldGen.WATER + 0.4 and WorldGen.normal_y_at(x, z) > 0.8 \
				and WorldGen.town_dist(x, z) > WorldGen.TOWN_WALL + 2.0 and not _near_tower(Vector3(x, 0, z))
			mask.set_pixel(i, j, Color(1, 1, 1) if ok else Color(0, 0, 0))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass_field.gdshader")
	m.set_shader_parameter("height_tex", ImageTexture.create_from_image(hi))
	m.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask))
	m.set_shader_parameter("height_rect", Vector4(-WorldGen.HALF, -WorldGen.HALF, WorldGen.WORLD, WorldGen.WORLD))
	m.set_shader_parameter("spacing", GRASS_SPACING)
	m.set_shader_parameter("radius", GRASS_RADIUS)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blade_clump()
	var cells := []
	var half := int(GRASS_RADIUS / GRASS_SPACING)
	for gz in range(-half, half + 1):
		for gx in range(-half, half + 1):
			if Vector2(gx, gz).length() * GRASS_SPACING <= GRASS_RADIUS:
				cells.append(Vector3(gx * GRASS_SPACING, 0, gz * GRASS_SPACING))
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cells[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassField"
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-WorldGen.HALF, -50, -WorldGen.HALF), Vector3(WorldGen.WORLD, 200, WorldGen.WORLD))
	add_child(mmi)

## Пучок из шести тонких травинок: каждая — три сужающихся отрезка с изгибом наружу
func _blade_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for k in 6:
		var a := TAU * k / 6.0 + r.randf() * 0.8
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var h := 0.38 + r.randf() * 0.32
		var w := 0.03 + r.randf() * 0.015
		var lean := 0.12 + r.randf() * 0.18
		var base := dir * r.randf_range(0.02, 0.12)
		var pts := []
		for sgm in 4:
			var t := sgm / 3.0
			pts.append([base + dir * lean * t * t + Vector3(0, h * t, 0), w * (1.0 - t * 0.85)])
		for sgm in 3:
			var p0: Vector3 = pts[sgm][0]
			var p1: Vector3 = pts[sgm + 1][0]
			var w0: float = pts[sgm][1]
			var w1: float = pts[sgm + 1][1]
			if sgm < 2:
				st.add_vertex(p0 - side * w0)
				st.add_vertex(p0 + side * w0)
				st.add_vertex(p1 + side * w1)
				st.add_vertex(p0 - side * w0)
				st.add_vertex(p1 + side * w1)
				st.add_vertex(p1 - side * w1)
			else:
				st.add_vertex(p0 - side * w0)
				st.add_vertex(p0 + side * w0)
				st.add_vertex(p1)
	st.generate_normals()
	return st.commit()

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
			Mats.toon(m)
			mesh.surface_set_material(i, m)
	return {"mesh": mesh, "local": t, "aabb": t * mesh.get_aabb()}

## Камни: маленькие — Outcrop, большие — Monolith и Steps по очереди. Размер как у прежних камней,
## низ чуть утоплен в землю; большие мешают пройти
func _build_rocks() -> void:
	# У каждого камня три версии: вблизи подробная, дальше — проще (tools/prepare_models.py env)
	var models := []
	for path in [ROCK_SMALL, ROCK_BIG[0], ROCK_BIG[1]]:
		var lods := [_model_mesh(path)]
		for suffix in ["_mid", "_far"]:
			var lp: String = path.replace(".glb", suffix + ".glb")
			lods.append(_model_mesh(lp) if ResourceLoader.exists(lp) else lods[-1])
		models.append(lods)
	var body := StaticBody3D.new()
	body.name = "Rocks"
	add_child(body)
	var chunks := {}   # [ключ участка, модель] → [Transform3D]
	var n_big := 0
	for r in WorldGen.props["rocks"]:
		if _near_tower(Vector3(r[0], 0, r[1])):
			continue
		var s: float = r[3]
		var kind := 0
		if s > 0.9:
			kind = 1 + n_big % 2
			n_big += 1
		var md: Dictionary = models[kind][0]
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
		var lods: Array = models[key.z]
		for lod in 3:
			var md: Dictionary = lods[lod]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = md["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				# Та же посадка, у каждой версии своё смещение внутри файла
				var t0: Transform3D = list[i]
				if lod > 0:
					t0 = t0 * (lods[0]["local"] as Transform3D).affine_inverse() * (md["local"] as Transform3D)
				mm.set_instance_transform(i, t0)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			match lod:
				0:
					mmi.visibility_range_end = ROCK_NEAR
				1:
					mmi.visibility_range_begin = ROCK_NEAR
					mmi.visibility_range_end = ROCK_MID
				2:
					mmi.visibility_range_begin = ROCK_MID
					mmi.visibility_range_end = maxf(ROCK_VIEW, ROCK_MID + 40.0)
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					_rock_nodes.append(mmi)
			add_child(mmi)

func _tree_collider(body: StaticBody3D, pos: Vector3, r: float, height := 6.0) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos + Vector3(0, height / 2.0 - 0.5, 0)
	body.add_child(cs)

## Ствол модели дерева в системе модели: (центр x, радиус, центр z) — по вершинам сетки на высоте
## 6–16 % от низа (над корнями, ниже кроны). Берётся облегчённая модель — форма та же, вершин мало.
var _trunks := {}
func _trunk_of(nm: String, lods: Array) -> Vector3:
	if _trunks.has(nm):
		return _trunks[nm]
	var box: AABB = lods[0]["aabb"]
	var md: Dictionary = lods[2]
	var t: Transform3D = md["local"]
	var lo := box.position.y + box.size.y * 0.06
	var hi := box.position.y + box.size.y * 0.16
	var pts := []
	var mesh: Mesh = md["mesh"]
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		for v in arr[Mesh.ARRAY_VERTEX]:
			var w: Vector3 = t * v
			if w.y >= lo and w.y <= hi:
				pts.append(Vector2(w.x, w.z))
	var res := Vector3(box.get_center().x, box.size.y * 0.04, box.get_center().z)
	if pts.size() >= 8:
		var xs := pts.map(func(p): return p.x)
		var zs := pts.map(func(p): return p.y)
		xs.sort()
		zs.sort()
		var c := Vector2(xs[xs.size() / 2], zs[zs.size() / 2])
		var ds := pts.map(func(p): return (p - c).length())
		ds.sort()
		# 70 % точек пояса — ствол; крайние — ветки и корни. Не толще 12 % высоты.
		res = Vector3(c.x, minf(ds[int(ds.size() * 0.7)], box.size.y * 0.12), c.y)
	_trunks[nm] = res
	print("Дерево %s: ствол r=%.2f (%.0f%% высоты)" % [nm, res.y, 100.0 * res.y / box.size.y])
	return res

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
# ---------- Башня этажей: высокая каменная башня, дверь смотрит на город
func _build_tower() -> void:
	var x := TOWER_POS.x
	var z := TOWER_POS.y
	var base := 99.0
	for a in 16:
		var ang := TAU * a / 16.0
		base = minf(base, WorldGen.ground_at(x + cos(ang) * 13.0, z + sin(ang) * 13.0))
	var g := Node3D.new()
	g.position = Vector3(x, base - 0.5, z)
	add_child(g)
	# Высота: на 15 м выше самой высокой горы
	var peak := 0.0
	for hv in WorldGen.heights:
		peak = maxf(peak, hv)
	var H: float = peak + TOWER_ABOVE_PEAKS - g.position.y
	var R := TOWER_R
	var stone := Mats.tiled(Mats.brick_texture(), 0xa8a094, 0.18)       # кладка с рельефом (карта нормалей)
	var dark_stone := Mats.tiled(Mats.brick_texture(), 0x6a645c, 0.3)
	var trim := Mats.lp(0x8a8478, 0.8)
	var gold := Mats.lp(0xe0b040, 0.35, 0.7, 0xa07010, 0.4)
	var win := Mats.glow(0xffc070)
	var roof_mat := Mats.lp(0x2e3e66, 0.6)
	var cyl := func(r0: float, r1: float, h: float, y: float, mat: Material, segs := 28) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = _cyl(r1, r0, h, segs)
		mi.material_override = mat
		mi.position.y = y + h / 2.0
		g.add_child(mi)
		return mi
	# Цоколь, тело башни (чуть сужается кверху), пояса этажей
	cyl.call(R + 2.0, R + 1.6, 2.2, 0.0, dark_stone)
	cyl.call(R + 1.2, R + 1.0, 1.0, 2.2, trim)
	var r_top := R * 0.86
	cyl.call(R, r_top, H, 0.0, stone)
	var floors := DungeonDefs.TOWER.size()
	for f in floors:
		var y := 6.0 + (H - 10.0) * float(f) / floors
		var rr := lerpf(R, r_top, y / H)
		# Пояс-карниз и балкон с зубцами через этаж
		cyl.call(rr + 0.7, rr + 0.5, 0.7, y, trim)
		if f % 2 == 1:
			cyl.call(rr + 1.6, rr + 1.6, 0.35, y + 0.7, dark_stone)
			for k in 16:
				var a := TAU * k / 16.0
				var tooth := _box(g, Vector3(0.6, 0.9, 0.3), dark_stone, Vector3(cos(a) * (rr + 1.45), y + 1.5, sin(a) * (rr + 1.45)))
				tooth.rotation.y = -a + PI / 2.0
		# Арочные окна: светятся тёплым светом
		for k in 6:
			var a := TAU * k / 6.0 + f * 0.5
			var wy := y + 3.0
			var wr := lerpf(R, r_top, wy / H) + 0.03
			var w := _box(g, Vector3(1.0, 2.2, 0.12), win, Vector3(sin(a) * wr, wy, cos(a) * wr))
			w.rotation.y = a
			var arch := MeshInstance3D.new()
			arch.mesh = _cyl(0.5, 0.5, 0.12, 10)
			arch.material_override = win
			arch.rotation = Vector3(PI / 2.0, a, 0)
			arch.position = Vector3(sin(a) * wr, wy + 1.1, cos(a) * wr)
			g.add_child(arch)
			var frame := _box(g, Vector3(1.4, 0.25, 0.3), trim, Vector3(sin(a) * (wr + 0.1), wy - 1.2, cos(a) * (wr + 0.1)))
			frame.rotation.y = a
	# Контрфорсы у основания
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		var b := _box(g, Vector3(1.6, 18.0, 3.0), dark_stone, Vector3(sin(a) * (R + 1.0), 9.0, cos(a) * (R + 1.0)))
		b.rotation.y = a
		var cap := _box(g, Vector3(1.6, 1.0, 1.6), trim, Vector3(sin(a) * (R + 0.6), 18.5, cos(a) * (R + 0.6)))
		cap.rotation.y = a
	# Венец: широкая площадка с зубцами, шатровая крыша со шпилем и маяком
	cyl.call(r_top + 2.2, r_top + 0.4, 2.5, H, dark_stone)
	cyl.call(r_top + 2.2, r_top + 2.2, 0.6, H + 2.5, trim)
	for k in 24:
		var a := TAU * k / 24.0
		var t2 := _box(g, Vector3(1.1, 1.4, 0.6), dark_stone, Vector3(cos(a) * (r_top + 1.9), H + 3.8, sin(a) * (r_top + 1.9)))
		t2.rotation.y = -a + PI / 2.0
	var roof := MeshInstance3D.new()
	roof.mesh = _cyl(0.0, r_top * 0.95, r_top * 1.8, 24)
	roof.material_override = roof_mat
	roof.position.y = H + 3.1 + r_top * 0.9
	g.add_child(roof)
	var spire := MeshInstance3D.new()
	spire.mesh = _cyl(0.0, 0.35, 8.0, 8)
	spire.material_override = gold
	spire.position.y = H + 3.1 + r_top * 1.8 + 4.0
	g.add_child(spire)
	var orb := MeshInstance3D.new()
	orb.mesh = _blob(0.9, 12, 6)
	orb.material_override = Mats.glow(0xffe8a0)
	orb.position.y = H + 3.1 + r_top * 1.8 + 1.0
	g.add_child(orb)
	var beacon := OmniLight3D.new()
	beacon.light_color = WorldGen.hex(0xffe0a0)
	beacon.light_energy = 3.0
	beacon.omni_range = 40.0
	beacon.position = orb.position
	g.add_child(beacon)
	# Знамёна: длинные полотнища под венцом
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = WorldGen.hex(0x8a1c24)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 0.9
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2.4, 12.0)
		q.mesh = qm
		q.material_override = cloth
		var br := r_top + 0.25
		q.position = Vector3(sin(a) * br, H - 6.5, cos(a) * br)
		q.rotation.y = a
		g.add_child(q)
		var emblem := _box(g, Vector3(1.0, 1.0, 0.06), gold, Vector3(sin(a) * (br + 0.05), H - 3.5, cos(a) * (br + 0.05)))
		emblem.rotation = Vector3(0, a, PI / 4.0)
	# Дверь со стороны города (на север, к −z): арка, ступени и факелы
	var dir := Vector3(0, 0, -1)
	var door_pos := Vector3(0, 0, -R - 1.6)
	var arch_n := Node3D.new()
	arch_n.position = door_pos
	arch_n.rotation.y = PI
	g.add_child(arch_n)
	for sx in [-2.2, 2.2]:
		_box(arch_n, Vector3(1.2, 6.0, 1.8), dark_stone, Vector3(sx, 3.0 + 0.5, 0.2))
	_box(arch_n, Vector3(5.6, 1.2, 2.0), dark_stone, Vector3(0, 6.8, 0.2))
	_box(arch_n, Vector3(1.0, 1.0, 0.2), gold, Vector3(0, 6.8, 1.25)).rotation.z = PI / 4.0
	var dark := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(3.2, 5.6)
	dark.mesh = q2
	dark.material_override = Mats.glow(0x000000)
	dark.position = Vector3(0, 3.3, 1.0)
	arch_n.add_child(dark)
	for i in 4:
		_box(arch_n, Vector3(4.6, 0.3, 0.8), dark_stone, Vector3(0, 0.55 - i * 0.2, 1.4 + i * 0.7))
	for sx in [-3.2, 3.2]:
		var post := MeshInstance3D.new()
		post.mesh = _cyl(0.1, 0.13, 2.4, 6)
		post.material_override = Mats.lp(0x4a3220)
		post.position = Vector3(sx, 1.7, 1.6)
		arch_n.add_child(post)
		var fl := MeshInstance3D.new()
		fl.mesh = _cyl(0.0, 0.2, 0.55, 6)
		fl.material_override = Mats.glow(0xffb040)
		fl.position = Vector3(sx, 3.2, 1.6)
		arch_n.add_child(fl)
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xff9a3c)
	light.light_energy = 1.8
	light.omni_range = 12.0
	light.position = Vector3(0, 4.0, 3.0)
	arch_n.add_child(light)
	var sb := StaticBody3D.new()
	add_child(sb)
	var sh := CylinderShape3D.new()
	sh.radius = R + 1.0
	sh.height = H
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = g.position + Vector3(0, H / 2.0, 0)
	sb.add_child(cs)
	var door := g.position + door_pos + dir * 1.6
	tower = {"door": Vector3(door.x, WorldGen.ground_at(door.x, door.z), door.z), "dir": dir, "pos": g.position, "height": H}

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Мир на поверхности: рельеф, вода, растительность, костёр, входы в подземелья и город.
extends Node3D

const CHUNK := 60  # клеток рельефа в одном куске — куски вне экрана не рисуются

var entrances: Array = []   # [{name, door: Vector3, dir: Vector3}]
var town_map: Array = []    # прямоугольники построек для миникарты
var campfire: Node3D
var _fire_light: OmniLight3D
var _fire_flame: MeshInstance3D
var _time := 0.0

func build() -> void:
	_build_terrain()
	_build_water()
	_build_vegetation()
	_build_campfire()
	_build_entrances()
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

func _build_water() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(WorldGen.hex(0x2f7fae), 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic = 0.1
	var plane := PlaneMesh.new()
	plane.size = Vector2(WorldGen.WORLD * 1.6, WorldGen.WORLD * 1.6)
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
	var white := Mats.lp(0xffffff)
	var trunk_c := WorldGen.hex(0x6b4a2b)
	var trunk := _cyl(0.22, 0.32, 1.0, 6)
	var body := StaticBody3D.new()
	body.name = "Props"
	add_child(body)
	var trunks := []
	var cones := [[], [], []]
	var crowns := [[], []]
	# Ели: ствол и три яруса конусов
	var layers := [[1.6, 1.0], [3.0, 0.78], [4.3, 0.55]]
	for t in p["pines"]:
		var pos := Vector3(t[0], t[2], t[1])
		var s: float = t[3]
		var rot: float = t[4]
		trunks.append([pos + Vector3(0, -0.2 + 1.2 * s, 0), rot, Vector3(s, s * 2.4, s), trunk_c])
		for l in 3:
			var ls: float = layers[l][1] * s
			cones[l].append([pos + Vector3(0, layers[l][0] * s + 1.6 * ls, 0), rot, Vector3(ls, ls, ls), WorldGen.hex(int(t[5 + l]))])
		_tree_collider(body, pos, 0.45 * s)
	# Лиственные: ствол и две кроны
	for t in p["oaks"]:
		var pos := Vector3(t[0], t[2], t[1])
		var s: float = t[3]
		var rot: float = t[4]
		trunks.append([pos + Vector3(0, -0.2 + 1.3 * s, 0), rot, Vector3(s * 1.1, s * 2.6, s * 1.1), trunk_c])
		crowns[0].append([pos + Vector3(0, 3.4 * s, 0), rot, Vector3(s * 1.15, s, s * 1.15), WorldGen.hex(int(t[5]))])
		crowns[1].append([pos + Vector3(0.6 * s, 4.3 * s, -0.3 * s), rot, Vector3(0.7 * s, 0.7 * s, 0.7 * s), WorldGen.hex(int(t[6]))])
		_tree_collider(body, pos, 0.45 * s)
	_multimesh(trunk, white, trunks)
	var cone := _cyl(0.0, 1.7, 3.2, 7)
	for l in 3:
		_multimesh(cone, white, cones[l])
	var crown := _blob(1.9)
	for k in 2:
		_multimesh(crown, white, crowns[k])
	# Камни: большие мешают пройти
	var rocks := []
	for r in p["rocks"]:
		var s: float = r[3]
		var pos := Vector3(r[0], r[2] + s * 0.3, r[1])
		rocks.append([pos, r[4], Vector3(s * 1.2, s * 0.8, s), WorldGen.hex(int(r[5]))])
		if s > 0.9:
			_tree_collider(body, pos, s * 0.95)
	_multimesh(_blob(1.0, 5, 2), white, rocks)
	# Трава
	var tufts := []
	for t in p["tufts"]:
		var s: float = t[3]
		tufts.append([Vector3(t[0], t[2] + 0.35 * s, t[1]), t[4], Vector3(s, s, s), WorldGen.hex(int(t[5]))])
	_multimesh(_cyl(0.0, 0.25, 0.8, 3), white, tufts, false)

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

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

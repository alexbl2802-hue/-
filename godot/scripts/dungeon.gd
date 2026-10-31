## Подземелье по карте из DungeonDefs: пол, своды, стены, колонны, факелы,
## кристаллы (в пещере), кости, выход и сундук. Лежит глубоко под миром.
extends Node3D

const CELL := DungeonDefs.CELL
const WALL_H := DungeonDefs.WALL_H
const BLOCK := 4  # клеток в блоке: пол/своды/стены собираются блоками, чтобы свет факелов ложился правильно

var def: Dictionary
var index := 0
var map: Array
var rows := 0
var cols := 0
var Y := 0.0
var cave := false
var pad := 0.0
var start_pos := Vector3.ZERO
var start_yaw := 0.0
var spawns: Array = []          # [[тип, позиция]]
var chest := {}
var _flickers: Array = []
var _exit_ring: MeshInstance3D
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _time := 0.0

func build(d: Dictionary, idx: int) -> void:
	def = d
	index = idx
	map = d["map"]
	rows = map.size()
	cols = (map[0] as String).length()
	Y = d["y"]
	cave = d["style"] == "cave"
	pad = 0.55 if cave else 0.0
	_rng.seed = 77 + idx
	name = "Dungeon%d" % idx
	_body = StaticBody3D.new()
	add_child(_body)
	var floors := []
	var walls := []
	var torches := []
	var crystals := []
	var pillars := []
	for j in rows:
		for i in cols:
			var c := ch(i, j)
			if c == "#":
				var edge := false
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						if not solid(i + di, j + dj):
							edge = true
				if edge:
					walls.append(Vector2i(i, j))
				continue
			floors.append(Vector2i(i, j))
			match c:
				"S":
					start_pos = cell_center(i, j)
					for dv in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
						if not solid(i + dv.x, j + dv.y):
							start_yaw = atan2(dv.x, dv.y)
							break
				"C": _build_chest(cell_center(i, j))
				"T": torches.append(Vector2i(i, j))
				"P": pillars.append(Vector2i(i, j))
				"K": crystals.append(Vector2i(i, j))
				"E": spawns.append([d["monster"], cell_center(i, j)])
				"O": spawns.append(["kobold", cell_center(i, j)])
	_build_shell(floors, walls)
	for p in pillars:
		_build_pillar(cell_center(p.x, p.y))
	for t in torches:
		_build_torch(t)
	if cave:
		_build_crystals(floors, crystals)
	_build_decor(floors)
	_build_exit()

func ch(i: int, j: int) -> String:
	if i < 0 or j < 0 or i >= cols or j >= rows:
		return "#"
	return (map[j] as String)[i]

func solid(i: int, j: int) -> bool:
	return ch(i, j) == "#"

func cell_center(i: int, j: int) -> Vector3:
	return Vector3((i - cols / 2.0 + 0.5) * CELL, Y, (j - rows / 2.0 + 0.5) * CELL)

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL + cols / 2.0 - 0.5), roundi(p.z / CELL + rows / 2.0 - 0.5))

# ---------- Пол, своды, стены
func _texture(kind: String) -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	if kind == "tile":
		img.fill(Color8(34, 32, 29))
		for a in 2:
			for b in 2:
				img.fill_rect(Rect2i(a * s / 2 + 3, b * s / 2 + 3, s / 2 - 6, s / 2 - 6), Color.from_hsv(35.0 / 360.0, 0.12, 0.4 + r.randf() * 0.16))
	else:
		img.fill(Color8(138, 132, 150))
	for k in 1500:
		var x := r.randi() % s
		var y := r.randi() % s
		var v := r.randf()
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(v, v, v), 0.2))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_shell(floors: Array, walls: Array) -> void:
	var floor_tex := _texture("rock" if cave else "tile")
	var floor_mat := Mats.tiled(floor_tex, 0x9a92a6 if cave else 0xbbb2a6, 0.25)
	var ceil_mat := Mats.tiled(_texture("rock") if cave else Mats.brick_texture(), 0x4a4450 if cave else 0x6a625a, 0.25)
	var wall_mat: Material
	if cave:
		wall_mat = Mats.lp(0xffffff, 1.0)
	else:
		wall_mat = Mats.tiled(Mats.brick_texture(), 0xb0a698, 0.25)
	var plane := PlaneMesh.new()
	plane.size = Vector2(CELL, CELL)
	var ceil_h := WALL_H + (0.6 if cave else 0.0)
	# Раскладываем клетки по блокам
	var fb := {}
	for f in floors:
		var key := Vector2i(f.x / BLOCK, f.y / BLOCK)
		if not fb.has(key):
			fb[key] = []
		fb[key].append(f)
	for key in fb:
		var cells: Array = fb[key]
		var mm := _mm(plane, cells.size(), false)
		var mc := _mm(plane, cells.size(), false)
		for k in cells.size():
			var c := cell_center(cells[k].x, cells[k].y)
			mm.set_instance_transform(k, Transform3D(Basis(), Vector3(c.x, Y, c.z)))
			mc.set_instance_transform(k, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(c.x, Y + ceil_h, c.z)))
		_mmi(mm, floor_mat, false)
		_mmi(mc, ceil_mat, false)
	var wb := {}
	for w in walls:
		var key := Vector2i(w.x / BLOCK, w.y / BLOCK)
		if not wb.has(key):
			wb[key] = []
		wb[key].append(w)
	var wall_mesh: Mesh
	if cave:
		var sp := SphereMesh.new()
		sp.radius = CELL * 0.66
		sp.height = CELL * 1.32
		sp.radial_segments = 7
		sp.rings = 4
		wall_mesh = sp
	else:
		var bx := BoxMesh.new()
		bx.size = Vector3(CELL, WALL_H, CELL)
		wall_mesh = bx
	for key in wb:
		var cells: Array = wb[key]
		var mm := _mm(wall_mesh, cells.size() * (2 if cave else 1), cave)
		for k in cells.size():
			var c := cell_center(cells[k].x, cells[k].y)
			if cave:
				for layer in 2:
					var b := Basis.from_euler(Vector3(_rng.randf() * 6, _rng.randf() * 6, _rng.randf() * 6))
					b = b * Basis.from_scale(Vector3(1 + _rng.randf() * 0.15, 1 + _rng.randf() * 0.3, 1 + _rng.randf() * 0.15))
					var p := Vector3(c.x + (_rng.randf() - 0.5) * 0.5, Y + 1.2 + layer * 2.8, c.z + (_rng.randf() - 0.5) * 0.5)
					mm.set_instance_transform(k * 2 + layer, Transform3D(b, p))
					mm.set_instance_color(k * 2 + layer, Color.from_hsv(_rng.randf_range(0.72, 0.8), 0.1, _rng.randf_range(0.55, 0.7)))
			else:
				mm.set_instance_transform(k, Transform3D(Basis(), Vector3(c.x, Y + WALL_H / 2.0, c.z)))
		_mmi(mm, wall_mat, true)
	# Столкновения: стены, пол, свод
	var half := CELL / 2.0 + pad
	for w in walls:
		var c := cell_center(w.x, w.y)
		_col_box(Vector3(c.x, Y + WALL_H / 2.0, c.z), Vector3(half * 2, WALL_H + 2.0, half * 2))
	var size := Vector3(cols * CELL, 1.0, rows * CELL)
	_col_box(Vector3(0, Y - 0.5, 0), size)
	_col_box(Vector3(0, Y + ceil_h + 0.5, 0), size)

func _mm(mesh: Mesh, n: int, colors: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = n
	return mm

func _mmi(mm: MultiMesh, mat: Material, shadow: bool) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _col_box(center: Vector3, size: Vector3) -> void:
	var sh := BoxShape3D.new()
	sh.size = size
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = center
	_body.add_child(cs)

func _col_cyl(center: Vector3, r: float, h: float) -> void:
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = center + Vector3(0, h / 2.0, 0)
	_body.add_child(cs)

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box(size: Vector3, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi

func _cyl(top: float, bottom: float, h: float, segs: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 0
	return m

# ---------- Колонны, факелы
func _build_pillar(c: Vector3) -> void:
	_mesh(_cyl(0.6, 0.7, WALL_H, 8), Mats.tiled(Mats.brick_texture(), 0xc8beb0, 0.25), Vector3(c.x, Y + WALL_H / 2.0, c.z), true)
	for yy in [0.2, WALL_H - 0.2]:
		_box(Vector3(1.7, 0.4, 1.7), Mats.lp(0x8a8276), Vector3(c.x, Y + yy, c.z))
	_col_cyl(Vector3(c.x, Y, c.z), 0.8, WALL_H)

func _build_torch(t: Vector2i) -> void:
	var c := cell_center(t.x, t.y)
	var d := Vector2i.ZERO
	for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if solid(t.x + dv.x, t.y + dv.y):
			d = dv
			break
	var off := CELL / 2.0 - 0.25 + pad * 0.6
	var wx := c.x + d.x * off
	var wz := c.z + d.y * off
	var stick := _mesh(_cyl(0.06, 0.08, 0.7, 5), Mats.lp(0x4a3220), Vector3(wx, Y + 2.5, wz))
	stick.rotation = Vector3(d.y * 0.4, 0, -d.x * 0.4)
	var fl := _mesh(_cyl(0.0, 0.15, 0.4, 5), Mats.glow(0xffb040), Vector3(wx - d.x * 0.15, Y + 3.0, wz - d.y * 0.15))
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xff8a30)
	light.light_energy = 2.2
	light.omni_range = 15.0
	light.omni_attenuation = 1.3
	light.position = Vector3(wx - d.x * 0.8, Y + 3.0, wz - d.y * 0.8)
	add_child(light)
	_flickers.append({"light": light, "flame": fl, "base": 2.2, "seed": _rng.randf() * 100.0, "slow": false})

# ---------- Кристаллы: растут на стенах и потолке пещеры и мягко светятся
func _build_crystals(floors: Array, k_cells: Array) -> void:
	var faces := []
	for f in floors:
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if solid(f.x + dv.x, f.y + dv.y):
				faces.append({"i": f.x, "j": f.y, "a": dv.x, "b": dv.y})
	var clusters := []
	# Клетки K — крупные светящиеся кластеры на ближайшей стене
	for kc in k_cells:
		var best = null
		var bd := 1e9
		for f in faces:
			var dd := Vector2(f["i"] - kc.x, f["j"] - kc.y).length()
			if dd < bd:
				bd = dd
				best = f
		if best != null:
			var cl: Dictionary = best.duplicate()
			cl["lit"] = true
			cl["big"] = true
			clusters.append(cl)
	for f in faces:
		if _rng.randf() < 0.3:
			var cl: Dictionary = f.duplicate()
			cl["lit"] = false
			clusters.append(cl)
	for f in floors:
		if _rng.randf() < 0.12:
			clusters.append({"i": f.x, "j": f.y, "a": 0, "b": 0, "ceil": true, "lit": false})
	var n := 0
	for cl in clusters:
		if not cl["lit"] and not cl.get("ceil", false):
			if n % 4 == 0:
				cl["lit"] = true
			n += 1
	var hues := [0.52, 0.8]
	var cone := _cyl(0.0, 1.0, 1.0, 5)
	var parts := [[], []]
	var lights := 0
	for cl in clusters:
		var hi := 0 if _rng.randf() < 0.6 else 1
		var c := cell_center(cl["i"], cl["j"])
		var bx: float
		var by: float
		var bz: float
		if cl.get("ceil", false):
			bx = c.x + (_rng.randf() - 0.5) * 2.5
			bz = c.z + (_rng.randf() - 0.5) * 2.5
			by = Y + WALL_H + 0.4
		else:
			var along := (_rng.randf() - 0.5) * 2.4
			bx = c.x + cl["a"] * (CELL / 2.0 - 0.3) + (along if cl["b"] != 0 else 0.0)
			bz = c.z + cl["b"] * (CELL / 2.0 - 0.3) + (along if cl["a"] != 0 else 0.0)
			by = Y + (1.2 + _rng.randf() * 1.2 if cl.get("big", false) else 0.3 + _rng.randf() * 3.3)
		var count := 7 if cl.get("big", false) else 3 + _rng.randi() % 3
		for k in count:
			var dir: Vector3
			if cl.get("ceil", false):
				dir = Vector3((_rng.randf() - 0.5) * 0.8, -1, (_rng.randf() - 0.5) * 0.8)
			else:
				dir = Vector3(-cl["a"] * (0.5 + _rng.randf() * 0.6) + (_rng.randf() - 0.5) * 0.7, 0.4 + _rng.randf() * 0.9, -cl["b"] * (0.5 + _rng.randf() * 0.6) + (_rng.randf() - 0.5) * 0.7)
			dir = dir.normalized()
			var h := (0.8 if cl.get("big", false) else 0.4) + _rng.randf() * (1.2 if cl.get("big", false) else 0.7)
			var w := h * (0.16 + _rng.randf() * 0.08)
			var basis := _basis_up_to(dir) * Basis.from_scale(Vector3(w, h, w))
			var p := Vector3(bx + (_rng.randf() - 0.5) * 0.3, by + (_rng.randf() - 0.5) * 0.4, bz + (_rng.randf() - 0.5) * 0.3)
			parts[hi].append(Transform3D(basis, p + dir * h * 0.5))
		if cl["lit"] and lights < 12:
			lights += 1
			var light := OmniLight3D.new()
			light.light_color = Color.from_hsv(hues[hi], 0.5, 1.0)
			var e := 1.1 if cl.get("big", false) else 0.7
			light.light_energy = e
			light.omni_range = 11.0
			light.omni_attenuation = 1.5
			light.position = Vector3(bx - cl["a"] * 0.8, by + 0.5, bz - cl["b"] * 0.8)
			add_child(light)
			_flickers.append({"light": light, "base": e, "seed": _rng.randf() * 100.0, "slow": true})
	for hi in 2:
		var m := Mats.lp(Color.from_hsv(hues[hi], 0.55, 0.95).to_rgba32() >> 8, 0.25, 0.0, Color.from_hsv(hues[hi], 0.85, 0.7).to_rgba32() >> 8, 1.1)
		var mm := _mm(cone, parts[hi].size(), false)
		for k in parts[hi].size():
			mm.set_instance_transform(k, parts[hi][k])
		_mmi(mm, m, false)

func _basis_up_to(dir: Vector3) -> Basis:
	var up := Vector3.UP
	var axis := up.cross(dir)
	if axis.length() < 1e-4:
		return Basis() if dir.y > 0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), up.angle_to(dir))

# ---------- Кости в склепе, сталактиты в пещере
func _build_decor(floors: Array) -> void:
	for f in floors:
		var c := cell_center(f.x, f.y)
		var t := ch(f.x, f.y)
		if t == "B":
			var skull := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22; sm.height = 0.44; sm.radial_segments = 6; sm.rings = 4
			skull.mesh = sm
			skull.material_override = Mats.lp(0xe8e0c8)
			skull.position = Vector3(c.x + 0.4, Y + 0.2, c.z)
			add_child(skull)
			for k in 5:
				var b := _mesh(_cyl(0.05, 0.05, 0.7, 4), Mats.lp(0xddd4bb), Vector3(c.x + (_rng.randf() - 0.5) * 1.5, Y + 0.06, c.z + (_rng.randf() - 0.5) * 1.5))
				b.rotation = Vector3(PI / 2, _rng.randf() * 6, 0)
		if cave and t == "." and _rng.randf() < 0.25:
			var h := 0.5 + _rng.randf() * 1.2
			var st := _mesh(_cyl(0.0, 0.18 + _rng.randf() * 0.2, h, 5), Mats.lp(0x6e6676), Vector3(c.x + (_rng.randf() - 0.5) * 3, Y + WALL_H + 0.6 - h / 2.0, c.z + (_rng.randf() - 0.5) * 3))
			st.rotation.x = PI

# ---------- Выход: светящийся круг и столб света
func _build_exit() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.8
	ring.outer_radius = 1.2
	ring.rings = 24
	ring.ring_segments = 4
	_exit_ring = _mesh(ring, Mats.glow(0x7fd8ff), Vector3(start_pos.x, Y + 0.05, start_pos.z))
	_exit_ring.scale = Vector3(1, 0.06, 1)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.62, 0.9, 1.0, 0.12)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := _cyl(1.0, 1.0, WALL_H, 16)
	beam.cap_top = false
	beam.cap_bottom = false
	_mesh(beam, bm, Vector3(start_pos.x, Y + WALL_H / 2.0, start_pos.z))
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0x9fe4ff)
	light.light_energy = 1.2
	light.omni_range = 9.0
	light.position = Vector3(start_pos.x, Y + 2, start_pos.z)
	add_child(light)

# ---------- Сундук с сокровищем
func _build_chest(c: Vector3) -> void:
	var root := Node3D.new()
	root.position = c
	root.rotation.y = _rng.randf() * 0.6 - 0.3
	add_child(root)
	var wood := Mats.lp(0x7a4a22)
	var metal := Mats.lp(0xc9a74a, 0.4, 0.6)
	_box(Vector3(1.3, 0.7, 0.85), wood, Vector3(0, 0.35, 0), root)
	_box(Vector3(1.1, 0.1, 0.65), Mats.lp(0xffd34d, 0.3, 0.8, 0x6a4a00, 1.0), Vector3(0, 0.66, 0), root)
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.7, -0.42)
	root.add_child(lid)
	_box(Vector3(1.3, 0.3, 0.85), wood, Vector3(0, 0.15, 0.42), lid)
	for x in [-0.45, 0.45]:
		_box(Vector3(0.1, 0.74, 0.88), metal, Vector3(x, 0.35, 0), root)
		_box(Vector3(0.1, 0.32, 0.88), metal, Vector3(x, 0.15, 0.42), lid)
	_box(Vector3(0.18, 0.22, 0.06), metal, Vector3(0, 0.62, 0.45), root)
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xffc040)
	light.light_energy = 0.0
	light.omni_range = 8.0
	light.position = c + Vector3(0, 1.5, 0)
	add_child(light)
	_col_cyl(c, 0.75, 1.0)
	chest = {"pos": c, "lid": lid, "light": light, "opened": false, "t": 0.0}

## Открытый сундук: крышка откидывается, внутри загорается золото
func open_chest(instant := false) -> void:
	chest["opened"] = true
	if instant:
		chest["t"] = 1.0
		(chest["lid"] as Node3D).rotation.x = -1.9
		(chest["light"] as OmniLight3D).light_energy = 1.5

func _process(dt: float) -> void:
	if not visible:
		return
	_time += dt
	for f in _flickers:
		var s: float
		if f["slow"]:
			s = 0.85 + 0.15 * sin(_time * 1.5 + f["seed"])
		else:
			s = 0.8 + 0.2 * sin(_time * 12.0 + f["seed"]) * sin(_time * 7.7 + f["seed"])
		f["light"].light_energy = f["base"] * s
		if f.has("flame"):
			f["flame"].scale.y = 0.8 + 0.3 * s
	_exit_ring.rotation.y = _time
	if chest.get("opened", false) and chest["t"] < 1.0:
		chest["t"] = minf(1.0, chest["t"] + dt * 1.5)
		(chest["lid"] as Node3D).rotation.x = -1.9 * (1.0 - pow(1.0 - chest["t"], 3))
		(chest["light"] as OmniLight3D).light_energy = 1.5 * chest["t"]

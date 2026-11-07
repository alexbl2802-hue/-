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
var tower := false              # этаж башни
var gate_cells: Array = []      # клетки ворот комнаты стража
var boss_pos := Vector3.ZERO    # где стоит страж этажа
var stairs_pos := Vector3.ZERO  # лестница на следующий этаж
var room := {}                  # клетки комнаты стража (Vector2i → true)
var gate_closed := false
var _gate_bars: Array = []      # [узел решётки, высота поднятой]
var _gate_shapes: Array = []
var _gate_t := 0.0              # 0 — открыты, 1 — закрыты
var _stairs_glow: Array = []
var stairs_open := false
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
	tower = d["style"] == "tower"
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
				# Монстров вдвое больше: на каждой отметке — пара, по сторонам центра клетки
				"E":
					for o in [-1.0, 1.0]:
						spawns.append([d["monster"], cell_center(i, j) + Vector3(o * CELL * 0.22, 0, -o * CELL * 0.12)])
				"O":
					for o in [-1.0, 1.0]:
						spawns.append([d.get("monster2", "kobold"), cell_center(i, j) + Vector3(o * CELL * 0.22, 0, o * CELL * 0.12)])
				"G": gate_cells.append(Vector2i(i, j))
				"B": boss_pos = cell_center(i, j)
				"U": stairs_pos = cell_center(i, j)
	# На каждом этаже башни — сундук в случайном месте: не у входа, не в комнате стража
	if tower and chest.is_empty():
		_place_random_chest(floors)
	_build_shell(floors, walls)
	for p in pillars:
		_build_pillar(cell_center(p.x, p.y))
	for t in torches:
		_build_torch(t)
	if cave:
		_build_crystals(floors, crystals)
	_build_decor(floors)
	_build_exit()
	if tower:
		_build_tower_decor(floors)
		_find_room()
		for g in gate_cells:
			_build_gate(g)
		if stairs_pos != Vector3.ZERO:
			_build_stairs(stairs_pos)

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
	var floor_tex: Texture2D = _texture("rock") if cave else Mats.tile_texture()
	var floor_mat := Mats.tiled(floor_tex, 0x9a92a6 if cave else 0xbbb2a6, 0.25)
	var ceil_mat := Mats.tiled(_texture("rock") if cave else Mats.brick_texture(), 0x4a4450 if cave else 0x6a625a, 0.25)
	var wall_mat: Material
	if cave:
		wall_mat = Mats.lp(0xffffff, 1.0)
	elif tower:
		# Этаж башни: стены и пол в цветах темы этажа
		wall_mat = Mats.tiled(Mats.brick_texture(), def["wall"], 0.25)
		floor_mat = Mats.tiled(floor_tex, Color(WorldGen.hex(def["floor"])).lightened(0.5).to_rgba32() >> 8, 0.25)
		ceil_mat = Mats.tiled(Mats.brick_texture(), Color(WorldGen.hex(def["wall"])).darkened(0.45).to_rgba32() >> 8, 0.25)
	else:
		wall_mat = Mats.tiled(Mats.brick_texture(), 0xb0a698, 0.25)
	for m in [floor_mat, ceil_mat]:
		(m as StandardMaterial3D).vertex_color_use_as_albedo = true
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
		_mi(_floor_mesh(cells, Y, false), floor_mat)
		_mi(_floor_mesh(cells, Y + ceil_h, true), ceil_mat)
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
		wall_mesh = _wall_mesh()
		(wall_mat as StandardMaterial3D).vertex_color_use_as_albedo = true
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

# ---------- Затенение углов: пол и свод темнее у стен, стены темнее у пола и под сводом
## Насколько светло в углу клетки (i, j): чем больше стен вокруг угла, тем темнее
func _corner_light(i: int, j: int) -> float:
	var n := 0
	for c in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
		if solid(c.x, c.y):
			n += 1
	return 1.0 - 0.2 * n

## Пол (или свод) блока клеток одной сеткой; яркость — в цвете вершин по углам
func _floor_mesh(cells: Array, y: float, ceiling: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.DOWN if ceiling else Vector3.UP)
	for cl in cells:
		var c := cell_center(cl.x, cl.y)
		var h := CELL / 2.0
		var pts := [Vector3(c.x - h, y, c.z - h), Vector3(c.x + h, y, c.z - h), Vector3(c.x + h, y, c.z + h), Vector3(c.x - h, y, c.z + h)]
		var lit := [_corner_light(cl.x, cl.y), _corner_light(cl.x + 1, cl.y), _corner_light(cl.x + 1, cl.y + 1), _corner_light(cl.x, cl.y + 1)]
		var order := [0, 2, 1, 0, 3, 2] if ceiling else [0, 1, 2, 0, 2, 3]
		for k in order:
			var v: float = lit[k]
			st.set_color(Color(v, v, v))
			st.add_vertex(pts[k])
	return st.commit()

## Блок стены: темнее у пола и под сводом
func _wall_mesh() -> ArrayMesh:
	var bx := BoxMesh.new()
	bx.size = Vector3(CELL, WALL_H, CELL)
	bx.subdivide_height = 6
	var st := SurfaceTool.new()
	st.create_from(bx, 0)
	var arr := st.commit_to_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for k in verts.size():
		var yy := verts[k].y + WALL_H / 2.0
		var v := lerpf(0.5, 1.0, smoothstep(0.0, 1.6, yy)) * lerpf(1.0, 0.72, smoothstep(WALL_H - 1.2, WALL_H, yy))
		cols[k] = Color(v, v, v)
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _mi(mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

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

## Факел пещеры — как был
func _build_cave_torch(t: Vector2i, d: Vector2i) -> void:
	var c := cell_center(t.x, t.y)
	var off := CELL / 2.0 - 0.25 + pad * 0.6
	var wx := c.x + d.x * off
	var wz := c.z + d.y * off
	var stick := _mesh(_cyl(0.06, 0.08, 0.7, 5), Mats.lp(0x4a3220), Vector3(wx, Y + 2.5, wz))
	stick.rotation = Vector3(d.y * 0.4, 0, -d.x * 0.4)
	var fl := _mesh(_cyl(0.0, 0.15, 0.4, 5), Mats.glow(0xffb040), Vector3(wx - d.x * 0.15, Y + 3.0, wz - d.y * 0.15))
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xff8a30)
	light.light_energy = 2.2
	light.omni_range = 18.0
	light.omni_attenuation = 1.3
	light.position = Vector3(wx - d.x * 0.8, Y + 3.0, wz - d.y * 0.8)
	add_child(light)
	torch_spots.append([Vector3(wx, Y + 3.0, wz), -Vector3(d.x, 0, d.y)])
	_flickers.append({"light": light, "flame": fl, "base": 2.2, "seed": _rng.randf() * 100.0, "slow": false})

## Факел склепа на стене: железный держатель на стене, факел наклонён от стены.
## Если в клетке рядом нет стены, в склепе факел переносится на ближайшую стену,
## а в пещере такой факел не ставится (там светят кристаллы).
var torch_spots := []            # [пламя, направление от стены] — для проверок
const TORCH_LIGHT := 2.31        # +5% к прежним 2,2
const TORCH_FLAME := 1.05        # яркость пламени +5%

func _build_torch(t: Vector2i) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var d := Vector2i.ZERO
	for dv in dirs:
		if solid(t.x + dv.x, t.y + dv.y):
			d = dv
			break
	if cave:
		if d != Vector2i.ZERO:
			_build_cave_torch(t, d)
		return   # факел без стены рядом висел бы в пустоте — в пещере его нет
	if d == Vector2i.ZERO:
		var best := 99
		for dv in dirs:
			for k in range(2, 6):
				if solid(t.x + dv.x * k, t.y + dv.y * k):
					if k < best:
						best = k
						d = dv
					break
		if best == 99:
			return
		t += d * (best - 1)
	var c := cell_center(t.x, t.y)
	var into := Vector3(d.x, 0, d.y)    # в стену
	var n := -into                       # от стены в зал
	var wall := c + into * CELL / 2.0
	var h := Y + 2.3
	var iron := Mats.lp(0x2e2a26, 0.6, 0.7)
	# Держатель: пластина на стене и короткий кронштейн
	var flat := Vector3(0.05, 0.32, 0.2) if d.x != 0 else Vector3(0.2, 0.32, 0.05)
	_box(flat, iron, Vector3(wall.x, h, wall.z) + n * 0.025)
	var arm := Vector3(0.16, 0.05, 0.06) if d.x != 0 else Vector3(0.06, 0.05, 0.16)
	_box(arm, iron, Vector3(wall.x, h - 0.08, wall.z) + n * 0.1)
	# Факел под углом от стены
	var tilt := 0.45
	var up := (Vector3.UP * cos(tilt) + n * sin(tilt)).normalized()
	var base := Vector3(wall.x, h - 0.2, wall.z) + n * 0.16
	var stick := _mesh(_cyl(0.06, 0.08, 0.7, 5), Mats.lp(0x4a3220), base + up * 0.35)
	stick.basis = _basis_up_to(up)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = WorldGen.hex(0xffb040) * TORCH_FLAME
	var top := base + up * 0.72
	var fl := _mesh(_cyl(0.0, 0.15, 0.4, 5), flame_mat, top + Vector3(0, 0.18, 0))
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xff8a30)
	light.light_energy = TORCH_LIGHT
	light.omni_range = 18.0
	light.omni_attenuation = 1.3
	light.position = top + n * 0.6 + Vector3(0, 0.2, 0)
	add_child(light)
	torch_spots.append([top, n])
	_flickers.append({"light": light, "flame": fl, "base": TORCH_LIGHT, "seed": _rng.randf() * 100.0, "slow": false})

# ---------- Кристаллы: растут на стенах и потолке пещеры и мягко светятся
const CRYSTAL_BOOST := 1.02      # свет и свечение кристаллов +2%
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
			var e := (1.1 if cl.get("big", false) else 0.7) * CRYSTAL_BOOST
			light.light_energy = e
			light.omni_range = 14.0
			light.omni_attenuation = 1.5
			light.position = Vector3(bx - cl["a"] * 0.8, by + 0.5, bz - cl["b"] * 0.8)
			add_child(light)
			_flickers.append({"light": light, "base": e, "seed": _rng.randf() * 100.0, "slow": true})
	for hi in 2:
		var m := Mats.lp(Color.from_hsv(hues[hi], 0.55, 0.95).to_rgba32() >> 8, 0.25, 0.0, Color.from_hsv(hues[hi], 0.85, 0.7).to_rgba32() >> 8, 1.1 * CRYSTAL_BOOST)
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

func _place_random_chest(floors: Array) -> void:
	var start := cell_of(start_pos)
	var boss_c := cell_of(boss_pos)
	var cand := []
	for c in floors:
		var t := ch(c.x, c.y)
		if t != ".":
			continue
		if absi(c.x - start.x) + absi(c.y - start.y) < 5:
			continue
		if boss_pos != Vector3.ZERO and absi(c.x - boss_c.x) + absi(c.y - boss_c.y) < 7:
			continue
		var gate_near := false
		for g in gate_cells:
			if absi(c.x - g.x) + absi(c.y - g.y) < 3:
				gate_near = true
		if not gate_near:
			cand.append(c)
	if cand.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.randomize()
	var pick: Vector2i = cand[r.randi_range(0, cand.size() - 1)]
	_build_chest(cell_center(pick.x, pick.y))

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

# ---------- Убранство этажей башни: знамёна в цветах этажа, витражи, подсвечники
func _build_tower_decor(floors: Array) -> void:
	var wall_c := WorldGen.hex(def["wall"])
	var light_c := WorldGen.hex(def["light"])
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(wall_c.r * 0.5 + 0.35, wall_c.g * 0.25, wall_c.b * 0.25)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 0.95
	var gold := Mats.lp(0xd8a840, 0.35, 0.7, 0x805010, 0.5)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = light_c.lerp(Color.WHITE, 0.2)
	var frame := Mats.lp(0x2a2622, 0.6, 0.6)
	var r := RandomNumberGenerator.new()
	r.seed = 501 + index
	var banners := []
	var windows := []
	var candles := []
	for f in floors:
		var c := ch(f.x, f.y)
		if c in ["S", "G", "U", "B"]:
			continue
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not solid(f.x + dv.x, f.y + dv.y):
				continue
			var roll := r.randf()
			var cc := cell_center(f.x, f.y)
			var into := Vector3(dv.x, 0, dv.y)
			var wall := cc + into * (CELL / 2.0 - 0.04)
			var yaw := atan2(-into.x, -into.z)
			if roll < 0.14:
				banners.append([wall, yaw])
			elif roll < 0.24:
				windows.append([wall, yaw])
			elif roll < 0.3:
				candles.append([wall, yaw, into])
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 3.0)
	for b in banners:
		var n := Node3D.new()
		n.position = b[0] + Vector3(0, Y + 2.6, 0) - Vector3(0, Y, 0)
		n.rotation.y = b[1]
		add_child(n)
		var q := MeshInstance3D.new()
		q.mesh = quad
		q.material_override = cloth
		n.add_child(q)
		_box(Vector3(1.6, 0.1, 0.1), gold, Vector3(0, 1.55, 0.02), n)        # перекладина
		_box(Vector3(0.45, 0.45, 0.03), gold, Vector3(0, 0.4, 0.02), n).rotation.z = PI / 4.0   # знак
	var wq := QuadMesh.new()
	wq.size = Vector2(1.1, 2.0)
	for w in windows:
		var n := Node3D.new()
		n.position = w[0] + Vector3(0, 2.6, 0)
		n.rotation.y = w[1]
		add_child(n)
		var q := MeshInstance3D.new()
		q.mesh = wq
		q.material_override = glass
		n.add_child(q)
		var arch := MeshInstance3D.new()
		arch.mesh = _cyl(0.55, 0.55, 0.02, 12)
		arch.material_override = glass
		arch.rotation.x = PI / 2.0
		arch.position = Vector3(0, 1.0, 0)
		n.add_child(arch)
		for x in [-0.6, 0.6]:
			_box(Vector3(0.1, 2.2, 0.08), frame, Vector3(x, 0, 0.03), n)
		_box(Vector3(1.3, 0.1, 0.08), frame, Vector3(0, -1.05, 0.03), n)
		_box(Vector3(0.05, 2.0, 0.06), frame, Vector3(0, 0, 0.04), n)       # переплёт
		_box(Vector3(1.1, 0.05, 0.06), frame, Vector3(0, 0.2, 0.04), n)
	for cd in candles:
		var n := Node3D.new()
		n.position = cd[0] + Vector3(0, 1.9, 0) - (cd[2] as Vector3) * 0.15
		add_child(n)
		_box(Vector3(0.3, 0.06, 0.3), gold, Vector3.ZERO, n)
		for k in 3:
			var cdl := MeshInstance3D.new()
			cdl.mesh = _cyl(0.035, 0.035, 0.22, 6)
			cdl.material_override = Mats.lp(0xf0e6d0)
			cdl.position = Vector3((k - 1) * 0.1, 0.14, 0)
			n.add_child(cdl)
			var fl := MeshInstance3D.new()
			fl.mesh = _cyl(0.0, 0.03, 0.08, 5)
			fl.material_override = Mats.glow(0xffc060)
			fl.position = Vector3((k - 1) * 0.1, 0.3, 0)
			n.add_child(fl)

# ---------- Комната стража этажа: ворота и лестница
## Клетки комнаты — всё, куда можно дойти от места стража, не проходя ворота
func _find_room() -> void:
	room = {}
	if boss_pos == Vector3.ZERO:
		return
	var start := cell_of(boss_pos)
	var stack := [start]
	room[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if room.has(n) or solid(n.x, n.y) or ch(n.x, n.y) == "G":
				continue
			room[n] = true
			stack.append(n)

func in_room(p: Vector3) -> bool:
	return absf(p.y - Y) < 6.0 and room.has(cell_of(p))

## Ворота: каменная арка и железная решётка, которая опускается, когда начинается бой
func _build_gate(g: Vector2i) -> void:
	var c := cell_center(g.x, g.y)
	# Решётка поперёк прохода: проход идёт вдоль той оси, где стен нет
	var across_x := solid(g.x, g.y - 1) == false and solid(g.x, g.y + 1) == false
	var iron := Mats.lp(0x3a3634, 0.5, 0.7)
	var stone := Mats.tiled(Mats.brick_texture(), Color(WorldGen.hex(def["wall"])).darkened(0.2).to_rgba32() >> 8, 0.25)
	var arch := Node3D.new()
	arch.position = c
	if not across_x:
		arch.rotation.y = PI / 2.0
	add_child(arch)
	# Арка сверху (над решёткой)
	_box(Vector3(CELL, 1.0, 0.6), stone, Vector3(0, WALL_H - 0.5, 0), arch)
	var bars := Node3D.new()
	arch.add_child(bars)
	for k in 9:
		_box(Vector3(0.09, WALL_H - 1.0, 0.09), iron, Vector3(-CELL / 2.0 + 0.25 + k * (CELL - 0.5) / 8.0, (WALL_H - 1.0) / 2.0, 0), bars)
	for yy in [0.5, 2.0, 3.4]:
		_box(Vector3(CELL - 0.2, 0.1, 0.12), iron, Vector3(0, yy, 0), bars)
	# Красные огни по бокам — видно, что за воротами страж
	for side in [-1.0, 1.0]:
		var gem := MeshInstance3D.new()
		gem.mesh = _cyl(0.0, 0.12, 0.3, 4)
		gem.material_override = Mats.glow(0xff3020)
		arch.add_child(gem)
		gem.position = Vector3(side * (CELL / 2.0 - 0.15), WALL_H - 1.4, 0.32)
	_gate_bars.append([bars, WALL_H - 1.1])
	bars.position.y = WALL_H - 1.1
	var sh := BoxShape3D.new()
	sh.size = Vector3(CELL, WALL_H, 0.5) if across_x else Vector3(0.5, WALL_H, CELL)
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = Vector3(c.x, Y + WALL_H / 2.0, c.z)
	cs.disabled = true
	_body.add_child(cs)
	_gate_shapes.append(cs)

func set_gate(closed: bool) -> void:
	if closed == gate_closed:
		return
	gate_closed = closed
	for cs in _gate_shapes:
		(cs as CollisionShape3D).set_deferred("disabled", not closed)

## Лестница наверх: каменные ступени к люку в потолке; светится, когда страж побеждён
func _build_stairs(p: Vector3) -> void:
	var stone := Mats.tiled(Mats.brick_texture(), Color(WorldGen.hex(def["wall"])).lightened(0.1).to_rgba32() >> 8, 0.25)
	# Ступени поднимаются к стене, низ — со стороны свободной клетки
	var cc := cell_of(p)
	var front := Vector2i(0, 1)
	for dv in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if not solid(cc.x + dv.x, cc.y + dv.y):
			front = dv
	var root := Node3D.new()
	root.position = Vector3(p.x, Y, p.z)
	root.rotation.y = atan2(front.x, front.y)
	add_child(root)
	for k in 6:
		_box(Vector3(2.4, 0.35 * (k + 1), 0.5), stone, Vector3(0, 0.175 * (k + 1), 1.2 - k * 0.5), root)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7
	ring.outer_radius = 1.0
	ring.rings = 20
	ring.ring_segments = 4
	var glow := MeshInstance3D.new()
	glow.mesh = ring
	glow.material_override = Mats.glow(0xffd060)
	root.add_child(glow)
	glow.position = Vector3(0, 0.06, 2.6)
	glow.scale = Vector3(1, 0.06, 1)
	var light := OmniLight3D.new()
	light.light_color = WorldGen.hex(0xffd060)
	light.omni_range = 7.0
	light.position = Vector3(0, 2.0, 1.5)
	root.add_child(light)
	_stairs_glow = [glow, light]
	stairs_front = p + Vector3(front.x, 0, front.y) * 2.6
	_col_box(Vector3(p.x, Y + 1.0, p.z), Vector3(2.4, 2.0, 2.4))
	set_stairs(false)

var stairs_front := Vector3.ZERO   # где стоять, чтобы подняться

func set_stairs(on: bool) -> void:
	stairs_open = on
	if _stairs_glow.is_empty():
		return
	(_stairs_glow[0] as Node3D).visible = on
	(_stairs_glow[1] as OmniLight3D).light_energy = 1.4 if on else 0.0

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
	if not _gate_bars.is_empty():
		_gate_t = move_toward(_gate_t, 1.0 if gate_closed else 0.0, dt * (3.0 if gate_closed else 1.0))
		for gb in _gate_bars:
			(gb[0] as Node3D).position.y = gb[1] * (1.0 - _gate_t)
	if chest.get("opened", false) and chest["t"] < 1.0:
		chest["t"] = minf(1.0, chest["t"] + dt * 1.5)
		(chest["lid"] as Node3D).rotation.x = -1.9 * (1.0 - pow(1.0 - chest["t"], 3))
		(chest["light"] as OmniLight3D).light_energy = 1.5 * chest["t"]

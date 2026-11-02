## Щиты и клинки в духе SAO, строятся из точек (без моделей):
## щиты — круглый деревянный баклер, железный щит-«капля», большой башенный щит с крестом;
## клинки — прямой одноручный меч с гардой-крыльями, широкий двуручник, рапира с чашкой-гардой,
## кинжал. Клинок — ромб в сечении со скосом к кромкам и долом, рукоять обмотана, навершие.
## Система координат: щит лежит в плоскости XY лицом к +Z; клинок вдоль +Y, ширина — X, рукоять ниже 0.
class_name SaoGear
extends RefCounted

# ---------- Щиты
## Контур щита (по часовой), y — вдоль предплечья, x — поперёк
static func _shield_outline(kind: String) -> PackedVector2Array:
	var o := PackedVector2Array()
	match kind:
		"round":
			for i in 28:
				var a := TAU * i / 28.0
				o.append(Vector2(cos(a), sin(a)) * 0.24)
		"heater":
			# прямой верх, бока плавно сходятся к острию (против часовой стрелки)
			var w := 0.19
			var h := 0.2
			var h2 := 0.3
			for i in 9:
				var t := float(i) / 8.0
				o.append(Vector2(lerpf(w, -w, t), h + 0.02 * sin(t * PI)))
			for i in range(1, 13):
				var t := float(i) / 12.0
				o.append(Vector2(-w * (1.0 - t * t), h - t * (h + h2)))
			for i in range(11, 0, -1):
				var t := float(i) / 12.0
				o.append(Vector2(w * (1.0 - t * t), h - t * (h + h2)))
		"tower":
			# большой щит с закруглённым верхом и острым низом
			var w := 0.23
			for i in 13:
				var a := PI * i / 12.0
				o.append(Vector2(cos(a) * w, 0.24 + sin(a) * 0.12))
			for i in range(1, 14):
				var t := float(i) / 13.0
				o.append(Vector2(-w * pow(1.0 - t, 0.8), 0.24 - t * 0.66))
			for i in range(12, 0, -1):
				var t := float(i) / 13.0
				o.append(Vector2(w * pow(1.0 - t, 0.8), 0.24 - t * 0.66))
	return o

## Выпуклая пластина по контуру: лицевая сторона, тыльная, торец; bulge — выпуклость в центре
static func _plate(outline: PackedVector2Array, thick: float, bulge: float, scale := 1.0, z0 := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	var rmax := 0.0
	for p in outline:
		rmax = maxf(rmax, p.length())
	var face := func(p: Vector2) -> Vector3:
		var q := p * scale
		return Vector3(q.x, q.y, z0 + bulge * (1.0 - (q.length() / (rmax * scale)) ** 2))
	# центр и кольца — чтобы выпуклость была плавной
	var rings := 4
	for side in [1.0, -1.0]:
		for i in n:
			var p0: Vector2 = outline[i]
			var p1: Vector2 = outline[(i + 1) % n]
			for r in rings:
				var u0 := float(r) / rings
				var u1 := float(r + 1) / rings
				var a: Vector3 = face.call(p0 * u0)
				var b: Vector3 = face.call(p1 * u0)
				var c: Vector3 = face.call(p0 * u1)
				var d: Vector3 = face.call(p1 * u1)
				if side < 0.0:
					a.z -= thick
					b.z -= thick
					c.z -= thick
					d.z -= thick
					st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
					st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
				else:
					st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
					st.add_vertex(b); st.add_vertex(d); st.add_vertex(c)
	for i in n:
		var a: Vector3 = face.call(outline[i])
		var b: Vector3 = face.call(outline[(i + 1) % n])
		var a2 := a - Vector3(0, 0, thick)
		var b2 := b - Vector3(0, 0, thick)
		st.add_vertex(a); st.add_vertex(a2); st.add_vertex(b)
		st.add_vertex(b); st.add_vertex(a2); st.add_vertex(b2)
	st.generate_normals()
	return st.commit()

## Щит: Node3D с пластиной, металлической кантовкой и украшением (умбон или крест)
static func shield(kind: String) -> Node3D:
	var root := Node3D.new()
	var outline := _shield_outline(kind)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var bulge := 0.03 if kind == "round" else 0.045
	body.mesh = _plate(outline, 0.02, bulge)
	body.material_override = StandardMaterial3D.new()
	root.add_child(body)
	# Кантовка: тот же контур чуть больше, тонкая, позади пластины
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = _plate(outline, 0.012, bulge, 1.06, 0.0)
	rim.position.z = -0.009
	root.add_child(rim)
	var deco := MeshInstance3D.new()
	deco.name = "Deco"
	if kind == "tower":
		# Крест на лицевой стороне
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(st, Vector3(0, -0.02, bulge + 0.012), Vector3(0.045, 0.42, 0.016))
		_box(st, Vector3(0, 0.12, bulge + 0.008), Vector3(0.28, 0.045, 0.016))
		st.generate_normals()
		deco.mesh = st.commit()
	else:
		var s := SphereMesh.new()
		s.radius = 0.055 if kind == "round" else 0.045
		s.height = s.radius * 1.2
		s.is_hemisphere = true
		deco.mesh = s
		deco.rotation.x = PI / 2.0
		deco.position = Vector3(0, 0.0 if kind == "round" else 0.05, bulge)
	root.add_child(deco)
	return root

static func paint_shield(root: Node3D, color: Color, metal: bool) -> void:
	var b := (root.get_node("Body") as MeshInstance3D).material_override as StandardMaterial3D
	b.albedo_color = color
	b.metallic = 0.5 if metal else 0.0
	b.roughness = 0.45 if metal else 0.8
	(root.get_node("Rim") as MeshInstance3D).material_override = _metal(Color("#c8b070") if not metal else Color("#e8e8f0"))
	(root.get_node("Deco") as MeshInstance3D).material_override = _metal(Color("#c03030")) if root.get_node("Deco").mesh is ArrayMesh else _metal(Color("#d8c890"))

static func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.8
	m.roughness = 0.3
	return m

static func _box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s / 2.0
	var p := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for f in [[4, 5, 6, 7], [1, 0, 3, 2], [0, 4, 7, 3], [5, 1, 2, 6], [7, 6, 2, 3], [0, 1, 5, 4]]:
		st.add_vertex(c + p[f[0]]); st.add_vertex(c + p[f[1]]); st.add_vertex(c + p[f[2]])
		st.add_vertex(c + p[f[0]]); st.add_vertex(c + p[f[2]]); st.add_vertex(c + p[f[3]])

# ---------- Клинки
## Форма клинка по типу: ширина у гарды, длина, сужение к острию, толщина, дол
const BLADE := {
	"sword": {"w": 0.052, "len": 0.86, "taper": 0.72, "tip": 0.09, "thick": 0.009, "fuller": true, "guard": "wings", "grip": 0.2},
	"great": {"w": 0.085, "len": 1.12, "taper": 0.8, "tip": 0.13, "thick": 0.012, "fuller": true, "guard": "bar", "grip": 0.3},
	"rapier": {"w": 0.022, "len": 0.92, "taper": 0.45, "tip": 0.12, "thick": 0.008, "fuller": false, "guard": "cup", "grip": 0.17},
	"dagger": {"w": 0.04, "len": 0.34, "taper": 0.55, "tip": 0.08, "thick": 0.008, "fuller": false, "guard": "small", "grip": 0.12},
}

## Клинок: Node3D с частями Blade (клинок), Guard (гарда), Grip (рукоять), Pommel (навершие)
static func blade(wt: String) -> Node3D:
	var b: Dictionary = BLADE.get(wt, BLADE["sword"])
	var root := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)   # грани клинка плоские — видны скосы к кромке
	var L: float = b["len"]
	var W: float = b["w"]
	var T: float = b["thick"]
	var steps := 14
	var prof := []   # [y, полуширина, полутолщина в середине, полутолщина у кромки]
	for i in steps + 1:
		var u := float(i) / steps
		var y := u * L
		var hw: float = W * 0.5 * lerpf(1.0, b["taper"], u)
		var tip_start: float = 1.0 - b["tip"] / L * 1.0
		if u > tip_start:
			hw *= sqrt(maxf(0.0, 1.0 - (u - tip_start) / (1.0 - tip_start)))
		prof.append([y, maxf(hw, 0.0005), T * 0.5 * lerpf(1.0, 0.6, u)])
	# Сечение: кромка (±hw, 0), середина (0, ±t); дол — неглубокая канавка в середине
	for i in steps:
		var p0: Array = prof[i]
		var p1: Array = prof[i + 1]
		for s in [1.0, -1.0]:
			for side in [1.0, -1.0]:
				var e0 := Vector3(side * p0[1], p0[0], 0)
				var e1 := Vector3(side * p1[1], p1[0], 0)
				var fu: bool = b["fuller"] and i < steps * 0.7
				var m0 := Vector3(side * p0[1] * 0.18, p0[0], s * p0[2] * (0.6 if fu else 1.0))
				var m1 := Vector3(side * p1[1] * 0.18, p1[0], s * p1[2] * (0.6 if fu else 1.0))
				var c0 := Vector3(0, p0[0], s * p0[2] * (0.45 if fu else 1.0))
				var c1 := Vector3(0, p1[0], s * p1[2] * (0.45 if fu else 1.0))
				var flip: bool = s * side > 0.0
				_quad(st, e0, e1, m1, m0, flip)
				_quad(st, m0, m1, c1, c0, flip)
	st.generate_normals()
	var bl := MeshInstance3D.new()
	bl.name = "Blade"
	bl.mesh = st.commit()
	root.add_child(bl)
	# Гарда
	var g := SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	match b["guard"]:
		"wings":
			# крылья гарды, плавно загнутые к клинку, и выступ на клинок
			for side in [-1.0, 1.0]:
				for k in 10:
					var u := float(k) / 9.0
					var x: float = side * (0.008 + u * 0.075)
					_box(g, Vector3(x, 0.004 + u * u * 0.03, 0), Vector3(0.012, 0.02 - u * 0.006, 0.026 - u * 0.01))
			_box(g, Vector3(0, 0.012, 0), Vector3(W * 0.9, 0.035, 0.022))
		"bar":
			_box(g, Vector3(0, 0, 0), Vector3(0.26, 0.03, 0.034))
			_box(g, Vector3(0, 0.02, 0), Vector3(W * 1.1, 0.04, 0.028))
		"cup":
			# чашка с дужкой к навершию — как у рапиры
			_box(g, Vector3(0, 0, 0), Vector3(0.11, 0.012, 0.02))
			for k in 16:
				var a := TAU * k / 16.0
				_box(g, Vector3(cos(a) * 0.045, -0.006, sin(a) * 0.045), Vector3(0.02, 0.008, 0.02))
			for k in 8:
				var u := float(k) / 7.0
				_box(g, Vector3(0.05 + sin(u * PI) * 0.012, -u * 0.16, 0), Vector3(0.008, 0.024, 0.008))
		"small":
			_box(g, Vector3(0, 0, 0), Vector3(0.09, 0.016, 0.024))
	g.generate_normals()
	var gu := MeshInstance3D.new()
	gu.name = "Guard"
	gu.mesh = g.commit()
	root.add_child(gu)
	# Рукоять с обмоткой и навершие
	var gl: float = b["grip"]
	var gr := SurfaceTool.new()
	gr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wraps := int(gl / 0.02)
	for k in wraps:
		_box(gr, Vector3(0, -0.012 - (k + 0.5) * gl / wraps, 0), Vector3(0.028 if k % 2 == 0 else 0.025, gl / wraps * 0.95, 0.026 if k % 2 == 0 else 0.023))
	gr.generate_normals()
	var gm := MeshInstance3D.new()
	gm.name = "Grip"
	gm.mesh = gr.commit()
	root.add_child(gm)
	var pm := MeshInstance3D.new()
	pm.name = "Pommel"
	var ps := SphereMesh.new()
	ps.radius = 0.024 if wt != "great" else 0.03
	ps.height = ps.radius * 2.2
	pm.mesh = ps
	pm.position.y = -0.012 - gl - ps.radius * 0.8
	root.add_child(pm)
	return root

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, flip: bool) -> void:
	if flip:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
		st.add_vertex(a); st.add_vertex(d); st.add_vertex(c)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)

## Цвета клинка по предмету: металл клинка, гарда, рукоять; свечение для редких
static func paint_blade(root: Node3D, blade_col: Color, guard_col: Color, grip_col: Color, glow: Color, glow_energy: float) -> void:
	var bm := StandardMaterial3D.new()
	bm.albedo_color = blade_col
	bm.metallic = 0.9
	bm.roughness = 0.18
	bm.metallic_specular = 0.8
	if glow_energy > 0.0:
		bm.emission_enabled = true
		bm.emission = glow
		bm.emission_energy_multiplier = glow_energy
	(root.get_node("Blade") as MeshInstance3D).material_override = bm
	(root.get_node("Guard") as MeshInstance3D).material_override = _metal(guard_col)
	(root.get_node("Pommel") as MeshInstance3D).material_override = _metal(guard_col)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = grip_col
	gm.roughness = 0.85
	(root.get_node("Grip") as MeshInstance3D).material_override = gm

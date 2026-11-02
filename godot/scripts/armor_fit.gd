## Броня по фигуре героя. Каждая деталь — оболочка вокруг кости (нагрудник вокруг позвоночника,
## наручи вокруг предплечья, поножи вокруг голени…). Радиус оболочки в каждом направлении берётся
## по самой выступающей точке тела в этом месте (+ толщина брони), поэтому тело и одежда модели
## никогда не проходят сквозь доспех. Оболочка привязана к тем же костям, что и тело
## (весами ближайших точек тела или жёстко к одной кости) — двигается вместе с ним.
class_name ArmorFit
extends RefCounted

var _mi: MeshInstance3D
var _skin: Skin
var _verts: PackedVector3Array
var _bones: PackedInt32Array
var _weights: PackedFloat32Array
var _nb := 4
var _dom: PackedInt32Array            # главная кость (номер привязки) у каждой точки тела
var _bind := {}                       # окончание имени кости → номер привязки в Skin
var _grid := {}                       # ячейка 6 см → точки тела (для поиска ближайшей)
const CELL := 0.06
var _flip := false
var _index: PackedInt32Array
var _arrays := []
var _format := 0
var _orig_mesh: Mesh

func _init(mi: MeshInstance3D) -> void:
	_mi = mi
	_skin = mi.skin
	var a := mi.mesh.surface_get_arrays(0)
	_verts = a[Mesh.ARRAY_VERTEX]
	_bones = a[Mesh.ARRAY_BONES]
	_weights = a[Mesh.ARRAY_WEIGHTS]
	_nb = _bones.size() / maxi(_verts.size(), 1)
	_index = a[Mesh.ARRAY_INDEX]
	_arrays = a
	_format = mi.mesh.surface_get_format(0)
	_orig_mesh = mi.mesh
	for i in _skin.get_bind_count():
		_bind[String(_skin.get_bind_name(i)).trim_prefix("mixamorig_").trim_prefix("mixamorig:")] = i
	_dom.resize(_verts.size())
	for v in _verts.size():
		var best := 0
		var bw := -1.0
		for k in _nb:
			if _weights[v * _nb + k] > bw:
				bw = _weights[v * _nb + k]
				best = _bones[v * _nb + k]
		_dom[v] = best
		var c := _cell(_verts[v])
		if not _grid.has(c):
			_grid[c] = PackedInt32Array()
		_grid[c].append(v)

func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))

## Положение кости (по окончанию имени: "Spine1", "LeftForeArm") в системе сетки, поза покоя
func pos(suffix: String) -> Vector3:
	if _bind.has(suffix):
		return _skin.get_bind_pose(_bind[suffix]).affine_inverse().origin
	# Концевые кости (макушка, кончик носка) без точек тела: от родителя по позе покоя
	var sk: Skeleton3D = _mi.get_node(_mi.skeleton)
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			var par := sk.get_bone_parent(i)
			var pn := sk.get_bone_name(par).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
			if _bind.has(pn):
				return _skin.get_bind_pose(_bind[pn]).affine_inverse() * sk.get_bone_rest(i).origin
	return Vector3.ZERO

func has_bone(suffix: String) -> bool:
	return _bind.has(suffix)

## Оболочка вокруг оси a→b.
## cfg: a, b — концы оси; t0, t1 — от/до (доли длины, можно за пределами 0..1);
## bones — кости, точки которых облегаем; fwd — направление «угол 0» (по умолчанию вперёд, +Z);
## arc — [от, до] угол в градусах (0 — fwd, 90 — влево от оси… по правилу правой руки вокруг a→b);
## rings, sectors — подробность; thick — толщина/зазор; rmin — радиус там, где тела нет;
## rmax — дальше от оси точки не учитываем; flare — расширение краёв [низ, верх] (м);
## skin — "nearest" или имя кости для жёсткой привязки; cap0/cap1 — закрыть торцы.
func shell(cfg: Dictionary, mat: Material) -> MeshInstance3D:
	var a: Vector3 = cfg["a"]
	var b: Vector3 = cfg["b"]
	var t0: float = cfg.get("t0", 0.0)
	var t1: float = cfg.get("t1", 1.0)
	var rings: int = cfg.get("rings", 10)
	var sectors: int = cfg.get("sectors", 24)
	var thick: float = cfg.get("thick", 0.02)
	var rmin: float = cfg.get("rmin", 0.04)
	var rmax: float = cfg.get("rmax", 0.3)
	var arc: Array = cfg.get("arc", [0.0, 360.0])
	var full: bool = absf(float(arc[1]) - float(arc[0])) >= 359.9
	var flare: Array = cfg.get("flare", [0.0, 0.0])
	# Какие точки тела облегаем: кости из bones, или (если задан exclude) все, кроме исключённых
	# — так в оболочку попадает и одежда модели (куртка, капюшон), привязанная к соседним костям
	var allowed := {}
	for s in cfg.get("bones", []):
		if _bind.has(s):
			allowed[_bind[s]] = true
	var envelope := allowed
	if cfg.has("exclude"):
		envelope = {}
		for nm in _bind:
			var skip := false
			for ex in cfg["exclude"]:
				if String(nm).begins_with(ex):
					skip = true
			if not skip:
				envelope[_bind[nm]] = true
	var ax := b - a
	var len := ax.length()
	var d := ax / len
	var fwd: Vector3 = cfg.get("fwd", Vector3(0, 0, 1))
	var e0 := (fwd - d * fwd.dot(d)).normalized()
	if e0.length() < 0.5:
		e0 = (Vector3.UP - d * d.y).normalized()
	var e1 := d.cross(e0).normalized()
	var a0 := deg_to_rad(float(arc[0]))
	var a1 := deg_to_rad(float(arc[1]))
	var cols := sectors if full else sectors + 1
	# 1) Самая выступающая точка тела в каждой ячейке (кольцо × сектор)
	var r := PackedFloat32Array()
	r.resize((rings + 1) * cols)
	r.fill(-1.0)
	var rsum := PackedFloat32Array()
	rsum.resize(r.size())
	var rcnt := PackedInt32Array()
	rcnt.resize(r.size())
	var fit: float = cfg.get("fit", 1.0)   # 1 — по самой выступающей точке, меньше — плотнее к телу
	var hide_v := {}   # точки тела под этой деталью
	# side_max: брать любые точки (кроме головы и кистей/предплечий), не дальше side_max вбок
	# от оси — так нагрудник облегает и накидку модели, привязанную к плечам и рукам
	var side_max: float = cfg.get("side_max", -1.0)
	var hard := {}
	if side_max > 0.0:
		for nm in _bind:
			var n := String(nm)
			if n.begins_with("Head") or n == "headfront" or n.contains("Hand") or n.contains("ForeArm"):
				hard[_bind[nm]] = true
	for v in _verts.size():
		var by_side := side_max > 0.0 and not hard.has(_dom[v]) and absf((_verts[v] - a).dot(e1)) <= side_max
		if not envelope.has(_dom[v]) and not by_side:
			continue
		var p := _verts[v] - a
		var t := p.dot(d) / len
		if t < t0 - 0.5 / rings * (t1 - t0) or t > t1 + 0.5 / rings * (t1 - t0):
			continue
		var q := p - d * (t * len)
		var rad := q.length()
		if rad > rmax:
			continue
		var ang := atan2(q.dot(e1), q.dot(e0))
		var fi := 0.0
		if full:
			fi = fposmod(ang - a0, TAU) / TAU * sectors
		else:
			var rel := fposmod(ang - a0 + PI * 0.0, TAU)
			if rel > a1 - a0 + 0.3:
				if rel < TAU - 0.3:
					continue
				rel -= TAU
			fi = rel / (a1 - a0) * sectors
		var ri := clampi(roundi((t - t0) / (t1 - t0) * rings), 0, rings)
		var ci := roundi(fi)
		ci = posmod(ci, sectors) if full else clampi(ci, 0, sectors)
		var k := ri * cols + ci
		r[k] = maxf(r[k], rad)
		rsum[k] += rad
		rcnt[k] += 1
		hide_v[v] = true
	if fit < 1.0:
		for k in r.size():
			if rcnt[k] > 0:
				r[k] = lerpf(rsum[k] / rcnt[k], r[k], fit)
	# 2) Пустые ячейки — от соседей; затем «расширить и сгладить»: оболочка всегда снаружи тела
	for it in 40:
		var changed := false
		var nr := r.duplicate()
		for ri in rings + 1:
			for ci in cols:
				var k := ri * cols + ci
				if r[k] >= 0.0:
					continue
				var s := 0.0
				var n := 0
				for o in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
					var rr: int = ri + o[0]
					var cc: int = ci + o[1]
					if full:
						cc = posmod(cc, cols)
					if rr < 0 or rr > rings or cc < 0 or cc >= cols:
						continue
					if r[rr * cols + cc] >= 0.0:
						s += r[rr * cols + cc]
						n += 1
				if n > 0:
					nr[k] = s / n
					changed = true
		r = nr
		if not changed:
			break
	for k in r.size():
		if r[k] < 0.0:
			r[k] = rmin
		r[k] = maxf(r[k], rmin)
	var dil := r.duplicate()
	for ri in rings + 1:
		for ci in cols:
			var m := r[ri * cols + ci]
			for o in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
				var rr: int = ri + o[0]
				var cc: int = ci + o[1]
				if full:
					cc = posmod(cc, cols)
				if rr < 0 or rr > rings or cc < 0 or cc >= cols:
					continue
				m = maxf(m, r[rr * cols + cc])
			dil[ri * cols + ci] = m
	for _pass in int(cfg.get("smooth", 2)):
		var sm := dil.duplicate()
		for ri in rings + 1:
			for ci in cols:
				var s := dil[ri * cols + ci] * 2.0
				var n := 2.0
				for o in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
					var rr: int = ri + o[0]
					var cc: int = ci + o[1]
					if full:
						cc = posmod(cc, cols)
					if rr < 0 or rr > rings or cc < 0 or cc >= cols:
						continue
					s += dil[rr * cols + cc]
					n += 1.0
				sm[ri * cols + ci] = maxf(s / n, r[ri * cols + ci])
		dil = sm
	# 3) Сетка оболочки (снаружи и тонкая кромка внутрь — видна толщина брони)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for ri in rings + 1:
		var u := float(ri) / rings
		var t := lerpf(t0, t1, u)
		var fl := lerpf(float(flare[0]), 0.0, smoothstep(0.0, 0.25, u)) + lerpf(0.0, float(flare[1]), smoothstep(0.75, 1.0, u))
		var row := []
		for ci in cols:
			var ang := a0 + (float(ci) / sectors) * (TAU if full else (a1 - a0))
			var dirv := e0 * cos(ang) + e1 * sin(ang)
			row.append(a + d * (t * len) + dirv * (dil[ri * cols + ci] + thick + fl))
		pts.append(row)
	var ws := []   # веса для каждой точки оболочки
	var rigid: String = cfg.get("skin", "nearest")
	for ri in rings + 1:
		var row := []
		for ci in cols:
			row.append(_skin_of(pts[ri][ci], rigid, allowed))
		ws.append(row)
	var quads := cols if full else cols - 1
	# Порядок обхода так, чтобы лицевая сторона смотрела от оси наружу
	var p00: Vector3 = pts[0][0]
	var p10: Vector3 = pts[1][0]
	var p01: Vector3 = pts[0][1]
	var nrm := (p01 - p00).cross(p10 - p00)
	var outward := p00 - (a + d * ((p00 - a).dot(d)))
	_flip = nrm.dot(outward) < 0.0
	for ri in rings:
		for ci in quads:
			var c2 := (ci + 1) % cols
			_tri(st, pts, ws, [ri, ci], [ri + 1, ci], [ri + 1, c2])
			_tri(st, pts, ws, [ri, ci], [ri + 1, c2], [ri, c2])
	# Закрыть торцы веером к оси
	for end in [[cfg.get("cap0", false), 0, t0], [cfg.get("cap1", false), rings, t1]]:
		if not end[0]:
			continue
		var ri: int = end[1]
		var c: Vector3 = a + d * (float(end[2]) * len)
		var cw = _skin_of(c, rigid, allowed)
		for ci in quads:
			var c2 := (ci + 1) % cols
			var p1: Vector3 = pts[ri][ci]
			var p2: Vector3 = pts[ri][c2]
			var first := (ri == 0) != _flip
			var order := [p1, p2] if first else [p2, p1]
			var wo := [ws[ri][ci], ws[ri][c2]] if first else [ws[ri][c2], ws[ri][ci]]
			_vert(st, c, cw)
			_vert(st, order[0], wo[0])
			_vert(st, order[1], wo[1])
	st.generate_normals()
	var mesh := st.commit()
	var out := _instance(mesh, mat)
	# Треугольники тела целиком под деталью — их прячем, пока деталь надета (иначе одежда
	# модели, которая толще брони, проступала бы сквозь неё)
	# Прячем треугольник, если его середина внутри детали (по длине, по дуге) и не дальше
	# от оси, чем оболочка + запас, а хотя бы одна вершина принадлежит облегаемым частям
	if cfg.get("hide", true):
		var slack: float = cfg.get("hide_slack", 0.22)
		# hide_any: прятать всё внутри детали (накидки капюшона и т.п.), кроме кистей и предплечий
		var hide_any: bool = cfg.get("hide_any", true)
		var hard_hide := {}
		for nm in _bind:
			for kp in cfg.get("keep", []):
				if String(nm).begins_with(kp):
					hard_hide[_bind[nm]] = true
		var tris := PackedInt32Array()
		for ti in _index.size() / 3:
			var i0 := _index[ti * 3]
			var i1 := _index[ti * 3 + 1]
			var i2 := _index[ti * 3 + 2]
			if not hide_any and not (hide_v.has(i0) or hide_v.has(i1) or hide_v.has(i2)):
				continue
			if hard_hide.has(_dom[i0]) or hard_hide.has(_dom[i1]) or hard_hide.has(_dom[i2]):
				continue
			var c := (_verts[i0] + _verts[i1] + _verts[i2]) / 3.0 - a
			var t := c.dot(d) / len
			if t < t0 or t > t1:
				continue
			var q := c - d * (t * len)
			var ang := atan2(q.dot(e1), q.dot(e0))
			var fi := 0.0
			if full:
				fi = fposmod(ang - a0, TAU) / TAU * sectors
			else:
				var rel := fposmod(ang - a0, TAU)
				if rel > a1 - a0:
					continue
				fi = rel / (a1 - a0) * sectors
			var ri := clampi(roundi((t - t0) / (t1 - t0) * rings), 0, rings)
			var ci := roundi(fi)
			ci = posmod(ci, sectors) if full else clampi(ci, 0, sectors)
			if q.length() <= dil[ri * cols + ci] + thick + slack:
				tris.append(ti)
		out.set_meta("hide", tris)
	return out

## Тело без треугольников, спрятанных под надетыми деталями
func masked_body(hidden: Dictionary) -> ArrayMesh:
	var a := _mi.mesh.surface_get_arrays(0) if _arrays.is_empty() else _arrays
	_arrays = a
	var idx := PackedInt32Array()
	for ti in _index.size() / 3:
		if not hidden.has(ti):
			idx.append(_index[ti * 3])
			idx.append(_index[ti * 3 + 1])
			idx.append(_index[ti * 3 + 2])
	var arr := a.duplicate()
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, _format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	m.surface_set_material(0, _mi.mesh.surface_get_material(0))
	return m

## Свободная сетка из готовых точек (каска, щитки), привязанная к телу так же
func _instance(mesh: ArrayMesh, mat: Material) -> MeshInstance3D:
	var out := MeshInstance3D.new()
	out.mesh = mesh
	out.material_override = mat
	out.skin = _skin
	out.transform = _mi.transform
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mi.get_parent().add_child(out)
	out.skeleton = out.get_path_to(_mi.get_node(_mi.skeleton))
	return out

func _tri(st: SurfaceTool, pts: Array, ws: Array, i: Array, j: Array, k: Array) -> void:
	_vert(st, pts[i[0]][i[1]], ws[i[0]][i[1]])
	if _flip:
		_vert(st, pts[j[0]][j[1]], ws[j[0]][j[1]])
		_vert(st, pts[k[0]][k[1]], ws[k[0]][k[1]])
	else:
		_vert(st, pts[k[0]][k[1]], ws[k[0]][k[1]])
		_vert(st, pts[j[0]][j[1]], ws[j[0]][j[1]])

func _vert(st: SurfaceTool, p: Vector3, w: Array) -> void:
	st.set_bones(w[0])
	st.set_weights(w[1])
	st.set_uv(Vector2(p.x + p.z, p.y) * 4.0)
	st.add_vertex(p)

## Веса для точки оболочки: жёстко к кости или как у ближайшей точки тела
func _skin_of(p: Vector3, rigid: String, allowed: Dictionary) -> Array:
	if rigid != "nearest" and _bind.has(rigid):
		return [PackedInt32Array([_bind[rigid], 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])]
	var c := _cell(p)
	var best := -1
	var bd := INF
	for rad in range(1, 6):
		for x in range(c.x - rad, c.x + rad + 1):
			for y in range(c.y - rad, c.y + rad + 1):
				for z in range(c.z - rad, c.z + rad + 1):
					var key := Vector3i(x, y, z)
					if not _grid.has(key):
						continue
					for v in _grid[key]:
						if not allowed.is_empty() and not allowed.has(_dom[v]):
							continue
						var dd := p.distance_squared_to(_verts[v])
						if dd < bd:
							bd = dd
							best = v
		if best >= 0:
			break
	if best < 0:
		return [PackedInt32Array([_dom[0], 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])]
	var bi := PackedInt32Array()
	var bw := PackedFloat32Array()
	for k in 4:
		bi.append(_bones[best * _nb + k] if k < _nb else 0)
		bw.append(_weights[best * _nb + k] if k < _nb else 0.0)
	return [bi, bw]

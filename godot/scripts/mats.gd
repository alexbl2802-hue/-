## Общие материалы. Цвета задаются как в веб-версии (sRGB hex).
class_name Mats
extends RefCounted

static var _lowpoly_shader: Shader = preload("res://shaders/lowpoly.gdshader")
static var _cache := {}

## Низкополигональный материал с плоскими гранями
static func lp(color: int, rough := 0.9, metal := 0.0, emit := -1, emit_energy := 0.0, detail := 0.0, detail_scale := 0.8) -> ShaderMaterial:
	var key := "%d|%f|%f|%d|%f|%f|%f" % [color, rough, metal, emit, emit_energy, detail, detail_scale]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _lowpoly_shader
	m.set_shader_parameter("albedo", WorldGen.hex(color))
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	if emit >= 0:
		m.set_shader_parameter("emission", WorldGen.hex(emit))
		m.set_shader_parameter("emission_energy", emit_energy)
	if detail > 0.0:
		m.set_shader_parameter("detail", detail)
		m.set_shader_parameter("detail_scale", detail_scale)
		m.set_shader_parameter("detail_tex", noise_texture("grain"))
	_cache[key] = m
	return m

## Аниме-стиль: свет и блики ступенями (тун), мягкая подсветка контура
static func toon(m: Material) -> void:
	if not (m is BaseMaterial3D):
		return
	var b := m as BaseMaterial3D
	b.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	b.specular_mode = BaseMaterial3D.SPECULAR_TOON
	b.rim_enabled = true
	b.rim = 0.25
	b.rim_tint = 0.6

## Тун для всех материалов модели (деревья, камни, постройки из .glb)
static func toon_mesh(mesh: Mesh) -> void:
	for i in mesh.get_surface_count():
		toon(mesh.surface_get_material(i))

## Материал рельефа: газон, земля, камень гор (shaders/terrain.gdshader, textures/*)
static func terrain() -> ShaderMaterial:
	if _cache.has("terrain"):
		return _cache["terrain"]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("detail", noise_texture("grain"))
	mat.set_shader_parameter("macro", noise_texture("macro"))
	mat.set_shader_parameter("rock", noise_texture("rock"))
	mat.set_shader_parameter("mountain", load("res://textures/mountain_rock.jpg"))
	if ResourceLoader.exists("res://textures/mountain_rock_normal.png"):
		mat.set_shader_parameter("mountain_nrm", load("res://textures/mountain_rock_normal.png"))
	mat.set_shader_parameter("grass_tex", load("res://textures/grass_albedo.png"))
	mat.set_shader_parameter("grass_nrm", load("res://textures/grass_normal.png"))
	mat.set_shader_parameter("dirt_tex", load("res://textures/dirt_albedo.png"))
	mat.set_shader_parameter("dirt_nrm", load("res://textures/dirt_normal.png"))
	_cache["terrain"] = mat
	return mat

## Бесшовные шумовые текстуры для детализации (генерируются движком один раз)
static func noise_texture(kind: String) -> NoiseTexture2D:
	var key := "noise_" + kind
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = 7
	var size := 256
	match kind:
		"grain":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.06
			n.fractal_octaves = 4
		"macro":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.02
			n.fractal_octaves = 3
			size = 128
		"clouds":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 5
		"rock":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.04
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_octaves = 2
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.normalize = true
	t.generate_mipmaps = true
	t.noise = n
	_cache[key] = t
	return t

## Светящийся материал без освещения (пламя, фонари)
static func glow(color: int) -> StandardMaterial3D:
	var key := "glow%d" % color
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = WorldGen.hex(color)
	_cache[key] = m
	return m

## Текстурированный материал с мировой трипланарной развёрткой (кирпич, брусчатка)
static func tiled(tex: Texture2D, tint: int, scale := 0.25, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = WorldGen.hex(tint)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	toon(m)
	if not tex.has_meta("normal") and tex is ImageTexture:
		_auto_relief(tex)
	if tex.has_meta("normal"):
		m.normal_enabled = true
		m.normal_texture = tex.get_meta("normal")
		m.normal_scale = 0.9
	# Блики: выпуклые светлые места матовые, швы и выбоины глаже — свет «играет» по кладке
	if tex.has_meta("rough"):
		m.roughness_texture = tex.get_meta("rough")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return m

## Рельеф для текстуры без своей карты нормалей: высота = яркость (тёмные швы глубже)
static func _auto_relief(tex: ImageTexture) -> void:
	var img := tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		return
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	var hm := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			hm.set_pixel(x, y, Color(l, l, l))
	tex.set_meta("normal", _normal_map(hm, 4.0))
	tex.set_meta("rough", _rough_map(hm))

## Карта шероховатости: 0,7 в швах … 1,0 на выпуклостях
static func _rough_map(hm: Image) -> ImageTexture:
	var r := hm.duplicate() as Image
	for y in r.get_height():
		for x in r.get_width():
			var h := r.get_pixel(x, y).r
			var v := 0.7 + 0.3 * clampf(h * 1.6, 0.0, 1.0)
			r.set_pixel(x, y, Color(v, v, v))
	r.generate_mipmaps()
	return ImageTexture.create_from_image(r)

static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	return r

## Кирпичная кладка: кирпичи разного оттенка со сколами по краям, шов вглубь;
## к текстуре приложена карта нормалей (meta "normal") — кладка выглядит объёмной.
static func brick_texture() -> ImageTexture:
	if _cache.has("brick"):
		return _cache["brick"]
	var r := _rng()
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var hm := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(40, 36, 32))
	hm.fill(Color(0.15, 0.15, 0.15))
	var rows := 8
	var bh := s / rows
	var bw := s / 4
	for row in rows:
		for col in range(-1, 5):
			var off := bw / 2 if row % 2 == 1 else 0
			var c := Color.from_hsv((26.0 + r.randf() * 10.0) / 360.0, 0.1 + r.randf() * 0.08, 0.48 + r.randf() * 0.3)
			_block(img, hm, Rect2i(col * bw + off + 2, row * bh + 2, bw - 4, bh - 4), c, r, 5.0)
	_grain(img, hm, r, 5000, 0.12)
	var t := ImageTexture.create_from_image(_mip(img))
	t.set_meta("normal", _normal_map(hm, 6.0))
	t.set_meta("rough", _rough_map(hm))
	_cache["brick"] = t
	return t

## Брусчатка: округлые камни, выпуклые к середине, тёмные швы
static func cobble_texture() -> ImageTexture:
	if _cache.has("cobble"):
		return _cache["cobble"]
	var r := _rng()
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var hm := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(92, 84, 72))
	hm.fill(Color(0.1, 0.1, 0.1))
	var cell := s / 8.0
	for yy in 8:
		for xx in 8:
			var c := Color.from_hsv((30.0 + r.randf() * 12.0) / 360.0, 0.1 + r.randf() * 0.06, 0.5 + r.randf() * 0.22)
			var cx := xx * cell + cell / 2.0 + (cell / 2.0 if yy % 2 == 1 else 0.0) + r.randf_range(-1.5, 1.5)
			var cy := yy * cell + cell / 2.0
			var rx := cell * r.randf_range(0.42, 0.48)
			var ry := cell * r.randf_range(0.38, 0.44)
			for py in range(int(cy - cell / 2), int(cy + cell / 2)):
				for px in range(int(cx - cell / 2) - 1, int(cx + cell / 2) + 1):
					var dx := (px - cx) / rx
					var dy := (py - cy) / ry
					var d := dx * dx + dy * dy
					if d <= 1.0:
						var dome := sqrt(1.0 - d)
						# Свет сверху-слева: верхний край камня светлее
						var shade := 1.0 + (-dx - dy) * 0.12 * (1.0 - dome) + dome * 0.08
						img.set_pixel(posmod(px, s), posmod(py, s), c * shade)
						hm.set_pixel(posmod(px, s), posmod(py, s), Color(0.3 + dome * 0.7, 0, 0))
	_grain(img, hm, r, 5000, 0.12)
	var t := ImageTexture.create_from_image(_mip(img))
	t.set_meta("normal", _normal_map(hm, 5.0))
	t.set_meta("rough", _rough_map(hm))
	_cache["cobble"] = t
	return t

## Плитка пола подземелий: крупные каменные плиты со сколами и трещинами
static func tile_texture() -> ImageTexture:
	if _cache.has("tile"):
		return _cache["tile"]
	var r := _rng()
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var hm := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(30, 28, 26))
	hm.fill(Color(0.1, 0.1, 0.1))
	for a in 2:
		for b in 2:
			var c := Color.from_hsv((32.0 + r.randf() * 8.0) / 360.0, 0.1, 0.42 + r.randf() * 0.16)
			_block(img, hm, Rect2i(a * s / 2 + 4, b * s / 2 + 4, s / 2 - 8, s / 2 - 8), c, r, 7.0)
	# Трещины
	for k in 6:
		var p := Vector2(r.randf() * s, r.randf() * s)
		var d := Vector2.from_angle(r.randf() * TAU)
		for step in 40:
			d = d.rotated(r.randf_range(-0.5, 0.5))
			p += d * 1.5
			var x := posmod(int(p.x), s)
			var y := posmod(int(p.y), s)
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.45))
			hm.set_pixel(x, y, Color(0.35, 0, 0))
	_grain(img, hm, r, 6000, 0.12)
	var t := ImageTexture.create_from_image(_mip(img))
	t.set_meta("normal", _normal_map(hm, 5.0))
	t.set_meta("rough", _rough_map(hm))
	_cache["tile"] = t
	return t

## Блок (кирпич, плита): цвет с пятнами, края скошены — светлый верх-лево, тёмный низ-право
static func _block(img: Image, hm: Image, rc: Rect2i, c: Color, r: RandomNumberGenerator, bevel: float) -> void:
	var s := img.get_width()
	var spot := Vector2(r.randf(), r.randf())
	for py in rc.size.y:
		for px in rc.size.x:
			var ex := minf(px, rc.size.x - 1 - px)
			var ey := minf(py, rc.size.y - 1 - py)
			var e := clampf(minf(ex, ey) / bevel, 0.0, 1.0)
			var shade := 1.0
			if e < 1.0:
				var lit := 0.0
				if py < bevel and py <= ex: lit = 1.0
				elif px < bevel and px <= ey: lit = 0.7
				elif rc.size.y - 1 - py < bevel: lit = -1.0
				elif rc.size.x - 1 - px < bevel: lit = -0.7
				shade += lit * 0.18 * (1.0 - e)
			var u := float(px) / rc.size.x - spot.x
			var v := float(py) / rc.size.y - spot.y
			shade *= 1.0 - 0.12 * exp(-(u * u + v * v) * 8.0)   # пятно потемнее
			var x := posmod(rc.position.x + px, s)
			var y := posmod(rc.position.y + py, s)
			img.set_pixel(x, y, c * shade)
			hm.set_pixel(x, y, Color(0.35 + 0.65 * e, 0, 0))

## Зернистость: мелкие светлые и тёмные точки в цвете и рельефе
static func _grain(img: Image, hm: Image, r: RandomNumberGenerator, n: int, a: float) -> void:
	var s := img.get_width()
	for i in n:
		var x := r.randi() % s
		var y := r.randi() % s
		var v := r.randf()
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(v, v, v), a))
		var h := hm.get_pixel(x, y).r
		hm.set_pixel(x, y, Color(clampf(h + (v - 0.5) * 0.15, 0.0, 1.0), 0, 0))

## Карта нормалей из карты высот (канал R)
static func _normal_map(hm: Image, strength: float) -> ImageTexture:
	var n := hm.duplicate() as Image
	n.convert(Image.FORMAT_RGBA8)
	n.bump_map_to_normal_map(strength)
	n.generate_mipmaps()
	return ImageTexture.create_from_image(n)

static func _speckle(img: Image, r: RandomNumberGenerator, n: int, a: float) -> void:
	var s := img.get_width()
	for i in n:
		var x := r.randi() % s
		var y := r.randi() % s
		var v := r.randf()
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(v, v, v), a))

static func _mip(img: Image) -> Image:
	img.generate_mipmaps()
	return img

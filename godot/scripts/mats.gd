## Общие материалы. Цвета задаются как в веб-версии (sRGB hex).
class_name Mats
extends RefCounted

static var _lowpoly_shader: Shader = preload("res://shaders/lowpoly.gdshader")
static var _cache := {}

## Низкополигональный материал с плоскими гранями
static func lp(color: int, rough := 0.9, metal := 0.0, emit := -1, emit_energy := 0.0) -> ShaderMaterial:
	var key := "%d|%f|%f|%d|%f" % [color, rough, metal, emit, emit_energy]
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
	_cache[key] = m
	return m

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
	return m

static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	return r

## Кирпичная кладка
static func brick_texture() -> ImageTexture:
	if _cache.has("brick"):
		return _cache["brick"]
	var r := _rng()
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(43, 38, 34))
	var bh := s / 8
	var bw := s / 4
	for row in 8:
		for col in range(-1, 5):
			var off := bw / 2 if row % 2 == 1 else 0
			var l := 0.5 + r.randf() * 0.3
			var c := Color.from_hsv(30.0 / 360.0, 0.12, l)
			img.fill_rect(Rect2i(col * bw + off + 2, row * bh + 2, bw - 4, bh - 4), c)
	_speckle(img, r, 900, 0.15)
	var t := ImageTexture.create_from_image(_mip(img))
	_cache["brick"] = t
	return t

## Брусчатка
static func cobble_texture() -> ImageTexture:
	if _cache.has("cobble"):
		return _cache["cobble"]
	var r := _rng()
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(111, 102, 88))
	var cell := s / 8.0
	for yy in 8:
		for xx in 8:
			var c := Color.from_hsv(35.0 / 360.0, 0.12, 0.5 + r.randf() * 0.2)
			var cx := xx * cell + cell / 2.0 + (cell / 2.0 if yy % 2 == 1 else 0.0)
			var cy := yy * cell + cell / 2.0
			for py in range(int(cy - cell / 2), int(cy + cell / 2)):
				for px in range(int(cx - cell / 2), int(cx + cell / 2)):
					var dx := (px - cx) / (cell * 0.44)
					var dy := (py - cy) / (cell * 0.4)
					if dx * dx + dy * dy <= 1.0:
						img.set_pixel(posmod(px, s), posmod(py, s), c)
	var t := ImageTexture.create_from_image(_mip(img))
	_cache["cobble"] = t
	return t

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

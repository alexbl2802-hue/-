## След рывка (как у Кирито на видео): размытая полоса от места старта до героя — тёмно-синяя,
## со штрихами скорости цвета рывка, к хвосту прозрачнее. Полоса всегда повёрнута к камере
## (видна и сбоку, и из-за спины), после появления героя гаснет за 0,35 с.
## Компонент вынесен из scripts/hero.gd: start → update(голова, хвост) → finish.
class_name DashStreak
extends MeshInstance3D

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;
uniform vec3 a;
uniform vec3 b;
uniform float width = 1.4;
uniform float fade = 1.0;
uniform sampler2D tex : filter_linear, repeat_disable;
void vertex() {
	vec3 axis = b - a;
	vec3 mid = (a + b) * 0.5;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = length(axis) > 0.001 ? normalize(axis) : vec3(1.0, 0.0, 0.0);
	vec3 side = cross(dir, normalize(cam - mid));
	side = length(side) > 0.001 ? normalize(side) : vec3(0.0, 1.0, 0.0);
	vec3 p = mid + axis * VERTEX.x + side * VERTEX.y * width;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * fade;
}
"""
const UP := Vector3(0, 0.85, 0)
static var _sh: Shader

## Новая полоса цвета col в узле parent
static func start(parent: Node, col: Color) -> DashStreak:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = SHADER
	var m := DashStreak.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _sh
	mat.set_shader_parameter("tex", _tex(col))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = 16384.0
	parent.add_child(m)
	return m

## Голова полосы — у героя (u = 0), хвост — место старта
func update(head: Vector3, tail: Vector3) -> void:
	var mat: ShaderMaterial = material_override
	mat.set_shader_parameter("a", head + UP)
	mat.set_shader_parameter("b", tail + UP)

## Погасить за 0,35 с и удалить
func finish() -> void:
	var mat: ShaderMaterial = material_override
	var tw := create_tween()
	tw.tween_method(func(f: float): mat.set_shader_parameter("fade", f), 1.0, 0.0, 0.35)
	tw.tween_callback(queue_free)

static func _tex(col: Color) -> ImageTexture:
	var w := 128
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rows := PackedFloat32Array()
	var r := RandomNumberGenerator.new()
	for y in h:
		rows.append(r.randf())
	var navy := Color(0.05, 0.07, 0.18)
	for y in h:
		var v := (y + 0.5) / h * 2.0 - 1.0
		var prof := pow(maxf(0.0, 1.0 - v * v), 1.5)
		# штрихи скорости: соседние строки сглажены, яркие — цвета рывка
		var st := (rows[y] + rows[(y + 1) % h] + rows[(y + h - 1) % h]) / 3.0
		for x in w:
			var u := (x + 0.5) / w           # 0 — у героя, 1 — хвост
			var tail := pow(1.0 - u, 0.9) * smoothstep(0.0, 0.05, u)
			var line := smoothstep(0.6, 0.9, st) * (1.0 - u * 0.5)
			var c := navy.lerp(col, line * 0.5)
			c.a = clampf(pow(prof, 0.7) * tail * (0.7 + 0.3 * st) * 1.1, 0.0, 0.95)
			img.set_pixel(x, h - 1 - y, c)
	return ImageTexture.create_from_image(img)

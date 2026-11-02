## След клинка: светящаяся лента между основанием и кончиком меча за последние доли секунды.
## Цвет — цвет приёма (или белый для обычных ударов), к хвосту лента тает.
class_name SwordTrail
extends MeshInstance3D

const KEEP := 0.14          # сколько секунд держится след
const MIN_STEP := 0.008     # реже точек не добавляем

var emitting := false
var color := Color(0.85, 0.95, 1.0, 0.7)
var _pts: Array = []        # [{base, tip, t}]
var _time := 0.0
var _im := ImmediateMesh.new()

func _ready() -> void:
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	material_override = m
	global_transform = Transform3D()

## Каждый кадр: где сейчас основание и кончик клинка
func feed(base: Vector3, tip: Vector3, dt: float) -> void:
	_time += dt
	if emitting and (_pts.is_empty() or _time - _pts[-1]["t"] >= MIN_STEP):
		_pts.append({"base": base, "tip": tip, "t": _time})
	while not _pts.is_empty() and _time - _pts[0]["t"] > KEEP:
		_pts.pop_front()
	_im.clear_surfaces()
	if _pts.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _pts:
		var k: float = 1.0 - (_time - float(p["t"])) / KEEP      # у меча — ярко, к хвосту — гаснет
		var c := Color(color.r, color.g, color.b, color.a * k * k)
		_im.surface_set_color(Color(c.r, c.g, c.b, c.a * 0.35))
		_im.surface_add_vertex(p["base"].lerp(p["tip"], 0.25))
		_im.surface_set_color(c)
		_im.surface_add_vertex(p["tip"])
	_im.surface_end()

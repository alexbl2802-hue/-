## Гибель монстра как в игре про мечника: тело вспыхивает и рассыпается на светящиеся
## осколки-многоугольники, которые разлетаются, вращаются и тают.
class_name Shatter
extends MultiMeshInstance3D

const LIFE := 1.0
var _v: Array = []     # скорости осколков
var _spin: Array = []
var _base: Array = []  # начальные положения
var _size: Array = []
var _t := 0.0
var _color := Color.WHITE

static func spawn(parent: Node, pos: Vector3, height: float, width: float, color: Color, count := 34) -> void:
	var s := Shatter.new()
	s._color = color
	parent.add_child(s)
	s.global_position = pos
	s._setup(height, width, count)

func _setup(height: float, width: float, count: int) -> void:
	var tri := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0.16, 0), Vector3(-0.13, -0.09, 0), Vector3(0.14, -0.08, 0)])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tri
	mm.instance_count = count
	multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in count:
		var p := Vector3(randf_range(-width, width) * 0.5, randf_range(0.1, height), randf_range(-width, width) * 0.5)
		_base.append(p)
		var out := Vector3(p.x, 0, p.z).normalized() if Vector2(p.x, p.z).length() > 0.01 else Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
		_v.append(out * randf_range(1.0, 3.0) + Vector3(0, randf_range(0.8, 2.8), 0))
		_spin.append(Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)))
		var sc := randf_range(0.9, 2.2)
		_size.append(sc)
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(_spin[i] * 0.1).scaled(Vector3.ONE * sc), p))
		mm.set_instance_color(i, _color)

func _process(dt: float) -> void:
	_t += dt
	var k := _t / LIFE
	if k >= 1.0:
		queue_free()
		return
	for i in multimesh.instance_count:
		var v: Vector3 = _v[i]
		var p: Vector3 = _base[i] + v * _t + Vector3(0, -2.5 * _t * _t, 0)
		var sc: float = _size[i] * (1.0 - k * k)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(_spin[i] * _t).scaled(Vector3.ONE * maxf(0.01, sc)), p))
		var c := _color.lerp(Color.WHITE, 0.4 * (1.0 - k))
		c.a = 1.0 - k
		multimesh.set_instance_color(i, c)

## Визуальные эффекты: всплывающие надписи (урон, опыт, добыча) и световые кольца.
class_name Fx
extends RefCounted

static var root: Node3D  # куда добавлять эффекты (задаёт main.gd)

## Всплывающие надписи рисует интерфейс (hud.gd) поверх 3D — так они всегда чёткие
static var floaters: Array = []   # [{text, pos, color, big, t}]

## Надпись, всплывающая над точкой и тающая
static func text(t: String, pos: Vector3, color: Color, big := false) -> void:
	floaters.append({"text": t, "pos": pos + Vector3(randf_range(-0.3, 0.3), 2.2, randf_range(-0.3, 0.3)), "color": color, "big": big, "t": 0.0})

static func update(dt: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i]["t"] += dt
		if floaters[i]["t"] > 1.4:
			floaters.remove_at(i)

## Плоское светящееся кольцо, расходящееся от точки
static func ring(pos: Vector3, color: Color, grow: float, dur: float, rise := false) -> void:
	if not root:
		return
	var m := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.75
	tor.outer_radius = 1.15
	tor.rings = 32
	tor.ring_segments = 4
	m.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.global_position = pos
	m.scale = Vector3(1, 0.05, 1)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1 + grow, 0.05, 1 + grow), dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	if rise:
		tw.tween_property(m, "global_position:y", pos.y + dur * 1.5, dur)
	tw.chain().tween_callback(m.queue_free)

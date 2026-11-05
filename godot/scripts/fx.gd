## Визуальные эффекты: всплывающие надписи (урон, опыт, добыча) и световые кольца.
class_name Fx
extends RefCounted

static var root: Node3D  # куда добавлять эффекты (задаёт main.gd)
static var base_scale := 1.0   # обычная скорость времени (автотест Кардинала её повышает)
static var _stop_until := 0    # конец «заморозки» кадра, мс реального времени
static var _spark_mat: StandardMaterial3D
static var _flash_mat: StandardMaterial3D

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


## ---------- Ощущение удара: искры, вспышка, «заморозка» кадра, тряска

## Попадание по монстру: искры из точки удара, вспышка, короткая остановка времени и тряска камеры.
## crit — крит (больше искр, золотые, дольше пауза), kill — добивание.
static func impact(pos: Vector3, dir: Vector3, crit := false, kill := false, rig: Node = null) -> void:
	sparks(pos, dir, Color(1.0, 0.82, 0.35) if crit else Color(1.0, 0.93, 0.75), 26 if crit else 14, 1.3 if crit else 1.0)
	flash(pos, Color(1.0, 0.75, 0.3) if crit else Color(1.0, 0.95, 0.85), 0.9 if crit else 0.6)
	hitstop(0.1 if kill else (0.075 if crit else 0.045))
	if rig and rig.has_method("shake"):
		rig.shake(0.1 if kill else (0.07 if crit else 0.035), 0.18)

## Искры: веер быстрых светящихся частиц по направлению удара, падают под тяжестью
static func sparks(pos: Vector3, dir: Vector3, color: Color, amount := 14, size := 1.0) -> void:
	if not root:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.28
	p.explosiveness = 0.95
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.12) * size
	p.mesh = q
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_mat.vertex_color_use_as_albedo = true
	p.material_override = _spark_mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.direction = (d + Vector3.UP * 0.35).normalized()
	p.spread = 40.0
	p.initial_velocity_min = 2.2 * size
	p.initial_velocity_max = 4.8 * size
	p.gravity = Vector3(0, -14, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0))
	g.set_color(1, Color(color.r, color.g * 0.5, color.b * 0.2, 0.0))
	p.color_ramp = g
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.7, false).timeout.connect(p.queue_free)

## Вспышка в точке удара: светящийся диск, мгновенно раздувается и гаснет
static func flash(pos: Vector3, color: Color, size := 0.6) -> void:
	if not root:
		return
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _flash_tex()
	mat.albedo_color = color
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.global_position = pos
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 1.8, 0.14)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	tw.chain().tween_callback(m.queue_free)

static var _flash_texture: Texture2D
static func _flash_tex() -> Texture2D:
	if _flash_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.25, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_flash_texture = t
	return _flash_texture

## «Заморозка» кадра при попадании: время почти останавливается на сотые доли секунды
static func hitstop(dur: float) -> void:
	if not root or base_scale != 1.0:
		return   # в ускоренном автотесте — без пауз
	var now := Time.get_ticks_msec()
	var until := now + roundi(dur * 1000.0)
	if until <= _stop_until:
		return
	_stop_until = until
	Engine.time_scale = 0.06
	var tree := root.get_tree()
	if not tree.process_frame.is_connected(_hitstop_tick):
		tree.process_frame.connect(_hitstop_tick)

## Каждый кадр, пока идёт «заморозка»: по настоящему времени вернуть обычную скорость
static func _hitstop_tick() -> void:
	if Time.get_ticks_msec() < _stop_until:
		return
	Engine.time_scale = base_scale
	if root and root.is_inside_tree() and root.get_tree().process_frame.is_connected(_hitstop_tick):
		root.get_tree().process_frame.disconnect(_hitstop_tick)

## Шип из хвоста волка или ядовитый шар королевы-паучихи: летит прямо, ранит героя при попадании, пропадает в земле или через 2 с
extends Node3D

var velocity := Vector3.ZERO
var hero: Node3D
var dmg := 20
var poison := false   # ядовитый шар королевы-паучихи вместо шипа
var _life := 0.0

func _ready() -> void:
	var mi := MeshInstance3D.new()
	if poison:
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = Mats.lp(0x6ad040, 0.3, 0.0, 0x40ff30, 1.2)
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.05
		cm.height = 0.45
		cm.radial_segments = 4
		mi.mesh = cm
		mi.material_override = Mats.lp(0x2e3138, 0.35, 0.0, 0x803020, 0.6)
		mi.rotation.x = -PI / 2.0   # остриём вперёд (по −Z узла)
	add_child(mi)

func _physics_process(dt: float) -> void:
	_life += dt
	var prev := global_position
	global_position += velocity * dt
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP)
	# Попадание: отрезок полёта прошёл рядом с грудью героя
	if hero and not hero.dead:
		var c: Vector3 = hero.global_position + Vector3(0, 1.0, 0)
		var seg := global_position - prev
		var t := clampf((c - prev).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
		if (prev + seg * t).distance_to(c) < 0.65:
			hero.take_damage(dmg, prev)
			queue_free()
			return
	var g: float = WorldGen.ground_at(global_position.x, global_position.z)
	if global_position.y < -50.0:
		g = -1e9
	if global_position.y < g or _life > 2.0:
		queue_free()

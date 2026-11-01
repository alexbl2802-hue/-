class_name DayNight
## Смена дня и ночи на поверхности: солнце идёт по небу, на закате тёплый свет, ночью — луна,
## тёмное небо, в окнах домов тёплый свет, горят фонари. Ночью монстры бьют сильнее (Game.is_night).
## Время суток хранится в Game.time_of_day (0 — полночь, 0,25 — рассвет, 0,5 — полдень, 0,75 — закат).
extends Node

const DAY_SECONDS := 600.0          # полный круг суток — 10 минут
const NIGHT_DMG := 1.25             # ночью монстры бьют на 25% сильнее

const SKY_DAY := [0x3d7fd1, 0xcfe2ee]
const SKY_NIGHT := [0x060c22, 0x18233e]
const SKY_DUSK := 0xf0a060

var env: Environment
var sun: DirectionalLight3D
var sky: ProceduralSkyMaterial
var moon: DirectionalLight3D
var hero_light: OmniLight3D          # фонарь героя ночью
var hud: Node
var surface := true                  # в подземельях сутки не видны
var _glass: ShaderMaterial
var _was_night := false

func setup(e: Environment, s: DirectionalLight3D, rig: Node3D, h: Node) -> void:
	env = e
	sun = s
	hud = h
	sky = env.sky.sky_material as ProceduralSkyMaterial
	moon = DirectionalLight3D.new()
	moon.light_color = WorldGen.hex(0x8fa8ff)
	moon.shadow_enabled = false
	moon.light_energy = 0.0
	add_child(moon)
	moon.look_at_from_position(Vector3(-60, 120, -40), Vector3.ZERO)
	hero_light = OmniLight3D.new()
	hero_light.light_color = WorldGen.hex(0xffd9a0)
	hero_light.omni_range = 11.0
	hero_light.light_energy = 0.0
	hero_light.position = Vector3(0, 0.6, 1.5)
	rig.add_child(hero_light)
	# Стекло окон в городе — общий материал всех домов
	_glass = Mats.lp(0x6a8aa8, 0.15, 0.3, 0x30404c, 1.0)
	_was_night = Game.is_night
	apply()

## Насколько светло: 1 — день, 0 — ночь
static func daylight(t: float) -> float:
	return smoothstep(-0.06, 0.14, sin((t - 0.25) * TAU))

func _process(dt: float) -> void:
	Game.time_of_day = fmod(Game.time_of_day + dt / DAY_SECONDS, 1.0)
	apply()

func apply() -> void:
	var t: float = Game.time_of_day
	var d := daylight(t)
	Game.is_night = d < 0.35
	if Game.is_night != _was_night:
		_was_night = Game.is_night
		if hud and surface:
			if Game.is_night:
				hud.banner("Наступила ночь", "Монстры становятся сильнее")
			else:
				hud.banner("Рассвет", "Ночь позади")
	moon.visible = surface
	hero_light.visible = surface
	if not surface:
		return
	# Солнце: с востока через зенит на запад
	var a := (t - 0.25) * TAU
	var el := sin(a)
	sun.global_transform = Transform3D(Basis(), Vector3.ZERO)
	sun.look_at_from_position(Vector3(cos(a) * 140.0, el * 150.0 + 4.0, 50.0), Vector3.ZERO)
	var dusk := (1.0 - smoothstep(0.0, 0.35, absf(el))) * d   # низкое солнце — тёплый свет
	sun.light_energy = 1.3 * d
	sun.light_color = WorldGen.hex(0xfff1d6).lerp(WorldGen.hex(0xffa860), dusk)
	sun.shadow_enabled = d > 0.2
	moon.light_energy = 0.55 * (1.0 - d)
	# Небо и туман
	var top := WorldGen.hex(SKY_NIGHT[0]).lerp(WorldGen.hex(SKY_DAY[0]), d)
	var hor := WorldGen.hex(SKY_NIGHT[1]).lerp(WorldGen.hex(SKY_DAY[1]), d).lerp(WorldGen.hex(SKY_DUSK), dusk * 0.6)
	sky.sky_top_color = top
	sky.sky_horizon_color = hor
	sky.ground_horizon_color = hor
	env.ambient_light_energy = lerpf(0.45, 0.9, d)
	env.fog_light_color = hor.lerp(WorldGen.hex(0xb9d3e6), d * 0.5)
	# Ночью — свет в окнах, фонари и фонарь у героя
	var n := 1.0 - d
	_glass.set_shader_parameter("emission", WorldGen.hex(0x30404c).lerp(WorldGen.hex(0xffb860), n))
	_glass.set_shader_parameter("emission_energy", lerpf(1.0, 2.2, n))
	for l in get_tree().get_nodes_in_group("night_lights"):
		(l as OmniLight3D).light_energy = 2.2 * n
	hero_light.light_energy = 1.3 * n

## Множитель урона монстров
static func monster_mult() -> float:
	return NIGHT_DMG if Game.is_night else 1.0

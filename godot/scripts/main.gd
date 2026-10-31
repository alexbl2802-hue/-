## Точка входа: свет и небо, мир, герой, камера, интерфейс и взаимодействия.
extends Node3D

var world: Node3D
var hero: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var _zone := ""
var _act := Callable()

func _ready() -> void:
	var loading := Label.new()
	loading.text = "Загрузка мира…"
	loading.add_theme_font_size_override("font_size", 22)
	loading.set_anchors_preset(Control.PRESET_CENTER)
	var cl := CanvasLayer.new()
	cl.add_child(loading)
	add_child(cl)
	await get_tree().process_frame
	await get_tree().process_frame

	WorldGen.load_data()
	_build_environment()
	world = preload("res://scripts/world.gd").new()
	world.name = "World"
	add_child(world)
	world.build()

	hero = preload("res://scripts/hero.gd").new()
	hero.name = "Hero"
	add_child(hero)
	hero.global_position = Vector3(0, WorldGen.ground_at(0, 8) + 0.1, 8)

	rig = preload("res://scripts/camera_rig.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = hero

	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.touch.rig = rig
	hud.minimap.setup(world, hero)
	hero.touch = hud.touch
	hero.rig = rig
	hud.touch.attack_pressed.connect(hero.attack)
	hud.touch.act_pressed.connect(func(): if _act.is_valid(): _act.call())

	cl.queue_free()
	hud.banner(WorldGen.TOWN_NAME, "Godot-версия · этап 1: мир, город и герой")

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = WorldGen.hex(0x3d7fd1)
	sky_mat.sky_horizon_color = WorldGen.hex(0xcfe2ee)
	sky_mat.ground_horizon_color = WorldGen.hex(0xcfe2ee)
	sky_mat.ground_bottom_color = WorldGen.hex(0x6b5a3a)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = WorldGen.hex(0xb9d3e6)
	env.fog_density = 1.0
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 420.0
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = WorldGen.hex(0xfff1d6)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	sun.look_at_from_position(Vector3(80, 140, 50), Vector3.ZERO)

func _process(_dt: float) -> void:
	if not hero:
		return
	var p := hero.global_position
	# Название места: город или долина
	var zone := "town" if WorldGen.town_dist(p.x, p.z) < WorldGen.TOWN_WALL else "valley"
	if zone != _zone:
		if _zone != "" and zone == "town":
			hud.banner(WorldGen.TOWN_NAME, "Под защитой крепостных стен")
		_zone = zone
		hud.set_status(WorldGen.TOWN_NAME if zone == "town" else "Долина")
	# Что можно сделать рядом
	var text := ""
	_act = Callable()
	if Vector2(p.x, p.z).distance_to(WorldGen.FORGE_POS) < 3.4:
		text = "⚒ Кузница"
		_act = func(): hud.banner("Кузница", "Улучшение и объединение оружия появятся позже")
	for e in world.entrances:
		var door: Vector3 = e["door"]
		if Vector2(p.x - door.x, p.z - door.z).length() < 3.2:
			text = "Войти: " + e["name"]
			_act = func(): hud.banner(e["name"], "Подземелья появятся на следующем этапе переноса")
	hud.touch.act_text = text

## Точка входа: свет и небо, мир, герой, монстры, добыча, камера, интерфейс и взаимодействия.
extends Node3D

var world: Node3D
var hero: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var enemies: Node3D
var loot: Node3D
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
	Fx.root = self

	hero = preload("res://scripts/hero.gd").new()
	hero.name = "Hero"
	add_child(hero)
	hero.global_position = Vector3(0, WorldGen.ground_at(0, 8) + 0.1, 8)
	hero.campfire_pos = world.campfire.position

	loot = preload("res://scripts/loot.gd").new()
	loot.name = "Loot"
	loot.hero = hero
	add_child(loot)
	enemies = preload("res://scripts/enemies.gd").new()
	enemies.name = "Enemies"
	enemies.hero = hero
	enemies.loot = loot
	add_child(enemies)
	enemies.spawn_all()
	hero.enemies = enemies

	rig = preload("res://scripts/camera_rig.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = hero

	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.touch.rig = rig
	hud.camera = rig.camera
	hud.enemies = enemies
	hud.minimap.setup(world, hero)
	hud.minimap.enemies = enemies
	hero.touch = hud.touch
	hero.rig = rig
	hud.touch.attack_pressed.connect(hero.attack)
	hud.touch.potion_pressed.connect(hero.drink_potion)
	hud.touch.skills_pressed.connect(hud.open_skills)
	hud.touch.skill_pressed.connect(hero.use_skill)
	hud.touch.act_pressed.connect(func(): if _act.is_valid(): _act.call())
	hero.hurt.connect(func(_d): hud.flash_hurt())
	hero.died.connect(_on_hero_died)
	Game.leveled_up.connect(_on_level_up)
	Game.message.connect(func(t, c, p): Fx.text(t, p, c))

	cl.queue_free()
	hud.banner(WorldGen.TOWN_NAME, "Godot-версия · этап 2: монстры, бой, умения, уровни, добыча")

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

func _on_level_up(level: int) -> void:
	var sub := "Здоровье +15 · Урон +4"
	if level <= SkillDefs.MAX_SKILL_LEVEL:
		sub += " · +1 очко навыка ⭐"
	hud.banner("Уровень %d!" % level, sub)
	Fx.text("Уровень %d!" % level, hero.global_position, Color("#ffd479"), true)
	Fx.ring(hero.global_position + Vector3(0, 0.1, 0), Color("#ffd060"), 3.0, 1.2, true)

## Гибель героя: через пару секунд он очнётся у костра, монстры вернутся на места
func _on_hero_died() -> void:
	hud.banner("Ты пал в бою", "Очнёшься у костра…")
	await get_tree().create_timer(1.8).timeout
	hud.fade(func():
		var c: Vector3 = world.campfire.position
		hero.respawn(Vector3(c.x - 2.5, WorldGen.ground_at(c.x - 2.5, c.z + 2.5) + 0.1, c.z + 2.5))
		hero.facing = PI * 0.75
		rig.yaw = hero.facing + PI
		enemies.reset_all()
		hud.banner(WorldGen.TOWN_NAME, "Отдохни у костра и попробуй снова"))

func _process(_dt: float) -> void:
	if not hero:
		return
	var p := hero.global_position
	# Название места: город или долина; счётчик побед
	var zone := "town" if WorldGen.town_dist(p.x, p.z) < WorldGen.TOWN_WALL else "valley"
	if zone != _zone:
		if _zone != "" and zone == "town":
			hud.banner(WorldGen.TOWN_NAME, "Под защитой крепостных стен")
		_zone = zone
	hud.set_status("%s  ·  ⚔ %d" % [WorldGen.TOWN_NAME if zone == "town" else "Долина", Game.kills])
	# Кнопки: зелья, очки навыков, умения и их перезарядка
	var t: Control = hud.touch
	t.potions = Game.potions()
	t.free_points = Game.points_free()
	for id in ["whirl", "dash"]:
		t.skill_ranks[id] = Game.rank(id)
		t.cd_left[id] = hero.cd[id]
		t.cd_total[id] = hero.cooldown_total(id)
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
	t.act_text = text if not hero.dead else ""

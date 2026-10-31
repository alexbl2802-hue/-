## Точка входа: свет и небо, мир, подземелья, герой, монстры, добыча, камера,
## интерфейс, главное меню и взаимодействия (войти, выйти, сундук, кузница).
extends Node3D

var world: Node3D
var dungeons: Array = []
var hero: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var enemies: Node3D
var loot: Node3D
var mode := -1          # -1 — поверхность, 0/1 — подземелье
var _env: Environment
var _sun: DirectionalLight3D
var _hero_light: OmniLight3D
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
	for i in DungeonDefs.LIST.size():
		var d: Node3D = preload("res://scripts/dungeon.gd").new()
		add_child(d)
		d.build(DungeonDefs.LIST[i], i)
		d.visible = false
		if Game.chests.has(i):
			d.open_chest(true)
		dungeons.append(d)

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
	for d in dungeons:
		enemies.spawn_dungeon(d)
	hero.enemies = enemies

	rig = preload("res://scripts/camera_rig.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = hero
	# Фонарь «за плечом» — только в подземельях
	_hero_light = OmniLight3D.new()
	_hero_light.light_color = WorldGen.hex(0xffd9a0)
	_hero_light.light_energy = 0.9
	_hero_light.omni_range = 9.0
	_hero_light.position = Vector3(0, 0.8, 2.0)
	_hero_light.visible = false
	rig.add_child(_hero_light)

	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.hero = hero
	hud.touch.rig = rig
	hud.camera = rig.camera
	hud.enemies = enemies
	hud.inventory.hero = hero
	hud.minimap.setup(world, hero)
	hud.minimap.enemies = enemies
	hero.touch = hud.touch
	hero.rig = rig
	hud.touch.attack_pressed.connect(hero.attack)
	hud.touch.potion_pressed.connect(hero.drink_potion)
	hud.touch.skills_pressed.connect(hud.open_skills)
	hud.touch.inventory_pressed.connect(hud.open_inventory)
	hud.touch.menu_pressed.connect(hud.open_menu)
	hud.touch.skill_pressed.connect(hero.use_skill)
	hud.touch.act_pressed.connect(func(): if _act.is_valid(): _act.call())
	hud.menu.started.connect(_on_started)
	hero.hurt.connect(func(_d): hud.flash_hurt())
	hero.died.connect(_on_hero_died)
	Game.leveled_up.connect(_on_level_up)
	Game.message.connect(func(t, c, p): Fx.text(t, p, c))

	cl.queue_free()
	hud.open_menu()

func _on_started(first: bool) -> void:
	if first:
		hud.banner("Добро пожаловать, %s!" % Game.player_name, "Камнеград — твой дом. За стенами ждут чудовища и два подземелья")
	else:
		hud.banner("С возвращением, %s!" % Game.player_name, WorldGen.TOWN_NAME)

func _build_environment() -> void:
	_env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = WorldGen.hex(0x3d7fd1)
	sky_mat.sky_horizon_color = WorldGen.hex(0xcfe2ee)
	sky_mat.ground_horizon_color = WorldGen.hex(0xcfe2ee)
	sky_mat.ground_bottom_color = WorldGen.hex(0x6b5a3a)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_density = 1.0
	_env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = WorldGen.hex(0xfff1d6)
	_sun.light_energy = 1.3
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 90.0
	add_child(_sun)
	_sun.look_at_from_position(Vector3(80, 140, 50), Vector3.ZERO)
	_apply_env(-1)

## Свет, туман и фон: небо над долиной, полумрак склепа, мягкий синий свет пещеры
func _apply_env(m: int) -> void:
	if m < 0:
		_env.background_mode = Environment.BG_SKY
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.ambient_light_energy = 0.9
		_env.fog_light_color = WorldGen.hex(0xb9d3e6)
		_env.fog_depth_begin = 90.0
		_env.fog_depth_end = 420.0
		_sun.visible = true
	else:
		var cave: bool = DungeonDefs.LIST[m]["style"] == "cave"
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = WorldGen.hex(0x0b0d18 if cave else 0x050407)
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = WorldGen.hex(0x8c9ad6 if cave else 0x6a6a90)
		_env.ambient_light_energy = 0.75 if cave else 0.3
		_env.fog_light_color = _env.background_color
		_env.fog_depth_begin = 10.0 if cave else 6.0
		_env.fog_depth_end = 60.0 if cave else 42.0
		_sun.visible = false
	if _hero_light:
		_hero_light.visible = m >= 0

func _set_mode(m: int) -> void:
	mode = m
	hero.underground = m >= 0
	world.visible = m < 0
	for i in dungeons.size():
		dungeons[i].visible = i == m
	_apply_env(m)
	hud.minimap.dungeon = dungeons[m] if m >= 0 else null
	_zone = ""

func enter_dungeon(i: int) -> void:
	hero.busy = true
	hud.fade(func():
		var d: Node3D = dungeons[i]
		_set_mode(i)
		hero.global_position = d.start_pos + Vector3(0, 0.2, 0)
		hero.velocity = Vector3.ZERO
		hero.facing = d.start_yaw
		rig.yaw = d.start_yaw + PI
		rig.pitch = 0.3
		rig.dist = minf(rig.dist, 6.0)
		rig.snap()
		enemies.reset_all()
		hero.busy = false
		hud.banner(d.def["name"], d.def["sub"]))

func exit_dungeon() -> void:
	hero.busy = true
	var e: Dictionary = world.entrances[mode]
	hud.fade(func():
		_set_mode(-1)
		var p: Vector3 = e["door"] + e["dir"] * 4.0
		hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
		hero.velocity = Vector3.ZERO
		hero.facing = atan2(e["dir"].x, e["dir"].z)
		rig.yaw = hero.facing + PI
		rig.snap()
		hero.busy = false
		hud.banner("Долина", "Снова под открытым небом"))

func open_chest(i: int) -> void:
	var d: Node3D = dungeons[i]
	d.open_chest()
	Game.chests.append(i)
	var c: Vector3 = d.chest["pos"]
	loot.drop("gold", randi_range(40, 64), c)
	loot.drop("potion", 2, c)
	for id in d.def["chest_loot"]:
		loot.drop(id, 1, c)
	Game.save_game()
	var n := Game.chests.size()
	hud.banner("Сокровище найдено!", "Все сокровища собраны — ты настоящий искатель приключений!" if n >= dungeons.size() else "Осталось ещё одно подземелье")

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
		_set_mode(-1)
		var c: Vector3 = world.campfire.position
		hero.respawn(Vector3(c.x - 2.5, WorldGen.ground_at(c.x - 2.5, c.z + 2.5) + 0.1, c.z + 2.5))
		hero.facing = PI * 0.75
		rig.yaw = hero.facing + PI
		rig.snap()
		enemies.reset_all()
		hud.banner(WorldGen.TOWN_NAME, "Отдохни у костра и попробуй снова"))

func _process(_dt: float) -> void:
	if not hero:
		return
	var p := hero.global_position
	# Название места и счётчики
	var place: String
	if mode >= 0:
		place = dungeons[mode].def["name"]
	else:
		var zone := "town" if WorldGen.town_dist(p.x, p.z) < WorldGen.TOWN_WALL else "valley"
		if zone != _zone:
			if _zone != "" and zone == "town":
				hud.banner(WorldGen.TOWN_NAME, "Под защитой крепостных стен")
			_zone = zone
		place = WorldGen.TOWN_NAME if zone == "town" else "Долина"
	hud.set_status("%s  ·  Сокровища: %d/%d  ·  ⚔ %d" % [place, Game.chests.size(), dungeons.size(), Game.kills])
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
	if not hero.busy and not hero.dead:
		if mode < 0:
			if Vector2(p.x, p.z).distance_to(WorldGen.FORGE_POS) < 3.4:
				text = "⚒ Кузница"
				_act = hud.open_forge
			for i in world.entrances.size():
				var door: Vector3 = world.entrances[i]["door"]
				if Vector2(p.x - door.x, p.z - door.z).length() < 3.2:
					text = "Войти: " + world.entrances[i]["name"]
					_act = enter_dungeon.bind(i)
		else:
			var d: Node3D = dungeons[mode]
			if Vector2(p.x - d.start_pos.x, p.z - d.start_pos.z).length() < 1.8:
				text = "Подняться на поверхность"
				_act = exit_dungeon
			var c: Vector3 = d.chest["pos"]
			if not d.chest["opened"] and Vector2(p.x - c.x, p.z - c.z).length() < 2.2:
				text = "Открыть сундук"
				_act = open_chest.bind(mode)
	t.act_text = text

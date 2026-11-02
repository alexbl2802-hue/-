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
var mode := -1          # -1 — поверхность, -2 — второй мир (Плато ветров), 0… — подземелья и этажи
const WORLD2 := -2
var world2: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _hero_light: OmniLight3D
var _zone := ""
var _act := Callable()
var day_night: DayNight

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
	var defs := DungeonDefs.all()
	for i in defs.size():
		var d: Node3D = preload("res://scripts/dungeon.gd").new()
		add_child(d)
		d.build(defs[i], i)
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
	# Второй мир над вершиной башни
	world2 = preload("res://scripts/world2.gd").new()
	add_child(world2)
	world2.build()
	world2.visible = false
	enemies.spawn_world2(world2)
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
	enemies.boss_killed.connect(_on_boss_killed)
	Game.message.connect(func(t, c, p): Fx.text(t, hero.global_position if p == Vector3.ZERO else p, c, p == Vector3.ZERO))

	# Настройки: при изменении в окне сразу применяются
	Settings.load_settings()
	hud.menu.settings.changed.connect(apply_settings)
	apply_settings()
	# Смена дня и ночи
	day_night = DayNight.new()
	add_child(day_night)
	day_night.setup(_env, _sun, rig, hud)
	cl.queue_free()
	hud.open_menu()

func _on_started(first: bool) -> void:
	if first:
		hud.banner("Добро пожаловать, %s!" % Game.player_name, "Камнеград — твой дом. За стенами ждут чудовища и два подземелья")
	else:
		hud.banner("С возвращением, %s!" % Game.player_name, WorldGen.TOWN_NAME)

func _build_environment() -> void:
	_env = Environment.new()
	# Небо с облаками и звёздами (shaders/sky.gdshader)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("sky_top_color", WorldGen.hex(0x3d7fd1))
	sky_mat.set_shader_parameter("sky_horizon_color", WorldGen.hex(0xcfe2ee))
	sky_mat.set_shader_parameter("ground_horizon_color", WorldGen.hex(0xcfe2ee))
	sky_mat.set_shader_parameter("ground_bottom_color", WorldGen.hex(0x6b5a3a))
	sky_mat.set_shader_parameter("clouds", Mats.noise_texture("clouds"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# Облака движутся — отражения неба обновляем понемногу и в малом размере, чтобы не тратить кадры
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.sky = sky
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_density = 1.0
	_env.fog_sky_affect = 0.0
	# Обработка кадра (цвет и виньетка) — под интерфейсом
	var post := CanvasLayer.new()
	post.layer = -1
	var pr := ColorRect.new()
	pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	pr.material = pm
	post.add_child(pr)
	add_child(post)
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
		_env.fog_depth_end = Settings.VIEW[Settings.view]["fog"]
		_sun.visible = true
	else:
		var def: Dictionary = dungeons[m].def
		var cave: bool = def["style"] == "cave"
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = WorldGen.hex(0x0b0d18 if cave else 0x050407)
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = WorldGen.hex(0x8c9ad6 if cave else 0x6a6a90)
		_env.ambient_light_energy = 0.75 if cave else 0.3
		if def["style"] == "tower":
			# Этаж башни: свет и туман в цветах темы этажа
			_env.background_color = WorldGen.hex(def["fog"])
			_env.ambient_light_color = WorldGen.hex(def["light"])
			_env.ambient_light_energy = 0.75
		_env.fog_light_color = _env.background_color
		_env.fog_depth_begin = 10.0 if cave else 6.0
		_env.fog_depth_end = 60.0 if cave else 42.0
		_sun.visible = false
	if _hero_light:
		_hero_light.visible = m >= 0

## Применить настройки: дальность прорисовки, тени, счётчик кадров
func apply_settings() -> void:
	var v: Dictionary = Settings.VIEW[Settings.view]
	rig.camera.far = v["far"]
	world.set_rock_view(v["rocks"])
	if mode < 0:
		_env.fog_depth_end = v["fog"]
	_sun.shadow_enabled = Settings.shadows
	if day_night:
		day_night.apply()
	hud.show_fps(Settings.show_fps)

func _set_mode(m: int) -> void:
	mode = m
	hero.underground = m >= 0
	world.visible = m == -1
	if world2:
		world2.visible = m == WORLD2
	hud.minimap.visible = m != WORLD2   # у плато пока нет карты
	hero.in_world2 = m == WORLD2
	# Костёр, у которого герой отдыхает (лечится быстрее)
	hero.campfire_pos = world2.campfire_pos + world2.ORIGIN if m == WORLD2 and world2 else world.campfire.position
	for i in dungeons.size():
		dungeons[i].visible = i == m
	_apply_env(-1 if m == WORLD2 else m)
	if day_night:
		day_night.surface = m < 0
		day_night.apply()
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
		if d.tower:
			d.set_gate(false)
			d.set_stairs(enemies.boss_beaten(i))
		hero.busy = false
		hud.banner(d.def["name"], d.def["sub"]))

func exit_dungeon() -> void:
	hero.busy = true
	var e: Dictionary = world.tower if dungeons[mode].tower else world.entrances[mode]
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

## Второй мир: с вершины башни — на Плато ветров, к порталу в деревне
func enter_world2() -> void:
	hero.busy = true
	hud.fade(func():
		_set_mode(WORLD2)
		hero.global_position = world2.start_pos + world2.ORIGIN
		hero.velocity = Vector3.ZERO
		hero.facing = PI
		rig.yaw = hero.facing + PI
		rig.pitch = 0.35
		rig.snap()
		enemies.reset_all()
		hero.busy = false
		hud.banner(world2.NAME, "Новый мир над вершиной башни. Здесь живут новые чудовища"))

## Из второго мира — порталом к подножию башни
func leave_world2() -> void:
	hero.busy = true
	var e: Dictionary = world.tower
	hud.fade(func():
		_set_mode(-1)
		var p: Vector3 = e["door"] + e["dir"] * 4.0
		hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
		hero.velocity = Vector3.ZERO
		hero.facing = atan2(e["dir"].x, e["dir"].z)
		rig.yaw = hero.facing + PI
		rig.snap()
		hero.busy = false
		hud.banner("Долина", "Портал вернул тебя к подножию башни"))

## Этаж башни (с 1): вход снизу или подъём по лестнице с предыдущего этажа
func enter_floor(f: int) -> void:
	enter_dungeon(DungeonDefs.floor_index(f))

func _on_boss_killed(e: Node3D) -> void:
	var d: Node3D = dungeons[e.dungeon_idx]
	if d.tower:
		d.set_gate(false)
		d.set_stairs(true)
		if d.def["floor"] < DungeonDefs.TOWER.size():
			hud.banner("%s повержен!" % e.T["name"], "Ворота открыты · путь на этаж %d свободен" % (d.def["floor"] + 1))
		else:
			hud.banner("%s повержен!" % e.T["name"], "Башня покорена! Лестница ведёт в новый мир — %s" % world2.NAME)
	else:
		hud.banner("%s повержен!" % e.T["name"], "Сундук с сокровищем открыт")

func open_chest(i: int) -> void:
	var d: Node3D = dungeons[i]
	d.open_chest()
	Game.chests.append(i)
	var c: Vector3 = d.chest["pos"]
	loot.drop("gold", randi_range(40, 64), c)
	loot.drop("essence", 4, c)
	loot.drop("shard", randi_range(3, 5), c)
	for id in d.def["chest_loot"]:
		loot.drop(id, 1, c)
	Game.save_game()
	var n := Game.chests.size()
	hud.banner("Сокровище найдено!", "Все сокровища собраны — ты настоящий искатель приключений!" if n >= DungeonDefs.LIST.size() else "Осталось ещё одно подземелье")

func _on_level_up(level: int) -> void:
	var sub := "Здоровье +15 · Урон +4 · +1 очко навыка"
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
	# Вход в город — надпись по центру; вверху — ник и уровень героя
	if mode < 0:
		var zone := "town" if WorldGen.town_dist(p.x, p.z) < WorldGen.TOWN_WALL else "valley"
		if zone != _zone:
			if _zone != "" and zone == "town":
				hud.banner(WorldGen.TOWN_NAME, "Под защитой крепостных стен")
			_zone = zone
	hud.set_status("%s  ·  Ур. %d" % [Game.player_name if Game.player_name != "" else "Странник", Game.level])
	# Кнопки: зелья, очки навыков, умения и их перезарядка
	var t: Control = hud.touch
	t.potions = Game.potions()
	t.free_points = Game.points_free() + Game.stat_points_free()
	t.dash_icon = SkillDefs.DASH_FORMS[SkillDefs.dash_form(Game.skills)]["icon"]
	var art: String = hero.art_id()
	t.art_icon = SkillDefs.find(art)["icon"] if art != "" and Game.rank(art) > 0 else ""
	t.cd_left["art"] = hero.cd["art"]
	t.cd_total["art"] = hero.cooldown_total("art")
	for id in ["whirl", "dash", "horizontal"]:
		t.skill_ranks[id] = Game.rank(id)
		t.cd_left[id] = hero.cd[id]
		t.cd_total[id] = hero.cooldown_total(id)
	t.cd_left["dodge"] = hero.cd["dodge"]
	t.cd_total["dodge"] = hero.cooldown_total("dodge")
	# Что можно сделать рядом
	var text := ""
	_act = Callable()
	if not hero.busy and not hero.dead:
		if mode == WORLD2:
			var o: Vector3 = world2.ORIGIN
			if Vector2(p.x - o.x - world2.portal_pos.x, p.z - o.z - world2.portal_pos.z).length() < 3.0:
				text = "Спуститься к подножию башни"
				_act = leave_world2
			if Vector2(p.x - o.x - world2.forge_pos.x, p.z - o.z - world2.forge_pos.z).length() < 3.6:
				text = "⚒ Кузница"
				_act = hud.open_forge
			var af: Vector3 = Alchemist.front(world2.alchemist_pos, PI / 2.0)
			if Vector2(p.x - o.x - af.x, p.z - o.z - af.z).length() < Alchemist.SHOP_RADIUS:
				text = "⚗ Алхимик"
				_act = hud.open_alchemist
		elif mode < 0:
			var al := Vector3(WorldGen.ALCHEMIST_POS.x, 0, WorldGen.ALCHEMIST_POS.y)
			if Vector2(p.x, p.z).distance_to(Vector2(Alchemist.front(al, WorldGen.ALCHEMIST_YAW).x, Alchemist.front(al, WorldGen.ALCHEMIST_YAW).z)) < Alchemist.SHOP_RADIUS:
				text = "⚗ Алхимик"
				_act = hud.open_alchemist
			if Vector2(p.x, p.z).distance_to(WorldGen.FORGE_POS) < 3.4:
				text = "⚒ Кузница"
				_act = hud.open_forge
			for i in world.entrances.size():
				var door: Vector3 = world.entrances[i]["door"]
				if Vector2(p.x - door.x, p.z - door.z).length() < 3.2:
					text = "Войти: " + world.entrances[i]["name"]
					_act = enter_dungeon.bind(i)
			var td: Vector3 = world.tower["door"]
			if Vector2(p.x - td.x, p.z - td.z).length() < 3.2:
				var f: int = Game.tower_unlocked()
				text = "Войти в башню: этаж %d" % f
				_act = enter_floor.bind(f)
		else:
			var d: Node3D = dungeons[mode]
			if Vector2(p.x - d.start_pos.x, p.z - d.start_pos.z).length() < 1.8:
				text = "Выйти из башни" if d.tower else "Подняться на поверхность"
				_act = exit_dungeon
			if d.tower:
				_tower_update(d, p)
				var boss: Node3D = enemies.boss_of(mode)
				if boss and not d.gate_closed:
					for g in d.gate_cells:
						var gc: Vector3 = d.cell_center(g.x, g.y)
						if Vector2(p.x - gc.x, p.z - gc.z).length() < 7.0:
							text = "⚔ Страж этажа: %s · Ур. %d" % [boss.T["name"], boss.level]
				if d.stairs_open and Vector2(p.x - d.stairs_front.x, p.z - d.stairs_front.z).length() < 2.4:
					if d.def["floor"] < DungeonDefs.TOWER.size():
						text = "Подняться на этаж %d" % (d.def["floor"] + 1)
						_act = enter_floor.bind(d.def["floor"] + 1)
					else:
						text = "Подняться в новый мир: " + world2.NAME
						_act = enter_world2
			var c: Vector3 = d.chest.get("pos", Vector3.INF)
			if d.chest.has("pos") and not d.chest["opened"] and Vector2(p.x - c.x, p.z - c.z).length() < 2.2:
				var boss: Node3D = enemies.boss_of(mode)
				if boss:
					text = "🔒 Сундук стережёт " + boss.T["name"]
				else:
					text = "Открыть сундук"
					_act = open_chest.bind(mode)
	t.act_text = text

## Комната стража: вошёл — ворота опускаются за спиной и не откроются, пока страж жив
func _tower_update(d: Node3D, p: Vector3) -> void:
	var boss: Node3D = enemies.boss_of(mode)
	var inside: bool = d.in_room(p)
	if boss and inside and not d.gate_closed:
		d.set_gate(true)
		hud.banner("Страж этажа: %s" % boss.T["name"], "Ур. %d · Ворота закрылись — назад пути нет" % boss.level)
	elif d.gate_closed and not boss:
		d.set_gate(false)

## Все монстры долины. Монстры далеко от героя «спят», чтобы телефон не тратил силы.
extends Node3D

const ACTIVE_RANGE := CardinalConfig.ACTIVE_RANGE

var hero: Node3D
var loot: Node3D
var list: Array = []
signal boss_killed(e: Node3D)
var _check_t := 0.0

func spawn_all() -> void:
	var script := preload("res://scripts/enemy.gd")
	for e in WorldGen.props["enemies"]:
		var en: CharacterBody3D = script.new()
		var x: float = e[1]
		var z: float = e[2]
		en.setup(e[0], Vector3(x, WorldGen.ground_at(x, z) + 0.3, z), hero)
		add_child(en)
		list.append(en)
	_update_active()

## Монстры подземелья: скелеты/пауки и кобольды — по двое на каждом месте появления
func spawn_dungeon(d: Node3D) -> void:
	var script := preload("res://scripts/enemy.gd")
	var lvl: int = d.def.get("level", 1)
	for sp in d.spawns:
		for k in (1 if d.tower else 2):   # на этажах башни — по одному, зато сильнее
			var en: CharacterBody3D = script.new()
			en.in_dungeon = true
			var off := Vector3(-0.9, 0, 0.5) if k == 0 else Vector3(0.9, 0, -0.5)
			if d.tower:
				off = Vector3.ZERO
			en.setup(sp[0], sp[1] + off + Vector3(0, 0.3, 0), hero, lvl)
			en.dungeon_idx = d.index
			add_child(en)
			list.append(en)
	# Босс стережёт сундук: стоит между сундуком и входом. Побеждённый больше не появляется
	if d.tower and not boss_beaten(d.index):
		spawn_guard(d)
	elif d.def.has("boss") and not boss_beaten(d.index):
		var c: Vector3 = d.chest["pos"]
		var to_start: Vector3 = d.start_pos - c
		to_start.y = 0.0
		var b: CharacterBody3D = script.new()
		b.in_dungeon = true
		b.dungeon_idx = d.index
		b.setup(d.def["boss"], c + to_start.normalized() * 3.5 + Vector3(0, 0.3, 0), hero, lvl + 2)
		add_child(b)
		list.append(b)

## Страж этажа башни: ждёт в своей комнате за воротами
func spawn_guard(d: Node3D) -> Node3D:
	var g: CharacterBody3D = preload("res://scripts/enemy.gd").new()
	g.in_dungeon = true
	g.dungeon_idx = d.index
	g.setup(d.def["boss"], d.boss_pos + Vector3(0, 0.3, 0), hero, int(d.def.get("level", 1)) + 2)
	g.guard_room = d
	add_child(g)
	list.append(g)
	return g

## Монстры Плато ветров (второй мир)
func spawn_world2(w2: Node3D) -> void:
	var script := preload("res://scripts/enemy.gd")
	for sp in w2.spawns:
		var en: CharacterBody3D = script.new()
		en.world2 = true
		en.setup(sp[0], sp[1], hero, sp[2])
		add_child(en)
		list.append(en)

## Побеждён ли страж этажа
static func boss_beaten(idx: int) -> bool:
	return Game.bosses.has(idx)

## Сколько обычных монстров (без босса) ещё живо в подземелье
func monsters_left(idx: int) -> int:
	var n := 0
	for e in list:
		if e.dungeon_idx == idx and not e.dead and not e.T.get("boss", false):
			n += 1
	return n

## Живой босс подземелья или null
func boss_of(idx: int) -> Node3D:
	for e in list:
		if e.T.get("boss", false) and e.dungeon_idx == idx and not e.dead:
			return e
	return null

func on_boss_killed(e: Node3D) -> void:
	if not Game.bosses.has(e.dungeon_idx):
		Game.bosses.append(e.dungeon_idx)
	Game.save_game()
	boss_killed.emit(e)

func _process(dt: float) -> void:
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = 0.5
		_update_active()

## Бодрствуют монстры в радиусе ACTIVE_RANGE, но не больше лимита CARDINAL (Cardinal.max_active_mobs) —
## ближайшие к герою; боссы в радиусе — без лимита; мёртвые (ждут возвращения) — всегда
func _update_active() -> void:
	if not hero:
		return
	var near: Array = []
	for e in list:
		var d: float = e.global_position.distance_to(hero.global_position)
		if e.dead:
			e.set_active(true)   # мёртвые ждут своего часа, чтобы вернуться
		elif e.T.get("boss", false):
			e.set_active(d < ACTIVE_RANGE)
		elif d < ACTIVE_RANGE:
			near.append([d, e])
		else:
			e.set_active(false)
	near.sort_custom(func(a, b): return a[0] < b[0])
	var cap: int = Cardinal.max_active_mobs
	for i in near.size():
		near[i][1].set_active(i < cap)


func on_enemy_killed(e: Node3D) -> void:
	if loot:
		# Вся добыча — один расчёт CARDINAL (CardinalLootManager.roll_enemy внутри loot.roll);
		# второй розыгрыш за то же убийство не делаем
		loot.roll(e.type, e.global_position)
	CardinalDirector.on_kill()

## Вернуть живых монстров на свои места (после гибели героя)
func reset_all() -> void:
	for e in list:
		e.reset_home()

func alive_near(pos: Vector3, radius: float) -> Array:
	var out := []
	for e in list:
		if not e.dead and e.global_position.distance_to(pos) < radius:
			out.append(e)
	return out

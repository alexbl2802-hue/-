## Все монстры долины. Монстры далеко от героя «спят», чтобы телефон не тратил силы.
extends Node3D

const ACTIVE_RANGE := 110.0

var hero: Node3D
var loot: Node3D
var list: Array = []
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

## Монстры подземелья: скелеты/пауки и кобольды
func spawn_dungeon(d: Node3D) -> void:
	var script := preload("res://scripts/enemy.gd")
	for sp in d.spawns:
		var en: CharacterBody3D = script.new()
		en.in_dungeon = true
		en.setup(sp[0], sp[1] + Vector3(0, 0.3, 0), hero)
		add_child(en)
		list.append(en)

func _process(dt: float) -> void:
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = 0.5
		_update_active()

func _update_active() -> void:
	if not hero:
		return
	for e in list:
		var on: bool = e.global_position.distance_to(hero.global_position) < ACTIVE_RANGE or (e.dead and e.visible)
		if e.dead and not e.visible:
			on = true  # мёртвые ждут своего часа, чтобы вернуться
		e.set_active(on)

func on_enemy_killed(e: Node3D) -> void:
	if loot:
		loot.roll(e.type, e.global_position)

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

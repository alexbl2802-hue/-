extends Node3D
class_name CardinalSpawnDirector
## Прикрепите к узлу сцены. Назначьте сцены мобов в инспекторе.
@export var mob_scenes: Array[PackedScene] = []
@export var boss_scenes: Array[PackedScene] = []
@export var spawn_interval := 8.0
@export var spawn_radius := 20.0
@export var enable_boss_spawning := false
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
func _ready() -> void:
    _rng.randomize()
func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < maxf(0.5, spawn_interval): return
    _elapsed = 0.0
    _spawn_from(mob_scenes, false)
func _spawn_from(scenes: Array[PackedScene], boss: bool) -> void:
    if scenes.is_empty() or not Cardinal.can_spawn(boss): return
    var scene := scenes[_rng.randi_range(0, scenes.size() - 1)]
    if scene == null: return
    var angle := _rng.randf_range(0.0, TAU)
    var radius := _rng.randf_range(3.0, maxf(3.0, spawn_radius))
    var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
    Cardinal.spawn_entity(scene, get_tree().current_scene, global_position + offset, boss)
func spawn_boss() -> void:
    if enable_boss_spawning: _spawn_from(boss_scenes, true)

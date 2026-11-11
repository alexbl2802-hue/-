extends Node
## Cardinal: центральный диспетчер. Добавьте как Autoload с именем Cardinal.
signal issue_detected(code: String, details: String)
signal issue_recovered(code: String)
@export var enabled: bool = true
## Лимит бодрствующих монстров (ближайших к герою). Значения — из CardinalConfig (CARDINAL 4.0).
@export var max_active_mobs: int = CardinalConfig.ACTIVE_MOBS_DEFAULT
## Сколько монстров может быть зарегистрировано (созданы заранее, вдали «спят»)
var max_registered_mobs: int = CardinalConfig.REGISTERED_MOBS_MAX
@export var difficulty: float = 1.0
var _mobs: Array[Node] = []
var _bosses: Array[Node] = []
var _chests: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _monitor_accumulator := 0.0

func _ready() -> void:
    _rng.randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
    if not enabled: return
    _monitor_accumulator += delta
    if _monitor_accumulator >= 2.0:
        _monitor_accumulator = 0.0
        _cleanup_registry()
        _monitor_health()

func register_mob(mob: Node, boss: bool = false) -> void:
    if not is_instance_valid(mob): return
    var registry := _bosses if boss else _mobs
    if not registry.has(mob): registry.append(mob)

func register_chest(chest: Node) -> void:
    if is_instance_valid(chest) and not _chests.has(chest): _chests.append(chest)

func unregister_entity(entity: Node) -> void:
    _mobs.erase(entity)
    _bosses.erase(entity)
    _chests.erase(entity)

func can_spawn(boss: bool = false) -> bool:
    if not enabled: return false
    return _bosses.size() < CardinalConfig.BOSSES_MAX if boss else _mobs.size() < max_registered_mobs

func spawn_entity(scene: PackedScene, parent: Node, at: Vector3, boss: bool = false) -> Node3D:
    if scene == null or not is_instance_valid(parent) or not can_spawn(boss): return null
    var entity := scene.instantiate()
    if not entity is Node3D:
        issue_detected.emit('INVALID_SCENE', 'Ожидается Node3D')
        entity.free()
        return null
    parent.add_child(entity)
    entity.global_position = at
    register_mob(entity, boss)
    return entity

func _cleanup_registry() -> void:
    for registry in [_mobs, _bosses, _chests]:
        for i in range(registry.size() - 1, -1, -1):
            if not is_instance_valid(registry[i]) or registry[i].is_queued_for_deletion():
                registry.remove_at(i)

func _monitor_health() -> void:
    if max_active_mobs < CardinalConfig.ACTIVE_MOBS_MIN:
        issue_detected.emit('INVALID_LIMIT', 'Лимит бодрствующих монстров меньше %d' % CardinalConfig.ACTIVE_MOBS_MIN)
        max_active_mobs = CardinalConfig.ACTIVE_MOBS_MIN
        issue_recovered.emit('INVALID_LIMIT')
    if not is_finite(difficulty) or difficulty < CardinalConfig.DIFFICULTY_MIN or difficulty > CardinalConfig.DIFFICULTY_MAX:
        issue_detected.emit('INVALID_DIFFICULTY', 'Сложность вне допустимого диапазона')
        difficulty = 1.0
        issue_recovered.emit('INVALID_DIFFICULTY')

func set_player_performance(deaths: int, wins: int) -> void:
    ## Сглаженное изменение сложности от 0.5 до 3.0.
    var target := clampf(1.0 + float(wins) * 0.035 - float(deaths) * 0.09, CardinalConfig.DIFFICULTY_MIN, CardinalConfig.DIFFICULTY_MAX)
    difficulty = lerpf(difficulty, target, 0.15)

func active_counts() -> Dictionary:
    _cleanup_registry()
    # awake — живые монстры, которые сейчас бодрствуют (их и ограничивает max_active_mobs)
    var awake := 0
    for m in _mobs:
        if m.is_physics_processing() and not m.get('dead'):
            awake += 1
    return {'mobs': _mobs.size(), 'awake': awake, 'bosses': _bosses.size(), 'chests': _chests.size()}

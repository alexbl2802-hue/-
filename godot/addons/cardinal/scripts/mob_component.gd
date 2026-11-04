extends Node
class_name CardinalMobComponent
@export var mob_id := 'wolf'
@export var is_boss := false
@export var base_health := 100.0
var current_health := 100.0
var _dead := false
var _loot := CardinalLootManager.new()
signal died(items: Array)
func _ready() -> void:
    current_health = base_health * Cardinal.difficulty
    Cardinal.register_mob(get_parent(), is_boss)
func take_damage(amount: float) -> void:
    if _dead or not is_finite(amount) or amount <= 0.0: return
    current_health -= amount
    if current_health <= 0.0:
        _dead = true
        var kind := 'boss' if is_boss else 'monster'
        var items := _loot.roll(CardinalLootTables.get_table(kind, mob_id), Cardinal.difficulty, 2 if is_boss else 1)
        died.emit(items)
        Cardinal.unregister_entity(get_parent())
func _exit_tree() -> void:
    Cardinal.unregister_entity(get_parent())

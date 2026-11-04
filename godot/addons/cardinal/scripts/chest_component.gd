extends Node
class_name CardinalChestComponent
signal opened(items: Array)
@export var chest_type := 'common'
var is_open := false
var _loot := CardinalLootManager.new()
func _ready() -> void:
    Cardinal.register_chest(get_parent())
func open_chest() -> Array[Dictionary]:
    if is_open: return []
    is_open = true
    var items := _loot.roll(CardinalLootTables.get_table('chest', chest_type), Cardinal.difficulty, 2)
    opened.emit(items)
    return items
func _exit_tree() -> void:
    if Cardinal != null: Cardinal.unregister_entity(get_parent())

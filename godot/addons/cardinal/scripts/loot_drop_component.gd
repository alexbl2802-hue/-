extends Node
class_name CardinalLootDropComponent
signal loot_generated(items: Array)
@export_enum('monster', 'boss', 'chest') var loot_kind := 'monster'
@export var loot_id := 'wolf'
@export_range(1, 10) var rolls := 1
var _loot := CardinalLootManager.new()
func generate() -> Array[Dictionary]:
    var items := _loot.roll(CardinalLootTables.get_table(loot_kind, loot_id), Cardinal.difficulty, rolls)
    loot_generated.emit(items)
    return items

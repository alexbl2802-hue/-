extends CanvasLayer
class_name CardinalAdminPanel
@export var core: CardinalCore
@export var developer_build := false
var panel: PanelContainer
var status: Label
func _ready() -> void:
 visible = developer_build
 if not developer_build: return
 panel = PanelContainer.new()
 panel.set_anchors_preset(Control.PRESET_CENTER)
 panel.position = Vector2(30, 80)
 add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 var heading := Label.new()
 heading.text = "CARDINAL / DEVELOPER"
 column.add_child(heading)
 status = Label.new()
 column.add_child(status)
 for action in ["Spawn +", "Spawn -", "Loot +", "Loot -", "Close"]:
  var button := Button.new()
  button.text = action
  column.add_child(button)
  button.pressed.connect(_handle.bind(action))
 _refresh()
func _handle(action: String) -> void:
 if core == null: return
 match action:
  "Spawn +": core.set_spawn_multiplier(core.spawn_multiplier + 0.1)
  "Spawn -": core.set_spawn_multiplier(core.spawn_multiplier - 0.1)
  "Loot +": core.set_loot_multiplier(core.loot_multiplier + 0.1)
  "Loot -": core.set_loot_multiplier(core.loot_multiplier - 0.1)
  "Close": visible = false
 _refresh()
func _refresh() -> void:
 if core and status:
  status.text = "Spawn x%.1f | Loot x%.1f | Errors %d" % [core.spawn_multiplier, core.loot_multiplier, core.error_count]
func open_developer_panel() -> void:
 if developer_build: visible = true

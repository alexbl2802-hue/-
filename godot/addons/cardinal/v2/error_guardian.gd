extends Node
class_name CardinalErrorGuardian
@export var core: CardinalCore
@export var monitored_player: Node3D
@export var minimum_y := -100.0
var safe_position := Vector3.ZERO
func _process(_delta: float) -> void:
 if not is_instance_valid(monitored_player): return
 var p := monitored_player.global_position
 if p.is_finite() and p.y >= minimum_y:
  safe_position = p
 else:
  if core: core.report_error("Invalid player position; restoring last safe location")
  monitored_player.global_position = safe_position

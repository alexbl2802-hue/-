extends Node
class_name HybridCardinalAnimateBridge
## Integration adapter: connect these signals to the existing systems; no assumption about their APIs.
signal cardinal_event(event_name: String, data: Dictionary)
signal animate_issue(issue: String, data: Dictionary)
@export var character: HybridCharacter
@export var diagnostics_interval := 5.0
var _elapsed := 0.0
func _ready() -> void:
 if character == null:
  push_warning("Bridge: assign HybridCharacter")
  return
 character.movement_event.connect(_forward_event)
 character.animation_issue.connect(_forward_issue)
func _process(delta: float) -> void:
 if character == null:
  return
 _elapsed += delta
 if _elapsed >= diagnostics_interval:
  _elapsed = 0.0
  cardinal_event.emit("movement_diagnostics", character.get_diagnostics())
func _forward_event(name: String, data: Dictionary) -> void:
 cardinal_event.emit(name, data)
func _forward_issue(name: String, data: Dictionary) -> void:
 animate_issue.emit(name, data)
 cardinal_event.emit("animation_issue", {"type": name, "details": data})

extends Control
class_name HybridMobileJoystick
## Attach to a Control anchored bottom-left; set its size to 180x180.
@export var character: HybridCharacter
@export var radius := 70.0
var _finger := -1
var _axis := Vector2.ZERO
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 queue_redraw()
func _gui_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed and _finger == -1:
   _finger = event.index
   _set_axis_at(event.position)
   accept_event()
  elif not event.pressed and event.index == _finger:
   _finger = -1
   _axis = Vector2.ZERO
   _push()
   accept_event()
 elif event is InputEventScreenDrag and event.index == _finger:
  _set_axis_at(event.position)
  accept_event()
func _set_axis_at(pos: Vector2) -> void:
 _axis = ((pos - size * 0.5) / maxf(radius, 1.0)).limit_length(1.0)
 _push()
func _push() -> void:
 if character != null:
  character.set_mobile_move(_axis)
 queue_redraw()
func _draw() -> void:
 var center := size * 0.5
 draw_circle(center, radius, Color(0.12, 0.15, 0.22, 0.4))
 draw_arc(center, radius, 0.0, TAU, 48, Color(0.8, 0.85, 1.0, 0.6), 2.0)
 draw_circle(center + _axis * radius, 27.0, Color(0.45, 0.75, 1.0, 0.8))

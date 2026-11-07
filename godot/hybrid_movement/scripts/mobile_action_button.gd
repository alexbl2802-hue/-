extends Button
class_name HybridMobileActionButton
@export var character: HybridCharacter
@export_enum("Jump", "Dash", "Attack", "Combat", "Run") var action := 0
func _ready() -> void:
 button_down.connect(_on_down)
 button_up.connect(_on_up)
func _on_down() -> void:
 if character == null:
  return
 match action:
  0: character.request_jump()
  1: character.request_dash()
  2: character.request_attack()
  3: character.toggle_combat()
  4: character.set_mobile_run(true)
func _on_up() -> void:
 if character != null and action == 4:
  character.set_mobile_run(false)

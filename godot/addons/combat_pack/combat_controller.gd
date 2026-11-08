extends Node
class_name AdventureCombatController
## Attach to player. Assign AnimationPlayer and optional shield attachment.
signal attack_started(name: String)
signal block_changed(active: bool, using_shield: bool)
@export var animation_player: AnimationPlayer
@export var shield_attachment: BoneAttachment3D
@export var shield_scene: PackedScene
@export var sword_damage_window_seconds := 0.16
var shield_instance: Node3D
var blocking := false
var busy := false
var _attack_serial := 0

func equip_shield(scene: PackedScene = null) -> void:
    if shield_attachment == null:
        push_warning("Assign shield_attachment to a left forearm/hand BoneAttachment3D")
        return
    unequip_shield()
    var selected := scene if scene != null else shield_scene
    if selected == null:
        return
    shield_instance = selected.instantiate() as Node3D
    if shield_instance == null:
        push_error("Shield scene root must be Node3D")
        return
    shield_attachment.add_child(shield_instance)
    shield_instance.transform = Transform3D.IDENTITY

func unequip_shield() -> void:
    if shield_instance != null:
        shield_instance.queue_free()
        shield_instance = null

func has_shield() -> bool:
    return is_instance_valid(shield_instance) and not shield_instance.is_queued_for_deletion()

func start_block() -> void:
    if busy or blocking:
        return
    blocking = true
    _play("shield_block_start" if has_shield() else "sword_block_start")
    block_changed.emit(true, has_shield())

func hold_block() -> void:
    if blocking:
        var target := "shield_block_loop" if has_shield() else "sword_block_loop"
        if animation_player and animation_player.current_animation != target:
            _play(target)

func receive_block_hit() -> void:
    if blocking:
        _play("shield_block_hit" if has_shield() else "sword_block_hit")

func stop_block() -> void:
    if not blocking:
        return
    blocking = false
    _play("shield_block_end" if has_shield() else "sword_block_end")
    block_changed.emit(false, has_shield())

func attack_whirlwind() -> void:
    _attack("whirlwind")

func attack_horizontal() -> void:
    _attack("horizontal")

func _attack(name: String) -> void:
    if blocking or busy:
        return
    busy = true
    _attack_serial += 1
    var serial := _attack_serial
    attack_started.emit(name)
    _play(name)
    var duration := 0.9 if name == "whirlwind" else 0.55
    await get_tree().create_timer(duration).timeout
    if is_inside_tree() and serial == _attack_serial:
        busy = false

func _play(name: String) -> void:
    if animation_player == null:
        push_warning("Missing AnimationPlayer")
    elif animation_player.has_animation(name):
        animation_player.play(name, 0.08)
    else:
        push_warning("Missing animation: " + name)

extends CharacterBody3D
## Godot 4.x: attach to CharacterBody3D. Assign visual_root to your imported model.
## Actions: dash, move_left, move_right, move_forward, move_back.
@export var visual_root: Node3D
@export var dash_distance := 5.0
@export var dash_duration := 0.13
@export var cooldown := 0.35
@export var camera: Camera3D
@export var collision_mask_for_dash: int = 1
var _busy := false
var _cooling := false
var _last_dir := Vector3.FORWARD

func _physics_process(_delta: float) -> void:
    if Input.is_action_just_pressed("dash") and not _busy and not _cooling:
        var dir := _get_direction()
        _dash(dir)

func _get_direction() -> Vector3:
    var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis := camera.global_transform.basis if camera else global_transform.basis
    var direction := basis.x * axes.x + basis.z * axes.y
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        direction = _last_dir
    else:
        direction = direction.normalized()
        _last_dir = direction
    return direction.normalized()

func _dash(direction: Vector3) -> void:
    _busy = true
    _cooling = true
    var start := global_position
    var target := start + direction * dash_distance
    var query := PhysicsRayQueryParameters3D.create(start + Vector3.UP, target + Vector3.UP, collision_mask_for_dash, [get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        target = hit.position - Vector3.UP - direction * 0.5
    if visual_root:
        visual_root.visible = false
    await get_tree().create_timer(dash_duration).timeout
    global_position = target
    velocity = Vector3.ZERO
    if visual_root:
        visual_root.visible = true
    _busy = false
    await get_tree().create_timer(cooldown).timeout
    _cooling = false

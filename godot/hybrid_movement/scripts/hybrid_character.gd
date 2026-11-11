extends CharacterBody3D
class_name HybridCharacter
## Attach to CharacterBody3D. Add child Node3D named VisualRoot and AnimationPlayer under it.
signal movement_event(event_name: String, details: Dictionary)
signal animation_issue(issue: String, details: Dictionary)

@export_group("References")
@export var visual_root: Node3D
@export var animation_player: AnimationPlayer
@export var camera_pivot: Node3D
@export_group("Movement")
@export var walk_speed := 3.2
@export var run_speed := 6.0
@export var combat_speed := 3.6
@export var acceleration := 15.0
@export var deceleration := 19.0
@export var turn_speed := 12.0
@export var jump_velocity := 5.0
@export var gravity_strength := 18.0
@export var air_control := 0.3
@export_group("Combat")
@export var dash_speed := 13.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.6
@export var attack_lock_duration := 0.36
@export var combo_window := 0.42
@export var max_combo := 3
@export var attack_buffer_seconds := 0.22
@export var dash_steering := false
@export var landing_animation := "Land"
@export var landing_animation_min_fall_speed := 5.0
@export_group("Animation names (rename to match imported clips)")
@export var idle_anim := "Idle"
@export var walk_anim := "Walk"
@export var run_anim := "Run"
@export var combat_idle_anim := "CombatIdle"
@export var combat_move_anim := "CombatMove"
@export var jump_anim := "Jump"
@export var fall_anim := "Fall"
@export var dash_anim := "Dash"
@export var attack_prefix := "Attack"

var combat_mode := false
var input_vector := Vector2.ZERO
var run_requested := false
var _dash_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector3.ZERO
var _attack_left := 0.0
var _combo_left := 0.0
var _combo_index := 0
var _queued_attack := false
var _attack_buffer_left := 0.0
var _fall_speed := 0.0
var _active_animation := ""
var _missing_clips: Dictionary = {}
var _last_grounded := true
var _mobile_vector := Vector2.ZERO
var _mobile_run := false

func _ready() -> void:
 if visual_root == null:
  visual_root = get_node_or_null("VisualRoot") as Node3D
 if animation_player == null:
  animation_player = get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
 if camera_pivot == null:
  camera_pivot = get_viewport().get_camera_3d()
 if visual_root == null:
  animation_issue.emit("missing_visual_root", {})
 if animation_player == null:
  animation_issue.emit("missing_animation_player", {})

func _physics_process(delta: float) -> void:
 _dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
 _combo_left = maxf(0.0, _combo_left - delta)
 _attack_buffer_left = maxf(0.0, _attack_buffer_left - delta)
 _attack_left = maxf(0.0, _attack_left - delta)
 if _attack_left <= 0.0 and _queued_attack:
  _queued_attack = false
  if _attack_buffer_left > 0.0:
   _start_attack()
 if _combo_left <= 0.0 and _attack_left <= 0.0:
  _combo_index = 0
 var keyboard_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
 input_vector = _mobile_vector if _mobile_vector.length_squared() > 0.0025 else keyboard_input
 input_vector = input_vector.limit_length(1.0)
 run_requested = _mobile_run or Input.is_action_pressed("run")
 if Input.is_action_just_pressed("toggle_combat"):
  toggle_combat()
 if Input.is_action_just_pressed("jump"):
  request_jump()
 if Input.is_action_just_pressed("dash"):
  request_dash()
 if Input.is_action_just_pressed("attack"):
  request_attack()
 var direction := _camera_relative_direction(input_vector)
 if _dash_left > 0.0:
  _dash_left = maxf(0.0, _dash_left - delta)
  velocity.x = _dash_direction.x * dash_speed
  velocity.z = _dash_direction.z * dash_speed
 else:
  var speed := combat_speed if combat_mode else (run_speed if run_requested else walk_speed)
  if _attack_left > 0.0:
   speed *= 0.3
  var target := direction * speed * input_vector.length()
  var rate := acceleration if target.length_squared() > 0.001 else deceleration
  if not is_on_floor():
   rate *= air_control
  velocity.x = move_toward(velocity.x, target.x, rate * delta)
  velocity.z = move_toward(velocity.z, target.z, rate * delta)
 if not is_on_floor():
  _fall_speed = maxf(_fall_speed, -velocity.y)
  velocity.y -= gravity_strength * delta
 elif velocity.y < 0.0:
  velocity.y = -0.2
 move_and_slide()
 if is_on_floor() and not _last_grounded:
  movement_event.emit("landed", {"fall_speed": _fall_speed})
  if _fall_speed >= landing_animation_min_fall_speed:
   _play_clip(landing_animation, 0.08)
  _fall_speed = 0.0
 _last_grounded = is_on_floor()
 _update_facing(direction, delta)
 _update_animation()

func _camera_relative_direction(axis: Vector2) -> Vector3:
 var forward := Vector3.FORWARD
 var right := Vector3.RIGHT
 if camera_pivot != null:
  forward = -camera_pivot.global_transform.basis.z
  right = camera_pivot.global_transform.basis.x
  forward.y = 0.0
  right.y = 0.0
  forward = forward.normalized()
  right = right.normalized()
 return (right * axis.x - forward * axis.y).normalized() if axis.length_squared() > 0.0001 else Vector3.ZERO

func _update_facing(direction: Vector3, delta: float) -> void:
 if visual_root == null:
  return
 if _dash_left > 0.0:
  if not dash_steering:
   return
  direction = _dash_direction
 var desired := direction
 if combat_mode and camera_pivot != null:
  desired = -camera_pivot.global_transform.basis.z
  desired.y = 0.0
 if desired.length_squared() < 0.001:
  return
 var angle := atan2(-desired.x, -desired.z)
 visual_root.rotation.y = lerp_angle(visual_root.rotation.y, angle, clampf(turn_speed * delta, 0.0, 1.0))

func request_jump() -> void:
 if is_on_floor() and _dash_left <= 0.0 and _attack_left <= 0.0:
  velocity.y = jump_velocity
  movement_event.emit("jump", {})

func request_dash() -> void:
 if _dash_cooldown_left > 0.0 or _dash_left > 0.0 or _attack_left > 0.0:
  return
 _dash_direction = _camera_relative_direction(input_vector)
 if _dash_direction.length_squared() < 0.001:
  _dash_direction = -global_transform.basis.z
  _dash_direction.y = 0.0
  _dash_direction = _dash_direction.normalized()
 _dash_left = dash_duration
 _dash_cooldown_left = dash_cooldown
 movement_event.emit("dash", {"direction": _dash_direction})

func request_attack() -> void:
 if _dash_left > 0.0:
  return
 if _attack_left > 0.0:
  if _combo_left > 0.0:
   _queued_attack = true
   _attack_buffer_left = attack_buffer_seconds
  return
 _start_attack()

func _start_attack() -> void:
 if _combo_left <= 0.0:
  _combo_index = 0
 _combo_index = (_combo_index % maxi(1, max_combo)) + 1
 _attack_left = attack_lock_duration
 _combo_left = combo_window
 _attack_buffer_left = 0.0
 movement_event.emit("attack_started", {"combo": _combo_index})
 _play_clip(attack_prefix + str(_combo_index), 0.08)

func toggle_combat() -> void:
 combat_mode = not combat_mode
 movement_event.emit("combat_mode_changed", {"enabled": combat_mode})

func set_mobile_move(axis: Vector2) -> void:
 _mobile_vector = axis.limit_length(1.0)

func set_mobile_run(pressed: bool) -> void:
 _mobile_run = pressed

func _update_animation() -> void:
 if _attack_left > 0.0:
  return
 if _dash_left > 0.0:
  _play_clip(dash_anim, 0.08)
 elif not is_on_floor():
  _play_clip(jump_anim if velocity.y > 0.0 else fall_anim, 0.12)
 elif Vector2(velocity.x, velocity.z).length() < 0.25:
  _play_clip(combat_idle_anim if combat_mode else idle_anim, 0.2)
 elif combat_mode:
  _play_clip(combat_move_anim, 0.16)
 else:
  _play_clip(run_anim if run_requested else walk_anim, 0.16)

func _play_clip(clip: String, blend: float) -> void:
 if animation_player == null or clip == _active_animation:
  return
 if not animation_player.has_animation(clip):
  if not _missing_clips.has(clip):
   _missing_clips[clip] = true
   animation_issue.emit("missing_animation_clip", {"clip": clip})
  return
 animation_player.play(clip, blend)
 _active_animation = clip

func get_diagnostics() -> Dictionary:
 return {"combat_mode": combat_mode, "speed": Vector2(velocity.x, velocity.z).length(), "on_floor": is_on_floor(), "animation": _active_animation, "missing_clips": _missing_clips.keys(), "dash_cooldown": _dash_cooldown_left, "combo_index": _combo_index, "attack_buffer": _attack_buffer_left, "fall_speed": _fall_speed}

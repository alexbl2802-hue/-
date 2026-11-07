extends Control
class_name ZemliVirtualJoystick   # в Godot 4.7 есть встроенный VirtualJoystick — имя занято
## Floating multitouch joystick for Godot 4.x (Android).
## Attach to a full-screen Control with Mouse > Filter = Ignore.
## Connect movement_changed(Vector2) to your character movement controller.

signal movement_changed(direction: Vector2)
signal sprint_changed(active: bool)

@export var joystick_radius: float = 92.0
@export var knob_radius: float = 35.0
@export_range(0.0, 0.9, 0.01) var deadzone: float = 0.12
@export_range(0.0, 1.0, 0.01) var walk_threshold: float = 0.45
@export var activation_area_width: float = 0.48
@export var activation_area_height_start: float = 0.35
@export var floating: bool = true
@export var base_opacity: float = 0.43
@export var sprint_double_tap_seconds: float = 0.32
@export var enable_double_tap_sprint: bool = true

var direction: Vector2 = Vector2.ZERO
var intensity: float = 0.0
var is_sprinting: bool = false
var _finger: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _last_tap_ms: int = -100000
var _visible_joystick: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _center = Vector2(size.x * 0.16, size.y * 0.76)
    _knob = _center
    set_process_unhandled_input(true)
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and _finger == -1:
        _center = Vector2(size.x * 0.16, size.y * 0.76)
        _knob = _center
        queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and _finger == -1 and _can_activate(event.position):
            _finger = event.index
            if floating:
                _center = event.position
            _knob = _center
            _visible_joystick = true
            var now := Time.get_ticks_msec()
            var double_tap := enable_double_tap_sprint and now - _last_tap_ms <= int(sprint_double_tap_seconds * 1000.0)
            _last_tap_ms = now
            _set_sprint(double_tap)
            _update_direction(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == _finger:
            _release()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == _finger:
        _update_direction(event.position)
        get_viewport().set_input_as_handled()

func _can_activate(point: Vector2) -> bool:
    return point.x <= size.x * activation_area_width and point.y >= size.y * activation_area_height_start

func _update_direction(point: Vector2) -> void:
    var offset := (point - _center).limit_length(joystick_radius)
    _knob = _center + offset
    intensity = offset.length() / maxf(joystick_radius, 1.0)
    direction = Vector2.ZERO if intensity <= deadzone else offset / joystick_radius
    movement_changed.emit(direction)
    queue_redraw()

func _set_sprint(active: bool) -> void:
    if is_sprinting == active:
        return
    is_sprinting = active
    sprint_changed.emit(active)

func _release() -> void:
    _finger = -1
    _visible_joystick = false
    direction = Vector2.ZERO
    intensity = 0.0
    _knob = _center
    _set_sprint(false)
    movement_changed.emit(Vector2.ZERO)
    queue_redraw()

func _draw() -> void:
    if floating and not _visible_joystick:
        return
    var outer := Color(0.06, 0.12, 0.19, base_opacity)
    var cyan := Color(0.15, 0.84, 1.0, 0.78)
    draw_circle(_center, joystick_radius, outer)
    draw_arc(_center, joystick_radius, 0, TAU, 80, cyan, 3.0, true)
    draw_circle(_knob, knob_radius, Color(0.15, 0.25, 0.32, 0.8))
    draw_arc(_knob, knob_radius, 0, TAU, 48, Color(0.7, 0.96, 1.0, 0.9), 2.0, true)
    if intensity > deadzone:
        draw_line(_center, _knob, Color(0.2, 0.9, 1.0, 0.55), 5.0, true)

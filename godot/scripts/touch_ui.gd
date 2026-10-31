## Сенсорное управление: левая часть экрана — джойстик, правая — камера и щипок,
## кнопки удара, прыжка, бега и действия. Каждое касание отслеживается отдельно,
## поэтому можно одновременно идти, крутить камеру и нажимать кнопки.
extends Control

signal attack_pressed
signal act_pressed

const R := 55.0

var move := Vector2.ZERO
var run := false
var jump := false
var act_text := "":
	set(v):
		if v != act_text:
			act_text = v
			queue_redraw()
var rig: Node3D

var _pts := {}          # индекс касания → позиция
var _btn_touch := {}    # индекс касания → кнопка
var _down := {}         # кнопка → нажата
var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _cam_id := -1
var _pinch_id := -1
var _pinch_d := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _buttons() -> Array:
	var s := size
	return [
		{"id": "attack", "c": Vector2(s.x - 24 - 45.5, s.y - 28 - 45.5), "r": 45.5, "label": "⚔", "fs": 39, "border": Color(1, 0.55, 0.43, 0.75)},
		{"id": "jump", "c": Vector2(s.x - 126 - 33, s.y - 20 - 33), "r": 33.0, "label": "⤒", "fs": 27},
		{"id": "run", "c": Vector2(s.x - 40 - 28, s.y - 130 - 28), "r": 28.0, "label": "🏃", "fs": 23},
	]

func _act_rect() -> Rect2:
	if act_text == "":
		return Rect2()
	var w := get_theme_default_font().get_string_size(act_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 42.0
	return Rect2(size.x - 24 - w, size.y - 198 - 56, w, 56)

func _hit(p: Vector2) -> String:
	if act_text != "" and _act_rect().has_point(p):
		return "act"
	for b in _buttons():
		if p.distance_to(b["c"]) <= b["r"] + 6.0:
			return b["id"]
	return ""

func _press(id: String, down: bool) -> void:
	_down[id] = down
	match id:
		"attack":
			if down: attack_pressed.emit()
		"jump":
			jump = down
		"run":
			if down: run = not run
		"act":
			if down: act_pressed.emit()

func _pinch_dist() -> float:
	return maxf(1.0, (_pts[_cam_id] as Vector2).distance_to(_pts[_pinch_id]))

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var b := _hit(e.position)
			if b != "":
				_btn_touch[e.index] = b
				_press(b, true)
			else:
				_pts[e.index] = e.position
				if e.position.x < size.x * 0.42 and _joy_id == -1:
					_joy_id = e.index
					_joy_origin = e.position
					_joy_knob = Vector2.ZERO
				elif _cam_id == -1:
					_cam_id = e.index
				elif _pinch_id == -1:
					_pinch_id = e.index
					_pinch_d = _pinch_dist()
		else:
			if _btn_touch.has(e.index):
				_press(_btn_touch[e.index], false)
				_btn_touch.erase(e.index)
			_pts.erase(e.index)
			if e.index == _joy_id:
				_joy_id = -1
				move = Vector2.ZERO
				_joy_knob = Vector2.ZERO
			if e.index == _pinch_id:
				_pinch_id = -1
			if e.index == _cam_id:
				_cam_id = _pinch_id
				_pinch_id = -1
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if not _pts.has(e.index):
			return
		var prev: Vector2 = _pts[e.index]
		_pts[e.index] = e.position
		if e.index == _joy_id:
			var d: Vector2 = e.position - _joy_origin
			if d.length() > R:
				d = d.normalized() * R
			_joy_knob = d
			move = Vector2(d.x / R, -d.y / R)
			queue_redraw()
		elif rig and (e.index == _cam_id or e.index == _pinch_id):
			if _cam_id != -1 and _pinch_id != -1:
				var nd := _pinch_dist()
				rig.dist = clampf(rig.dist * _pinch_d / nd, 3.0, 16.0)
				_pinch_d = nd
			else:
				rig.yaw -= (e.position.x - prev.x) * 0.0065
				rig.pitch = clampf(rig.pitch + (e.position.y - prev.y) * 0.005, -0.25, 1.25)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var font := get_theme_default_font()
	var line := Color(1, 0.9, 0.7, 0.35)
	# Подсказка, где джойстик
	if _joy_id == -1:
		draw_arc(Vector2(60 + 55, size.y - 50 - 55), 55, 0, TAU, 48, Color(1, 0.9, 0.7, 0.25), 2.0)
	else:
		draw_circle(_joy_origin, 65, Color(1, 1, 1, 0.08))
		draw_arc(_joy_origin, 65, 0, TAU, 48, line, 2.0)
		draw_circle(_joy_origin + _joy_knob, 28, Color(1, 0.83, 0.47, 0.55))
		draw_arc(_joy_origin + _joy_knob, 28, 0, TAU, 32, Color(1, 0.94, 0.78, 0.8), 2.0)
	for b in _buttons():
		var on: bool = _down.get(b["id"], false) or (b["id"] == "run" and run)
		var fill := Color(1, 0.83, 0.47, 0.45) if on else Color(0.08, 0.06, 0.04, 0.55)
		draw_circle(b["c"], b["r"], fill)
		draw_arc(b["c"], b["r"], 0, TAU, 48, b.get("border", Color(1, 0.86, 0.63, 0.45)), 2.0)
		var fs: int = b["fs"]
		draw_string(font, b["c"] + Vector2(-b["r"], fs * 0.36), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2, fs, Color(1, 0.9, 0.69))
	if act_text != "":
		var r := _act_rect()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 0.83, 0.47, 0.88)
		sb.border_color = Color(1, 0.95, 0.82)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(28)
		draw_style_box(sb, r)
		draw_string(font, Vector2(r.position.x, r.position.y + 35), act_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.16, 0.11, 0.03))

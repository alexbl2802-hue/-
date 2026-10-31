## Сенсорное управление: левая часть экрана — джойстик, правая — камера и щипок,
## кнопки удара, прыжка, бега, действия, зелья, навыков и умений. Каждое касание
## отслеживается отдельно, поэтому можно одновременно идти, крутить камеру и нажимать кнопки.
extends Control

signal attack_pressed
signal act_pressed
signal potion_pressed
signal skills_pressed
signal skill_pressed(id: String)

const R := 55.0

var move := Vector2.ZERO
var run := false
var jump := false
var act_text := ""
var rig: Node3D

# Состояние для отрисовки (обновляет main.gd)
var potions := 0
var free_points := 0
var skill_ranks := {"whirl": 0, "dash": 0}
var cd_left := {"whirl": 0.0, "dash": 0.0}
var cd_total := {"whirl": 1.0, "dash": 1.0}

var _pts := {}          # индекс касания → позиция
var _btn_touch := {}    # индекс касания → кнопка
var _down := {}         # кнопка → нажата
var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _cam_id := -1
var _pinch_id := -1
var _pinch_d := 1.0
var _time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	_time += dt
	queue_redraw()

func _buttons() -> Array:
	var s := size
	var list := [
		{"id": "attack", "c": Vector2(s.x - 24 - 45.5, s.y - 28 - 45.5), "r": 45.5, "label": "⚔", "fs": 39, "border": Color(1, 0.55, 0.43, 0.75)},
		{"id": "jump", "c": Vector2(s.x - 126 - 33, s.y - 20 - 33), "r": 33.0, "label": "⤒", "fs": 27},
		{"id": "run", "c": Vector2(s.x - 40 - 28, s.y - 130 - 28), "r": 28.0, "label": "🏃", "fs": 23},
		{"id": "potion", "rect": Rect2(72, 12, 52, 52), "label": "🧪", "fs": 27, "badge": str(potions), "dim": potions == 0},
		{"id": "skills", "rect": Rect2(132, 12, 52, 52), "label": "⭐", "fs": 27, "badge": str(free_points) if free_points > 0 else "", "glow": free_points > 0},
	]
	if skill_ranks["whirl"] > 0:
		list.append({"id": "whirl", "c": Vector2(s.x - 128 - 32, s.y - 98 - 32), "r": 32.0, "label": "🌀", "fs": 29, "border": Color(0.5, 0.85, 1, 0.75)})
	if skill_ranks["dash"] > 0:
		list.append({"id": "dash", "c": Vector2(s.x - 204 - 32, s.y - 28 - 32), "r": 32.0, "label": "💨", "fs": 29, "border": Color(0.5, 0.85, 1, 0.75)})
	return list

func _act_rect() -> Rect2:
	if act_text == "":
		return Rect2()
	var w := get_theme_default_font().get_string_size(act_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 42.0
	return Rect2(size.x - 24 - w, size.y - 198 - 56, w, 56)

func _hit(p: Vector2) -> String:
	if act_text != "" and _act_rect().has_point(p):
		return "act"
	for b in _buttons():
		if b.has("rect"):
			if (b["rect"] as Rect2).grow(4).has_point(p):
				return b["id"]
		elif p.distance_to(b["c"]) <= b["r"] + 6.0:
			return b["id"]
	return ""

func _press(id: String, down: bool) -> void:
	_down[id] = down
	if not down:
		if id == "jump":
			jump = false
		return
	match id:
		"attack": attack_pressed.emit()
		"jump": jump = true
		"run": run = not run
		"act": act_pressed.emit()
		"potion": potion_pressed.emit()
		"skills": skills_pressed.emit()
		"whirl", "dash": skill_pressed.emit(id)

## Сбросить все касания (например, когда открывается окно)
func release_all() -> void:
	_pts.clear()
	_btn_touch.clear()
	_down.clear()
	_joy_id = -1
	_cam_id = -1
	_pinch_id = -1
	move = Vector2.ZERO
	jump = false

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
	var text_c := Color(1, 0.9, 0.69)
	# Джойстик
	if _joy_id == -1:
		draw_arc(Vector2(60 + 55, size.y - 50 - 55), 55, 0, TAU, 48, Color(1, 0.9, 0.7, 0.25), 2.0)
	else:
		draw_circle(_joy_origin, 65, Color(1, 1, 1, 0.08))
		draw_arc(_joy_origin, 65, 0, TAU, 48, line, 2.0)
		draw_circle(_joy_origin + _joy_knob, 28, Color(1, 0.83, 0.47, 0.55))
		draw_arc(_joy_origin + _joy_knob, 28, 0, TAU, 32, Color(1, 0.94, 0.78, 0.8), 2.0)
	for b in _buttons():
		var id: String = b["id"]
		var on: bool = _down.get(id, false) or (id == "run" and run)
		var fill := Color(1, 0.83, 0.47, 0.45) if on else Color(0.08, 0.06, 0.04, 0.6)
		var border: Color = b.get("border", Color(1, 0.86, 0.63, 0.45))
		var fs: int = b["fs"]
		var center: Vector2
		var half: float
		if b.has("rect"):
			var r: Rect2 = b["rect"]
			center = r.get_center()
			half = r.size.x / 2.0
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill
			sb.set_corner_radius_all(12)
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 0.83, 0.47, 0.6 + 0.4 * sin(_time * 4.5)) if b.get("glow", false) else border
			if b.get("glow", false):
				sb.shadow_color = Color(1, 0.83, 0.47, 0.35 + 0.3 * sin(_time * 4.5))
				sb.shadow_size = 8
			draw_style_box(sb, r)
		else:
			center = b["c"]
			half = b["r"]
			draw_circle(center, half, fill)
			draw_arc(center, half, 0, TAU, 48, border, 2.0)
		var tc := text_c
		if b.get("dim", false):
			tc.a = 0.45
		draw_string(font, center + Vector2(-half, fs * 0.36), b["label"], HORIZONTAL_ALIGNMENT_CENTER, half * 2, fs, tc)
		var badge: String = b.get("badge", "")
		if badge != "":
			draw_string_outline(font, center + Vector2(half - 22, half - 3), badge, HORIZONTAL_ALIGNMENT_RIGHT, 20, 14, 4, Color.BLACK)
			draw_string(font, center + Vector2(half - 22, half - 3), badge, HORIZONTAL_ALIGNMENT_RIGHT, 20, 14, Color.WHITE)
		# Перезарядка умения: затемнённый сектор и оставшиеся секунды
		if cd_left.has(id) and cd_left[id] > 0.0:
			var frac: float = cd_left[id] / maxf(0.01, cd_total[id])
			var pts := PackedVector2Array([center])
			var steps := 32
			for k in steps + 1:
				var a := -PI / 2 + TAU * frac * k / steps
				pts.append(center + Vector2(cos(a), sin(a)) * half)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
			var secs := str(ceili(cd_left[id]))
			draw_string_outline(font, center + Vector2(-half, 6), secs, HORIZONTAL_ALIGNMENT_CENTER, half * 2, 17, 4, Color.BLACK)
			draw_string(font, center + Vector2(-half, 6), secs, HORIZONTAL_ALIGNMENT_CENTER, half * 2, 17, Color.WHITE)
	if act_text != "":
		var r := _act_rect()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 0.83, 0.47, 0.88)
		sb.border_color = Color(1, 0.95, 0.82)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(28)
		draw_style_box(sb, r)
		draw_string(font, Vector2(r.position.x, r.position.y + 35), act_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.16, 0.11, 0.03))

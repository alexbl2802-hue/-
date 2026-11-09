## Сенсорное управление: левая часть экрана — джойстик, правая — камера и щипок,
## кнопки удара, прыжка, бега, действия, зелья, навыков и умений. Каждое касание
## отслеживается отдельно, поэтому можно одновременно идти, крутить камеру и нажимать кнопки.
extends Control

signal attack_pressed
signal act_pressed
signal potion_pressed
signal skills_pressed
signal skill_pressed(id: String)
signal inventory_pressed
signal menu_pressed
signal cardinal_pressed

const R := 55.0

var move := Vector2.ZERO
var run := false
var jump := false
var block := false      # кнопка блока удерживается
var act_text := ""
var rig: Node3D

# Состояние для отрисовки (обновляет main.gd)
var potions := 0
var free_points := 0
var cd_left := {"dodge": 0.0}
var cd_total := {"dodge": 1.0}
var dash_icon := "💨"   # меняется с эволюцией: 🌬️ Скользящий шаг, ✨ Мерцание
var dash_form := "dash" # форма рывка: dash / slide / blink — для картинки на кнопке
# Кнопки навыков: все изученные активные навыки, по 4 на страницу дуги вокруг удара;
# страницы листаются пальцем по дуге (как страницы), точки под дугой — какая страница
var skill_list: Array = []   # id навыков по порядку (dash, horizontal, art_sword …)
var skill_icons := {}        # id → значок, если нет картинки
const PAGE := 4
const PAGE_SLOTS := [172.0, 207.0, 243.0, 278.0]   # шире, чтобы кнопки не жались друг к другу
const PAGE_TURN := 90.0      # на сколько градусов уезжает страница при листании
var _page := 0
var _page_anim := 0.0        # -1/1 → 0: новая страница въезжает по дуге
var _swipe := {}             # индекс касания → {"id": кнопка или "", "a": угол старта, "p": точка, "done": bool}
var _imgs := {}         # картинки навыков (assets/icons/skills) для кнопок
# Круглые кнопки в серебряной рамке (assets/icons/buttons): у удара, прыжка, бега, блока и уклонения —
# своя картинка целиком; у навыков — их картинка внутри той же рамки (ring.png)
const BTN_IMG := {"attack": "attack", "jump": "jump", "run": "run", "block": "block", "dodge": "dodge"}
const RING_INNER := 0.86     # внутренний край рамки — доля радиуса
var _btn := {}

func _btn_tex(n: String) -> Texture2D:
	if not _btn.has(n):
		var p := "res://assets/icons/buttons/%s.png" % n
		_btn[n] = load(p) if ResourceLoader.exists(p) else null
	return _btn[n]

func _img(id: String) -> Texture2D:
	if not _imgs.has(id):
		var p := "res://assets/icons/skills_round/%s.png" % id   # круглая версия — ровно под кнопку
		if not ResourceLoader.exists(p):
			p = SkillDefs.icon_path(id)
		_imgs[id] = load(p) if id != "" and ResourceLoader.exists(p) else null
	return _imgs[id]

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
	_page_anim = move_toward(_page_anim, 0.0, dt * 4.5)
	_page = clampi(_page, 0, maxi(0, _pages() - 1))
	queue_redraw()

func _pages() -> int:
	return ceili(skill_list.size() / float(PAGE))

func _ring_center() -> Vector2:
	return Vector2(size.x - 16 - 38, size.y - 14 - 38)

## Перелистнуть страницу навыков: dir 1 — следующая, -1 — предыдущая (по кругу)
func _flip(dir: int) -> void:
	var n := _pages()
	if n <= 1:
		return
	_page = posmod(_page + dir, n)
	_page_anim = -float(dir)

func _buttons() -> Array:
	var s := size
	# Основной удар — в правом нижнем углу; навыки — дугой вокруг него (ближний круг),
	# прыжок, бег, блок и уклонение — дальним кругом
	var ac := Vector2(s.x - 16 - 38, s.y - 14 - 38)
	var at := func(r: float, deg: float) -> Vector2: return ac + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * r
	var list := [
		{"id": "attack", "c": ac, "r": 38.0, "label": "⚔", "fs": 32, "border": Color(1, 0.55, 0.43, 0.75)},
		{"id": "inventory", "rect": Rect2(10, 10, 32, 32), "label": "🎒", "fs": 16},
		{"id": "potion", "rect": Rect2(48, 10, 32, 32), "label": "🧪", "fs": 16, "badge": str(potions), "dim": potions == 0},
		{"id": "skills", "rect": Rect2(86, 10, 32, 32), "label": "👤", "fs": 16, "badge": str(free_points) if free_points > 0 else "", "glow": free_points > 0},
		{"id": "menu", "rect": Rect2(124, 10, 32, 32), "label": "☰", "fs": 16},
		{"id": "cardinal", "rect": Rect2(162, 10, 32, 32), "label": "◈", "fs": 16},
	]
	# Ближний круг — навыки текущей страницы (при листании въезжают по дуге)
	for k in PAGE:
		var i := _page * PAGE + k
		if i >= skill_list.size():
			break
		var id: String = skill_list[i]
		var img := dash_form if id == "dash" else id
		var art := id.begins_with("art_")
		list.append({"id": id, "skill": true, "img": img, "c": at.call(RING_IN, PAGE_SLOTS[k] + _page_anim * PAGE_TURN), "r": 24.0,
			"label": skill_icons.get(id, "✦"), "fs": 20, "alpha": 1.0 - absf(_page_anim),
			"border": Color(1, 0.85, 0.4, 0.8) if art else Color(0.5, 0.85, 1, 0.8)})
	# Дальний круг — уклонение, блок, прыжок, бег
	# Уклонение: назад, вбок или кувырок — по наклону джойстика
	list.append({"id": "dodge", "c": at.call(RING_OUT, 180.0), "r": 23.0, "label": "↶", "fs": 21, "border": Color(0.6, 0.95, 0.8, 0.75)})
	list.append({"id": "block", "c": at.call(RING_OUT, 203.0), "r": 23.0, "label": "🔰", "fs": 19, "border": Color(0.75, 0.8, 0.9, 0.7)})
	list.append({"id": "jump", "c": at.call(RING_OUT, 226.0), "r": 23.0, "label": "⤒", "fs": 19})
	list.append({"id": "run", "c": at.call(RING_OUT, 249.0), "r": 23.0, "label": "🏃", "fs": 17})
	return list

const RING_IN := 96.0     # радиус дуги навыков вокруг удара
const RING_OUT := 146.0     # дальний круг (до миникарты не достаёт)

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
			if b.get("skill", false) and absf(_page_anim) > 0.3:
				continue   # страница ещё едет
			return b["id"]
	return ""

## Касание на дуге навыков (между кнопками) — только для листания
func _on_skill_arc(p: Vector2) -> bool:
	if _pages() <= 1:
		return false
	var v := p - _ring_center()
	var a := fposmod(rad_to_deg(v.angle()), 360.0)
	return absf(v.length() - RING_IN) < 30.0 and a > 158.0 and a < 292.0

func _press(id: String, down: bool) -> void:
	_down[id] = down
	if not down:
		if id == "jump":
			jump = false
		if id == "block":
			block = false
		return
	match id:
		"attack": attack_pressed.emit()
		"jump": jump = true
		"block": block = true
		"run": run = not run
		"act": act_pressed.emit()
		"potion": potion_pressed.emit()
		"skills": skills_pressed.emit()
		"dodge": skill_pressed.emit(id)
		"inventory": inventory_pressed.emit()
		"menu": menu_pressed.emit()
		"cardinal": cardinal_pressed.emit()

## Сбросить все касания (например, когда открывается окно)
func release_all() -> void:
	_pts.clear()
	_btn_touch.clear()
	_down.clear()
	_swipe.clear()
	_joy_id = -1
	_cam_id = -1
	_pinch_id = -1
	move = Vector2.ZERO
	jump = false
	block = false

func _pinch_dist() -> float:
	return maxf(1.0, (_pts[_cam_id] as Vector2).distance_to(_pts[_pinch_id]))

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var b := _hit(e.position)
			if b in skill_list or (b == "" and _on_skill_arc(e.position)):
				# Навык срабатывает сразу при нажатии; если палец повёл по дуге — ещё и листаем страницу
				_swipe[e.index] = {"id": b, "a": (e.position - _ring_center()).angle(), "p": e.position, "done": false}
				if b != "":
					_down[b] = true
					skill_pressed.emit(b)
			elif b != "":
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
			if _swipe.has(e.index):
				var sw: Dictionary = _swipe[e.index]
				_swipe.erase(e.index)
				if sw["id"] != "":
					_down[sw["id"]] = false
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
		if _swipe.has(e.index):
			var sw: Dictionary = _swipe[e.index]
			if not sw["done"] and (e.position - (sw["p"] as Vector2)).length() > 20.0:
				var da := rad_to_deg(angle_difference(sw["a"], (e.position - _ring_center()).angle()))
				if absf(da) > 10.0 and _pages() > 1:
					sw["done"] = true
					if sw["id"] != "":
						_down[sw["id"]] = false
					_flip(1 if da > 0.0 else -1)
			get_viewport().set_input_as_handled()
			return
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
				rig.yaw -= (e.position.x - prev.x) * 0.0065 * Settings.cam_sens
				rig.pitch = clampf(rig.pitch + (e.position.y - prev.y) * 0.005 * Settings.cam_sens, -0.25, 1.25)
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
			var own := _btn_tex(BTN_IMG.get(id, ""))
			var ring := _btn_tex("ring")
			if own or (ring and _img(b.get("img", ""))):
				# Фиолетовое свечение вокруг рамки, при нажатии ярче
				for k in 3:
					draw_circle(center, half * (1.12 - k * 0.04), Color(0.62, 0.3, 1.0, (0.10 if not on else 0.22) * b.get("alpha", 1.0)))
			else:
				draw_circle(center, half, fill)
				draw_arc(center, half, 0, TAU, 48, border, 2.0)
		var tc := text_c
		if b.get("dim", false):
			tc.a = 0.45
		var tex := _img(b.get("img", ""))
		var own_tex := _btn_tex(BTN_IMG.get(id, "")) if not b.has("rect") else null
		var mod := Color(1, 1, 1, 1) if not on else Color(1.25, 1.15, 1.35, 1)
		if b.get("dim", false):
			mod.a = 0.45
		mod.a *= b.get("alpha", 1.0)
		tc.a *= b.get("alpha", 1.0)
		if own_tex:
			draw_texture_rect(own_tex, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, mod)
		elif tex:
			# Картинка навыка — внутри серебряной рамки, как у остальных кнопок
			var ring_tex := _btn_tex("ring")
			var side := half * 2.0 * (RING_INNER + 0.02) if ring_tex else half * 2.0 - 3.0
			draw_texture_rect(tex, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, mod)
			if ring_tex:
				draw_texture_rect(ring_tex, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, mod)
			else:
				draw_arc(center, half, 0, TAU, 48, b.get("border", Color(1, 0.86, 0.63, 0.45)), 2.0)
		else:
			draw_string(font, center + Vector2(-half, fs * 0.36), b["label"], HORIZONTAL_ALIGNMENT_CENTER, half * 2, fs, tc)
		var badge: String = b.get("badge", "")
		if badge != "":
			draw_string_outline(font, center + Vector2(half - 20, half - 2), badge, HORIZONTAL_ALIGNMENT_RIGHT, 20, 12, 4, Color.BLACK)
			draw_string(font, center + Vector2(half - 20, half - 2), badge, HORIZONTAL_ALIGNMENT_RIGHT, 20, 12, Color.WHITE)
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
	# Точки страниц навыков — между ударом и дугой навыков
	var np := _pages()
	if np > 1:
		for k in np:
			var a := deg_to_rad(225.0 + (k - (np - 1) / 2.0) * 9.0)
			var c := _ring_center() + Vector2(cos(a), sin(a)) * 57.0
			draw_circle(c, 3.2 if k == _page else 2.4, Color(1, 0.92, 0.7, 0.95 if k == _page else 0.4))
	if act_text != "":
		var r := _act_rect()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 0.83, 0.47, 0.88)
		sb.border_color = Color(1, 0.95, 0.82)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(28)
		draw_style_box(sb, r)
		draw_string(font, Vector2(r.position.x, r.position.y + 35), act_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.16, 0.11, 0.03))

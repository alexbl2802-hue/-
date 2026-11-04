## Экранный интерфейс: название места, уровень/здоровье/опыт, баннеры, миникарта,
## полоски здоровья раненых монстров, красная вспышка при уроне, затемнение,
## окно навыков и сенсорное управление.
extends CanvasLayer

var touch: Control
var minimap: Control
var skills: Control
var inventory: Control
var forge: Control
var alchemist: Control
var cardinal: Control   # системное окно CARDINAL
var menu: Control
var hero: Node3D
var camera: Camera3D
var enemies: Node

var _status: Label
var _banner: Label
var _banner_sub: Label
var _banner_box: VBoxContainer
var _tween: Tween
var _bars: Control
var _enemy_bars: Control
var _hurt: TextureRect
var _fade: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Полоски здоровья монстров (рисуются поверх 3D)
	_enemy_bars = Control.new()
	_enemy_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_bars.draw.connect(_draw_enemy_bars)
	_enemy_bars.draw.connect(_draw_floaters)
	_enemy_bars.draw.connect(_draw_enemy_tags)
	_enemy_bars.draw.connect(_draw_boss_bar)
	root.add_child(_enemy_bars)
	# Красная вспышка по краям экрана при уроне
	var grad := Gradient.new()
	grad.set_color(0, Color(0.63, 0, 0, 0))
	grad.set_color(1, Color(0.67, 0, 0, 0.7))
	grad.add_point(0.55, Color(0.63, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	_hurt = TextureRect.new()
	_hurt.texture = gt
	_hurt.stretch_mode = TextureRect.STRETCH_SCALE
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.modulate.a = 0.0
	root.add_child(_hurt)
	# Ник и уровень героя вверху по центру
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.04, 0.55), 8, 14, 5))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color("#ffe7b0"))
	panel.add_child(_status)
	root.add_child(panel)
	# Уровень, здоровье, опыт
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	root.add_child(_bars)
	# Миникарта справа сверху
	minimap = preload("res://scripts/minimap.gd").new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -124
	minimap.offset_right = -12
	minimap.offset_top = 12
	minimap.offset_bottom = 124
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	# Баннер
	_banner_box = VBoxContainer.new()
	_banner_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner_box.position.y = 92
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.modulate.a = 0.0
	_banner = _label(32, Color("#f4ecd8"))
	_banner_sub = _label(15, Color(0.96, 0.93, 0.85, 0.85))
	_banner_box.add_child(_banner)
	_banner_box.add_child(_banner_sub)
	root.add_child(_banner_box)
	# Сенсорное управление
	touch = preload("res://scripts/touch_ui.gd").new()
	root.add_child(touch)
	# Окно навыков
	skills = preload("res://scripts/ui/skills_panel.gd").new()
	root.add_child(skills)
	skills.closed.connect(func(): touch.visible = true)
	inventory = preload("res://scripts/ui/inventory_panel.gd").new()
	root.add_child(inventory)
	inventory.closed.connect(func(): touch.visible = true)
	forge = preload("res://scripts/ui/forge_panel.gd").new()
	root.add_child(forge)
	forge.closed.connect(func(): touch.visible = true)
	alchemist = preload("res://scripts/ui/alchemist_panel.gd").new()
	root.add_child(alchemist)
	alchemist.closed.connect(func(): touch.visible = true)
	cardinal = preload("res://scripts/ui/cardinal_panel.gd").new()
	root.add_child(cardinal)
	cardinal.closed.connect(func(): touch.visible = true)
	# Затемнение для переходов
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)
	# Главное меню — поверх всего
	menu = preload("res://scripts/ui/main_menu.gd").new()
	root.add_child(menu)
	menu.started.connect(func(_first): touch.visible = true)

func _box(c: Color, radius: int, mx: int, my: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = Color(1, 0.86, 0.63, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb

func _label(fs: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(dt: float) -> void:
	Fx.update(dt)
	_bars.queue_redraw()
	_enemy_bars.queue_redraw()
	if _fps_lbl and _fps_lbl.visible:
		_fps_lbl.text = "%d кадр/с" % Engine.get_frames_per_second()

## Счётчик кадров в секунду (настройка)
var _fps_lbl: Label
func show_fps(on: bool) -> void:
	if not _fps_lbl:
		_fps_lbl = Label.new()
		_fps_lbl.add_theme_font_size_override("font_size", 12)
		_fps_lbl.add_theme_color_override("font_color", Color("#9fff9f"))
		_fps_lbl.position = Vector2(14, 70)
		_fps_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fps_lbl)
	_fps_lbl.visible = on

## Цвет полоски здоровья: зелёная, с половины — жёлтая, на последней четверти — красная и мигает
func hp_color(f: float) -> Color:
	if f > 0.5:
		return Color("#4cd964")
	if f > 0.25:
		return Color("#f2c230")
	var blink := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
	return Color("#e8382c").lerp(Color("#ff8a80"), 1.0 - blink)

func set_status(text: String) -> void:
	_status.text = text

func banner(title: String, sub := "") -> void:
	_banner.text = title
	_banner_sub.text = sub
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.5)
	_tween.tween_interval(2.4)
	_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.8)

func flash_hurt() -> void:
	_hurt.modulate.a = 1.0
	create_tween().tween_property(_hurt, "modulate:a", 0.0, 0.6)

## Затемнить экран, выполнить действие и снова показать
func fade(action: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.45)
	tw.tween_callback(action)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.45)

func open_skills() -> void:
	touch.release_all()
	touch.visible = false
	skills.open()

func open_inventory() -> void:
	touch.release_all()
	touch.visible = false
	inventory.open()

func open_forge() -> void:
	touch.release_all()
	touch.visible = false
	forge.open()

func open_alchemist() -> void:
	touch.release_all()
	touch.visible = false
	alchemist.open()

func open_cardinal() -> void:
	touch.release_all()
	touch.visible = false
	cardinal.open()

func open_menu() -> void:
	touch.release_all()
	touch.visible = false
	menu.open()

# ---------- Уровень, здоровье, опыт
func _draw_bars() -> void:
	var font := _bars.get_theme_default_font()
	var w := 200.0
	var x := (_bars.size.x - w) / 2.0 + 16
	var y := 44.0
	# Значок уровня
	var c := Vector2(x - 20, y + 9)
	_bars.draw_circle(c, 15, Color("#e0a83a"))
	_bars.draw_arc(c, 15, 0, TAU, 32, Color("#fff3d0"), 2.0)
	_bars.draw_string(font, c + Vector2(-15, 5), str(Game.level), HORIZONTAL_ALIGNMENT_CENTER, 30, 14, Color("#2a1d08"))
	# Здоровье
	_bars.draw_rect(Rect2(x, y, w, 12), Color(0, 0, 0, 0.55))
	_bars.draw_rect(Rect2(x, y, w * clampf(Game.hp / Game.max_hp, 0, 1), 12), hp_color(Game.hp / Game.max_hp))
	_bars.draw_rect(Rect2(x, y, w, 12), Color(1, 0.86, 0.63, 0.35), false, 1.0)
	var t := "%d / %d" % [ceili(Game.hp), roundi(Game.max_hp)]
	_bars.draw_string_outline(font, Vector2(x, y + 10), t, HORIZONTAL_ALIGNMENT_CENTER, w, 10, 3, Color(0, 0, 0, 0.8))
	_bars.draw_string(font, Vector2(x, y + 10), t, HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color.WHITE)
	# Опыт
	_bars.draw_rect(Rect2(x, y + 15, w, 5), Color(0, 0, 0, 0.55))
	_bars.draw_rect(Rect2(x, y + 15, w * clampf(float(Game.xp) / Game.xp_next(Game.level), 0, 1), 5), Color("#5ab8e8"))

# ---------- Полоски здоровья раненых монстров
func _draw_enemy_bars() -> void:
	if not camera or not enemies:
		return
	for e in enemies.list:
		if e.dead or e.hp >= e.T["hp"] or not e.is_physics_processing():
			continue
		var p: Vector3 = e.global_position + Vector3(0, e.T["bar"], 0)
		if camera.is_position_behind(p) or camera.global_position.distance_to(p) > 60.0:
			continue
		var s := camera.unproject_position(p)
		var r := Rect2(s.x - 26, s.y - 4, 52, 7)
		_enemy_bars.draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
		_enemy_bars.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(e.hp / e.T["hp"], 0, 1), r.size.y)), hp_color(e.hp / e.T["hp"]))

# ---------- Всплывающие надписи (урон, опыт, добыча)
func _draw_floaters() -> void:
	if not camera:
		return
	var font := _enemy_bars.get_theme_default_font()
	for f in Fx.floaters:
		var t: float = f["t"]
		var p: Vector3 = f["pos"] + Vector3(0, t * 1.3, 0)
		if camera.is_position_behind(p):
			continue
		var s := camera.unproject_position(p)
		var fs := 24 if f["big"] else 17
		var c: Color = f["color"]
		c.a = 1.0 - maxf(0.0, (t - 0.9) / 0.5)
		var w := 400.0
		_enemy_bars.draw_string_outline(font, s + Vector2(-w / 2, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, w, fs, 5, Color(0, 0, 0, c.a * 0.9))
		_enemy_bars.draw_string(font, s + Vector2(-w / 2, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, w, fs, c)

## Надпись над персонажем: «Имя · Ур. N» (имя может быть пустым — тогда только уровень)
func _tag(s: Vector2, title: String, level: int, color: Color) -> void:
	var font := _enemy_bars.get_theme_default_font()
	var lv := "Ур. %d" % level
	var fs := 13
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if title != "" else 0.0
	var sep := "  ·  " if title != "" else ""
	var sw := font.get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := s.x - (tw + sw + lw) / 2.0
	for part in [[title, color], [sep, Color(1, 1, 1, 0.6)], [lv, Color("#ffd479")]]:
		if part[0] == "":
			continue
		_enemy_bars.draw_string_outline(font, Vector2(x, s.y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		_enemy_bars.draw_string(font, Vector2(x, s.y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, part[1])
		x += font.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

# ---------- Полоска здоровья босса вверху экрана, когда герой рядом с ним
func _draw_boss_bar() -> void:
	if not enemies or not hero or menu.visible:
		return
	var boss: Node3D = null
	for e in enemies.list:
		if e.T.get("boss", false) and not e.dead and e.is_physics_processing() and e.global_position.distance_to(hero.global_position) < 26.0:
			boss = e
	if not boss:
		return
	var font := _enemy_bars.get_theme_default_font()
	var w := 380.0
	var x := (_enemy_bars.size.x - w) / 2.0
	var y := 78.0
	var t: String = boss.T["name"]
	_enemy_bars.draw_string_outline(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_CENTER, w, 15, 4, Color(0, 0, 0, 0.85))
	_enemy_bars.draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("#ffb070"))
	var r := Rect2(x, y + 6, w, 11)
	_enemy_bars.draw_rect(r.grow(2), Color(0, 0, 0, 0.6))
	_enemy_bars.draw_rect(Rect2(r.position, Vector2(w * clampf(boss.hp / boss.T["hp"], 0, 1), r.size.y)), hp_color(boss.hp / boss.T["hp"]))
	_enemy_bars.draw_rect(r.grow(2), Color(1, 0.75, 0.4, 0.6), false, 1.5)

# ---------- Название и уровень над монстрами
func _draw_enemy_tags() -> void:
	if not camera or not enemies or menu.visible:
		return
	for e in enemies.list:
		if e.dead or not e.visible or not e.is_physics_processing() or e.T.get("boss", false):
			continue   # у босса — большая полоска с именем вверху экрана
		var p: Vector3 = e.global_position + Vector3(0, e.T["bar"] + 0.3, 0)
		if camera.is_position_behind(p) or camera.global_position.distance_to(p) > 30.0:
			continue
		_tag(camera.unproject_position(p), e.T.get("name", ""), e.level, Color("#ff9a7a"))

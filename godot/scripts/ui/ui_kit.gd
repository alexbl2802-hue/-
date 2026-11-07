## Общие элементы окон в стиле присланных картинок: тёмно-синие окна с серебряной рамкой
## и узорами по углам, табличка заголовка со скошенным краем, колонка вкладок слева
## с синей подсветкой выбранной, ячейки предметов с заливкой цвета редкости,
## синие кнопки-«капсулы» со свечением.
class_name UiKit
extends RefCounted

const GOLD := Color("#ffc94a")      # акцент: золото, легендарное, награды
const CREAM := Color("#eef3fb")     # текст на кнопках
const TEXT := Color("#dfe7f3")
const DIM := Color("#8d9ab0")       # второстепенный текст
const GLOW := Color("#5aa8ff")      # синее свечение выбранного
const SILVER := Color("#aeb9c9")    # серебряная рамка окна
const WIN_BG := Color(0.035, 0.06, 0.11, 0.97)
const CARD_BG := Color(0.05, 0.085, 0.15, 0.95)
const LINE := Color("#26344c")      # тонкие разделители и рамки внутренних панелей
const BTN_BG := Color("#13284a")
const BTN_HI := Color("#2160c0")
const RADIUS := 6

static func box(bg: Color, border: Color, radius := RADIUS, margin := 8, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

## Свечение вокруг рамки
static func glow(s: StyleBoxFlat, size := 10, a := 0.35, c := GLOW) -> StyleBoxFlat:
	s.shadow_color = Color(c.r, c.g, c.b, a)
	s.shadow_size = size
	return s

## Окно: тёмно-синий фон, серебряная рамка, тень
static func window_box() -> StyleBoxFlat:
	var s := box(WIN_BG, SILVER, 10, 14, 2)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 14
	return s

## Внутренняя панель (список, описание предмета)
static func card_box(margin := 10) -> StyleBoxFlat:
	return box(CARD_BG, LINE, 8, margin, 1)

static func card(content: Control, margin := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(margin))
	p.add_child(content)
	return p

## Узоры окна: вторая тонкая рамка внутри и серебряные завитки по углам.
## Добавляется последним ребёнком PanelContainer; рисует за пределами своего прямоугольника на margin.
static func decorate(panel: PanelContainer, margin := 14.0) -> void:
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(o)
	o.draw.connect(func():
		var r := Rect2(Vector2(-margin, -margin), o.size + Vector2(margin, margin) * 2.0)
		var inner := r.grow(-5.0)
		o.draw_rect(inner, Color(SILVER.r, SILVER.g, SILVER.b, 0.18), false, 1.0)
		var sil := Color(SILVER.r, SILVER.g, SILVER.b, 0.95)
		for k in 4:
			var sx := 1.0 if k % 2 == 0 else -1.0
			var sy := 1.0 if k < 2 else -1.0
			var c := Vector2(r.position.x if sx > 0 else r.end.x, r.position.y if sy > 0 else r.end.y)
			var d := Vector2(sx, sy)
			# уголок: двойной изгиб, ромбик и завиток
			o.draw_polyline(PackedVector2Array([c + Vector2(30, 3) * d, c + Vector2(8, 3) * d, c + Vector2(3, 8) * d, c + Vector2(3, 30) * d]), sil, 2.0, true)
			o.draw_polyline(PackedVector2Array([c + Vector2(22, 9) * d, c + Vector2(12, 9) * d, c + Vector2(9, 12) * d, c + Vector2(9, 22) * d]), Color(sil, 0.6), 1.2, true)
			var dm := c + Vector2(15, 15) * d
			o.draw_colored_polygon(PackedVector2Array([dm + Vector2(0, -3), dm + Vector2(3, 0), dm + Vector2(0, 3), dm + Vector2(-3, 0)]), sil)
			o.draw_arc(c + Vector2(38, 7) * d, 4.0, 0.0, TAU * 0.75, 10, Color(sil, 0.7), 1.2, true)
			o.draw_arc(c + Vector2(7, 38) * d, 4.0, 0.0, TAU * 0.75, 10, Color(sil, 0.7), 1.2, true))

## Табличка заголовка: тёмная плашка с серебряной рамкой и скошенным правым краем
static func title_plate(t: String, fs := 22) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxEmpty.new()
	st.content_margin_left = 18
	st.content_margin_right = 34
	st.content_margin_top = 3
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	var l := label(t, fs, Color("#f4f7fc"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	p.add_child(l)
	p.draw.connect(func():
		var w := p.size.x
		var h := p.size.y
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w - 20, 0), Vector2(w, h / 2.0), Vector2(w - 20, h), Vector2(0, h)])
		p.draw_colored_polygon(pts, Color("#0b1220"))
		var outline := pts.duplicate()
		outline.append(pts[0])
		p.draw_polyline(outline, SILVER, 2.0, true)
		var inner := PackedVector2Array([Vector2(4, 4), Vector2(w - 22, 4), Vector2(w - 6, h / 2.0), Vector2(w - 22, h - 4), Vector2(4, h - 4), Vector2(4, 4)])
		p.draw_polyline(inner, Color(SILVER.r, SILVER.g, SILVER.b, 0.3), 1.0, true)
		p.draw_line(Vector2(w + 4, h / 2.0), Vector2(w + 14, h / 2.0), Color(SILVER.r, SILVER.g, SILVER.b, 0.7), 1.5, true))
	return p

## Шапка окна: табличка заголовка, место для своих надписей (возвращается) и кнопка «✕»
static func header(vb: VBoxContainer, title: String, on_close: Callable) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(title_plate(title))
	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 12)
	extra.alignment = BoxContainer.ALIGNMENT_END
	extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(extra)
	var x := close_button()
	x.pressed.connect(on_close)
	head.add_child(x)
	return extra

static func close_button() -> Button:
	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(34, 34)
	x.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := box(Color("#0e1a2e"), SILVER, 6, 0, 1)
		if state != "normal":
			glow(s, 5, 0.5)
		x.add_theme_stylebox_override(state, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		x.add_theme_color_override(k, CREAM)
	return x

static func label(t: String, fs := 13, c := TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

## Строка «название ...... значение»
static func stat_row(name: String, value: String, vc := TEXT, fs := 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	var a := label(name, fs, TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(label(value, fs, vc))
	return r

## Тонкий разделитель
static func line() -> ColorRect:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(0, 1)
	return c

## Кнопка-капсула: тёмно-синяя с голубой каймой; главная — ярко-синяя со свечением
static func button(t: String, primary := false, fs := 13) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := box(BTN_HI if primary else BTN_BG, Color("#a8d4ff") if primary else Color("#4f78b0"), 16, 0, 1)
		if primary:
			glow(s, 6, 0.45)
			s.border_width_top = 2
		if state == "hover" or state == "pressed":
			glow(s, 8, 0.6)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		if state == "pressed":
			s.bg_color = s.bg_color.darkened(0.2)
		if state == "disabled":
			s.bg_color = Color("#141c2a")
			s.border_color = Color("#2c3a50")
			s.shadow_size = 0
		b.add_theme_stylebox_override(state, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE if primary else CREAM)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.65, 0.72, 0.7))
	return b

## Вкладка в левой колонке: значок и название; выбранная — синяя полоса со свечением
static func tab(t: String, selected := false, fs := 14) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(0, 38)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat
		if selected:
			s = glow(box(Color("#1d4f9a"), Color("#7cc0ff"), 8, 0, 1), 7, 0.45)
			s.border_width_left = 3
		else:
			s = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
			s.border_color = LINE
			s.border_width_bottom = 1
			if state == "hover" or state == "pressed":
				s.bg_color = Color(0.35, 0.6, 1.0, 0.08)
		s.content_margin_left = 12
		s.content_margin_right = 10
		b.add_theme_stylebox_override(state, s)
	var fc := Color.WHITE if selected else Color("#c9d3e2")
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	return b

## Колонка вкладок слева в своей панели
static func tab_column(width := 150.0) -> Array:   # [панель, VBox для вкладок]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var p := card(vb, 6)
	p.custom_minimum_size = Vector2(width, 0)
	return [p, vb]

## Ячейка предмета: значок на заливке цвета редкости, рамка того же цвета, число в углу, подпись снизу
static func slot(icon: String, border: Color, count := "", caption := "", size := 42.0, selected := false) -> Button:
	var b := Button.new()
	b.text = icon
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", int(size * 0.5))
	var empty := border.a < 0.5
	for state in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat
		if empty:
			s = box(Color("#0f1828"), LINE, 5, 0, 1)
		else:
			var fill := border.darkened(0.62)
			fill.a = 0.95
			s = box(fill, border.lightened(0.15) if selected else border, 5, 0, 3 if selected else 2)
			glow(s, 8 if selected else 3, 0.7 if selected else 0.3, border)
		b.add_theme_stylebox_override(state, s)
	if not empty:   # блик сверху, как на гранёной плашке
		var shine := Panel.new()
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(1, 1, 1, 0.07)
		ss.corner_radius_top_left = 4
		ss.corner_radius_top_right = 4
		shine.add_theme_stylebox_override("panel", ss)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.anchor_right = 1.0
		shine.anchor_bottom = 0.45
		shine.offset_left = 2
		shine.offset_top = 2
		shine.offset_right = -2
		b.add_child(shine)
	if count != "":
		var n := label(count, 11, Color.WHITE)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 4)
		# С подписью внизу число переезжает в правый верхний угол
		if caption != "":
			n.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			n.offset_left = -26
			n.offset_top = 1
			n.offset_right = -4
		else:
			n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			n.offset_left = -26
			n.offset_top = -16
			n.offset_right = -4
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(n)
	if caption != "":
		var c := label(caption, 9, Color(1, 1, 1, 0.7))
		c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		c.offset_top = -13
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(c)
	return b

## Плашка с деньгами: 🪙 золото и 🔮 осколки на тёмной полосе
static func money_bar(gold: int, shards: int) -> PanelContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	hb.add_child(label("🪙 %s" % group(gold), 15, Color("#ffe08a")))
	hb.add_child(label("🔮 %s" % group(shards), 15, Color("#9fd2ff")))
	var p := PanelContainer.new()
	var s := box(Color("#0b1322"), LINE, 16, 6, 1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	p.add_theme_stylebox_override("panel", s)
	p.add_child(hb)
	return p

## 478350 → «478 350»
static func group(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

## Затемнение фона + окно по центру; возвращает контейнер содержимого
static func modal(owner: Control, on_backdrop: Callable) -> VBoxContainer:
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.visible = false
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: on_backdrop.call())
	owner.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", window_box())
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	decorate(panel)
	# Окно всегда целиком на экране: чуть меньше обычного и ещё меньше, если не влезает
	panel.resized.connect(func(): fit(center, panel))
	owner.visibility_changed.connect(func(): fit.call_deferred(center, panel))
	return vb

const UI_SCALE := 0.82   # общий размер окон (было 0,92)

## Масштаб ставится слою по центру экрана (у окна внутри контейнера Godot его сбрасывает)
static func fit(center: Control, panel: Control) -> void:
	if not center.is_inside_tree() or panel.size.x <= 0.0:
		return
	var vp := center.get_viewport_rect().size
	var k := minf(UI_SCALE, minf((vp.x - 16.0) / panel.size.x, (vp.y - 10.0) / panel.size.y))
	center.pivot_offset = center.size / 2.0
	center.scale = Vector2(k, k)

## Прокрутка списков пальцем: кнопки и надписи внутри ScrollContainer пропускают касание дальше,
## и список листается, если вести по нему пальцем (нажатие кнопки при этом отменяется).
## Подключается один раз для всей игры (Game._ready → get_tree().node_added).
static func pass_in_scroll(n: Node) -> void:
	if not (n is Control) or n is ScrollContainer or n is Range or n is LineEdit or n is TextEdit:
		return
	var c := n as Control
	if c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		p = p.get_parent()

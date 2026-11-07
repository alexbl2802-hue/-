## Профиль героя: ник, уровень и очки навыков; слева — прокручиваемый список навыков,
## справа — описание выбранного навыка, под ним кнопки «Улучшить» и «Эволюция».
## Игра на паузе, пока окно открыто.
extends Control

signal closed

var _title: Label
var _points: Label
var _list: VBoxContainer
var _reset: Button
var _reset_armed := false
var _sel := "strength"
var _tab := "skills"          # skills — навыки, stats — характеристики
var _sel_stat := "str"
var _tabs := {}
const STATS := [
	{"id": "str", "icon": "💪", "name": "Сила"},
	{"id": "agi", "icon": "🪶", "name": "Ловкость"},
	{"id": "vit", "icon": "❤️", "name": "Выносливость"},
]
# Правая половина: описание выбранного навыка
var _d_name: Label
var _d_kind: Label
var _d_rank: Label
var _d_now: Label
var _d_next: Label
var _d_need: Label
var _up: Button
var _evo: Button

var _tab_col: VBoxContainer

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	# Шапка: табличка «Навыки», ник и уровень, очки, сброс, закрыть
	var extra := UiKit.header(vb, "Навыки", close)
	_title = _lbl("", 14, UiKit.CREAM)
	extra.add_child(_title)
	_points = _lbl("", 14, UiKit.GOLD)
	extra.add_child(_points)
	_reset = _btn("Сбросить", false)
	_reset.pressed.connect(_on_reset)
	extra.add_child(_reset)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	# Слева — вкладки
	var tc: Array = UiKit.tab_column(160)
	body.add_child(tc[0])
	_tab_col = tc[1]
	# Левая половина: список навыков с прокруткой
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.custom_minimum_size = Vector2(240, 250)
	body.add_child(UiKit.card(scroll, 6))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	# Правая половина: описание навыка, ниже — «Улучшить» и рядом «Эволюция»
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiKit.card_box(12))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = 1.0
	body.add_child(info)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 5)
	info.add_child(dv)
	_d_name = _lbl("", 19, Color("#f4f7fc"))
	dv.add_child(_d_name)
	_d_kind = _lbl("", 11, Color("#8fc4ff"))
	dv.add_child(_d_kind)
	_d_rank = _lbl("", 15, UiKit.CREAM)
	dv.add_child(_d_rank)
	_d_now = _wrap(_lbl("", 13, UiKit.TEXT))
	dv.add_child(_d_now)
	_d_next = _wrap(_lbl("", 12, UiKit.DIM))
	dv.add_child(_d_next)
	_d_need = _lbl("", 12, Color("#ff9a7a"))
	dv.add_child(_d_need)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	dv.add_child(buttons)
	_up = _btn("Улучшить", true)
	_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up.custom_minimum_size = Vector2(0, 40)
	_up.pressed.connect(func():
		var ok := Game.add_stat(_sel_stat) if _tab == "stats" else Game.learn(_sel)
		if ok:
			_render())
	buttons.add_child(_up)
	_evo = _btn("✨ Эволюция", false)
	_evo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_evo.custom_minimum_size = Vector2(0, 40)
	_evo.pressed.connect(func():
		if Game.evolve(_sel):
			_render())
	buttons.add_child(_evo)

func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	return l

func _lbl(t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

func _btn(t: String, primary: bool) -> Button:
	return UiKit.button(t, primary)

func open() -> void:
	_reset_armed = false
	_reset.text = "Сбросить"
	_render()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _on_reset() -> void:
	if (_tab == "skills" and Game.skills.is_empty()) or (_tab == "stats" and Game.stat_points_free() == (Game.level - 1) * Game.STAT_PER_LEVEL):
		return
	if not _reset_armed:
		_reset_armed = true
		_reset.text = "Точно сбросить?"
		return
	if _tab == "stats":
		Game.reset_stats()
	else:
		Game.reset_skills()
	_reset_armed = false
	_reset.text = "Сбросить"
	_render()

func _render() -> void:
	var free := Game.points_free()
	_title.text = "👤 %s · Ур. %d" % [Game.player_name if Game.player_name != "" else "Странник", Game.level]
	for c in _tab_col.get_children():
		_tab_col.remove_child(c)
		c.queue_free()
	for t in [["skills", "⚔  Навыки"], ["stats", "📊  Характеристики"]]:
		var key: String = t[0]
		var tb := UiKit.tab(t[1], key == _tab, 13)
		tb.pressed.connect(func():
			_tab = key
			_reset_armed = false
			_reset.text = "Сбросить"
			_render())
		_tab_col.add_child(tb)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if _tab == "stats":
		_render_stats()
		return
	_points.text = "Очки навыков: %d" % free
	for s in SkillDefs.LIST:
		var id: String = s["id"]
		var r := Game.rank(id)
		var locked: bool = Game.level < s["lvl"]
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  %s      %d / %d" % [s["icon"], s["name"], r, s["max"]]
		if id == "dash":   # у рывка — текущая форма эволюции
			match SkillDefs.dash_form(Game.skills):
				"slide": row.text = "🌬️  Скользящий шаг      %d / %d" % [Game.rank("dash_slide"), SkillDefs.SLIDE_MAX]
				"blink": row.text = "✨  Мерцание      прорыв"
		row.add_theme_font_size_override("font_size", 14)
		row.custom_minimum_size = Vector2(0, 40)
		for state in ["normal", "hover", "pressed", "focus"]:
			var st := UiKit.glow(UiKit.box(Color("#1d4f9a"), Color("#7cc0ff"), 8, 0, 1), 6, 0.45) if id == _sel \
				else UiKit.box(Color("#0f1a2e"), UiKit.LINE, 8, 0, 1)
			st.content_margin_left = 10
			row.add_theme_stylebox_override(state, st)
		var fc := Color(0.93, 0.95, 0.98, 0.45 if locked else 1.0)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			row.add_theme_color_override(k, fc)
		row.pressed.connect(func():
			_sel = id
			_render())
		_list.add_child(row)
	_render_info(free)

## Вкладка «Характеристики»: Сила, Ловкость, Выносливость — по 2 очка за уровень
func _render_stats() -> void:
	var free := Game.stat_points_free()
	_points.text = "Очки характеристик: %d" % free
	for st in STATS:
		var id: String = st["id"]
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  %s      %d" % [st["icon"], st["name"], Game.stats[id]]
		row.add_theme_font_size_override("font_size", 14)
		row.custom_minimum_size = Vector2(0, 40)
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := UiKit.glow(UiKit.box(Color("#1d4f9a"), Color("#7cc0ff"), 8, 0, 1), 6, 0.45) if id == _sel_stat \
				else UiKit.box(Color("#0f1a2e"), UiKit.LINE, 8, 0, 1)
			sb.content_margin_left = 10
			row.add_theme_stylebox_override(state, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			row.add_theme_color_override(k, Color(0.93, 0.95, 0.98))
		row.pressed.connect(func():
			_sel_stat = id
			_render())
		_list.add_child(row)
	var cur: Dictionary = STATS.filter(func(x): return x["id"] == _sel_stat)[0]
	var n: int = Game.stats[_sel_stat]
	_d_name.text = "%s %s" % [cur["icon"], cur["name"]]
	_d_kind.text = "Характеристика · по %d очка за каждый уровень" % Game.STAT_PER_LEVEL
	_d_rank.text = "Вложено очков: %d" % n
	match _sel_stat:
		"str":
			_d_now.text = "Сейчас: урон +%d" % (n * Game.STAT_STR)
			_d_next.text = "Каждое очко: урон +%d" % Game.STAT_STR
		"agi":
			_d_now.text = "Сейчас: удары быстрее на %d%%, крит +%d%%" % [roundi(n * Game.STAT_AGI_SPEED * 100), roundi(n * Game.STAT_AGI_CRIT * 100)]
			_d_next.text = "Каждое очко: удары быстрее на %d%%, крит +%d%%" % [roundi(Game.STAT_AGI_SPEED * 100), roundi(Game.STAT_AGI_CRIT * 100)]
		"vit":
			_d_now.text = "Сейчас: здоровье +%d" % (n * Game.STAT_VIT)
			_d_next.text = "Каждое очко: здоровье +%d" % Game.STAT_VIT
	_d_need.text = ""
	_up.text = "+1 очко"
	_up.disabled = free <= 0
	_evo.visible = false

## Правая половина: что даёт навык сейчас и на следующем ранге, кнопки
func _render_info(free: int) -> void:
	_evo.visible = true
	if _sel == "dash" and SkillDefs.dash_form(Game.skills) != "dash":
		_render_dash_evo(free)
		return
	var s: Dictionary = SkillDefs.find(_sel)
	var r := Game.rank(_sel)
	var mx: int = s["max"]
	var locked: bool = Game.level < s["lvl"]
	_d_name.text = "%s %s" % [s["icon"], s["name"]]
	_d_kind.text = "Умение — своя кнопка на экране" if s.get("active", false) else "Пассивный навык"
	_d_rank.text = "Ранг %d / %d" % [r, mx]
	_d_now.text = ("Сейчас: " + SkillDefs.desc(_sel, r)) if r > 0 else "Ещё не изучен"
	if r < mx:
		_d_next.text = "Следующий ранг: " + SkillDefs.desc(_sel, r + 1)
	else:
		_d_next.text = "Максимальный ранг — открыта эволюция"
	_d_need.text = "Нужен уровень %d" % s["lvl"] if locked else ""
	_up.text = "Изучить" if r == 0 else "Улучшить"
	_up.disabled = locked or r >= mx or free <= 0
	# Эволюция — на максимальном ранге (у рывка — в Скользящий шаг, у остальных пока закрыта)
	if _sel == "dash":
		_d_next.text += "\nНа %d уровне — эволюция в Скользящий шаг" % mx if r < mx else ""
		_evo.text = "✨ Эволюция: Скользящий шаг" if Game.can_evolve("dash") else "✨ Эволюция  🔒"
		_evo.disabled = not Game.can_evolve("dash")
		return
	var evo_ready: bool = r >= mx and SkillDefs.EVOLUTION_ENABLED
	_evo.text = "✨ Эволюция" if evo_ready else "✨ Эволюция  🔒"
	_evo.disabled = not evo_ready

## Рывок после эволюции: Скользящий шаг (5 уровней) и прорыв в Мерцание
func _render_dash_evo(free: int) -> void:
	var form := SkillDefs.dash_form(Game.skills)
	var st := SkillDefs.dash_stats(Game.skills)
	_d_kind.text = "Умение — своя кнопка на экране · эволюция Рывка"
	_d_need.text = ""
	_d_now.text = "Сейчас: " + SkillDefs.dash_desc(st["speed"], st["cd"])
	if form == "blink":
		_d_name.text = "✨ Мерцание"
		_d_rank.text = "Прорыв · высшая форма"
		_d_next.text = "Герой исчезает и появляется впереди"
		_up.text = "Максимум"
		_up.disabled = true
		_evo.text = "⚡ Прорыв пройден"
		_evo.disabled = true
		return
	var sl := Game.rank("dash_slide")
	_d_name.text = "🌬️ Скользящий шаг"
	_d_rank.text = "Уровень %d / %d" % [sl, SkillDefs.SLIDE_MAX]
	if sl < SkillDefs.SLIDE_MAX:
		var nx := Game.skills.duplicate()
		nx["dash_slide"] = sl + 1
		var ns := SkillDefs.dash_stats(nx)
		_d_next.text = "Следующий уровень: " + SkillDefs.dash_desc(ns["speed"], ns["cd"]) + "\nНа %d уровне — прорыв в Мерцание" % SkillDefs.SLIDE_MAX
	else:
		_d_next.text = "Прорыв в Мерцание: скорость +200%, откат 3 с"
	_up.text = "Улучшить"
	_up.disabled = sl >= SkillDefs.SLIDE_MAX or free <= 0
	_evo.text = "⚡ Прорыв: Мерцание" if Game.can_evolve("dash") else "⚡ Прорыв  🔒"
	_evo.disabled = not Game.can_evolve("dash")

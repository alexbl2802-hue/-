## Кузница: улучшение надетого оружия за золото и соединение трёх одинаковых вещей
## одного ранга в одну вещь следующего ранга (нужны тёмные осколки из подземелий).
extends Control

signal closed

var _money: Control
var _tabs: VBoxContainer
var _up_box: VBoxContainer
var _list: VBoxContainer
var _note: Label
var _tab := "upgrade"
var _forge_box: VBoxContainer
var _pages := {}

const TABS := [["upgrade", "⚒  Улучшение"], ["combine", "♻  Соединение"], ["forge", "🔥  Ковка"]]

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	_money = UiKit.header(vb, "Кузница", close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	# Слева — вкладки
	var tc: Array = UiKit.tab_column(150)
	body.add_child(tc[0])
	_tabs = tc[1]
	# В центре — страница выбранной вкладки
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	var mp := UiKit.card(mid, 10)
	mp.custom_minimum_size = Vector2(410, 262)
	body.add_child(mp)
	_up_box = VBoxContainer.new()
	_up_box.add_theme_constant_override("separation", 6)
	_up_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_up_box)
	_pages["upgrade"] = _up_box
	var combine := VBoxContainer.new()
	combine.add_theme_constant_override("separation", 6)
	combine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combine.add_child(_caption("Соединение предметов"))
	var hint := UiKit.label("%d одинаковые вещи одного ранга → 1 вещь следующего ранга. Нужны 🔮 тёмные осколки из подземелий." % Items.COMBINE_COUNT, 11, UiKit.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(390, 0)
	combine.add_child(hint)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combine.add_child(_scroll(_list, 176))
	mid.add_child(combine)
	_pages["combine"] = combine
	var forge := VBoxContainer.new()
	forge.add_theme_constant_override("separation", 6)
	forge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forge.add_child(_caption("Ковка уникального оружия"))
	_forge_box = VBoxContainer.new()
	_forge_box.add_theme_constant_override("separation", 6)
	_forge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge.add_child(_scroll(_forge_box, 206))
	mid.add_child(forge)
	_pages["forge"] = forge
	_note = UiKit.label("", 12, UiKit.CREAM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_note)
	# Справа — редкость предметов
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 5)
	var rp := UiKit.card(rv, 8)
	rp.custom_minimum_size = Vector2(196, 0)
	body.add_child(rp)
	rv.add_child(_caption("Редкость предметов"))
	for i in Items.RANKS.size():
		var rk: Dictionary = Items.RANKS[i]
		var c: Color = rk["color"]
		var bg := c.darkened(0.82)
		bg.a = 0.95
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var cube := UiKit.label("◆", 20, c)
		cube.add_theme_color_override("font_shadow_color", Color(c, 0.6))
		cube.add_theme_constant_override("shadow_outline_size", 6)
		row.add_child(cube)
		var nm := UiKit.label(rk["name"], 13, c)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UiKit.label("×%s" % str(rk["mult"]), 12, UiKit.TEXT))
		var p := PanelContainer.new()
		var st := UiKit.glow(UiKit.box(bg, Color(c, 0.55), 6, 5, 1), 3, 0.25, c)
		st.content_margin_left = 8
		st.content_margin_right = 8
		p.add_theme_stylebox_override("panel", st)
		p.add_child(row)
		rv.add_child(p)

func _caption(t: String) -> Label:
	var l := UiKit.label(t, 15, Color("#f4f7fc"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _scroll(content: Control, h: float) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(390, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(content)
	return sc

func open() -> void:
	_note.text = ""
	_render()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _render() -> void:
	for c in _money.get_children():
		_money.remove_child(c)
		c.queue_free()
	_money.add_child(UiKit.money_bar(Game.gold, Game.count_of("shard")))
	_clear(_tabs)
	for t in TABS:
		var key: String = t[0]
		var tb := UiKit.tab(t[1], key == _tab, 13)
		tb.pressed.connect(func():
			_tab = key
			_note.text = ""
			_render())
		_tabs.add_child(tb)
	for k in _pages:
		(_pages[k] as Control).visible = k == _tab
	match _tab:
		"forge": _render_forge()
		"combine": _render_combine()
		_: _render_upgrade()

## Ковка: уникальное оружие из материалов боссов
func _render_forge() -> void:
	_clear(_forge_box)
	var hint := UiKit.label("Материалы боссов + 🔮 тёмные осколки + 🪙 золото → уникальное оружие со своим свечением", 11, UiKit.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(370, 0)
	_forge_box.add_child(hint)
	for rec in Items.RECIPES:
		var inst := Items.make(rec["id"])
		var it := Items.get_item(rec["id"])
		var mat := Items.get_item(rec["mat"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.slot(it["icon"], Items.color(inst), "", "", 40.0))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label("%s — %s" % [it["name"], Items.rank_of(inst)["name"]], 13, Items.color(inst)))
		info.add_child(UiKit.label(Items.lines(inst), 10, Color(1, 1, 1, 0.75)))
		info.add_child(UiKit.label("Нужно: %s %s (%d/1) · 🔮 %d (%d) · 🪙 %d" % [mat["icon"], mat["name"], Game.count_of(rec["mat"]), rec["shards"], Game.count_of("shard"), rec["gold"]], 10, Color(1, 0.9, 0.7, 0.85)))
		row.add_child(info)
		var why := Game.can_forge(rec)
		var b := UiKit.button("Выковать" if why == "" else why, why == "", 12)
		b.disabled = why != ""
		b.custom_minimum_size = Vector2(110, 0)
		b.pressed.connect(func():
			if Game.forge(rec):
				_note.text = "🔥 Выковано: %s" % Items.title(Items.make(rec["id"]))
			_render())
		row.add_child(b)
		_forge_box.add_child(row)

func _render_upgrade() -> void:
	_clear(_up_box)
	_up_box.add_child(_caption("Улучшение предмета"))
	var w = Game.equip["weapon"]
	if w == null:
		var l := UiKit.label("Надень оружие, чтобы улучшить его", 12, UiKit.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_up_box.add_child(l)
		return
	var it := Items.get_item(w["id"])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(UiKit.slot(it["icon"], Items.color(w), "+%d" % w["u"] if w["u"] > 0 else "", "", 60.0))
	if w["u"] < Items.MAX_UPGRADE:
		row.add_child(UiKit.label("➜", 26, UiKit.GOLD))
		row.add_child(UiKit.slot(it["icon"], Items.color(w), "+%d" % (w["u"] + 1), "", 60.0, true))
	_up_box.add_child(row)
	var nm := UiKit.label("%s  ·  %s  ·  ступень %d / %d" % [it["name"], Items.rank_of(w)["name"], w["u"], Items.MAX_UPGRADE], 12, Items.color(w))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_box.add_child(nm)
	_up_box.add_child(UiKit.line())
	var dmg := Items.stat(w, "dmg")
	if w["u"] >= Items.MAX_UPGRADE:
		_up_box.add_child(UiKit.stat_row("Урон оружия", "+%d — улучшено до предела" % dmg, Color("#7dff8a")))
	else:
		_up_box.add_child(UiKit.stat_row("Урон оружия", "+%d  →  +%d" % [dmg, dmg + Items.UPGRADE_DMG], Color("#7dff8a")))
	# Починка: прочность оружия и цена
	if w.has("d"):
		var rep := HBoxContainer.new()
		rep.add_theme_constant_override("separation", 8)
		var full: bool = w["d"] >= Items.max_dur(w)
		var dl := UiKit.label("🔧 Прочность %d / %d" % [w["d"], Items.max_dur(w)], 12, Color("#ff8a7a") if Items.broken(w) else UiKit.TEXT)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep.add_child(dl)
		var rb := UiKit.button("Целое" if full else "Починить · 🪙 %d" % Items.repair_cost(w), false, 12)
		rb.disabled = full or Game.gold < Items.repair_cost(w)
		rb.pressed.connect(func():
			if Game.repair_weapon():
				_note.text = "🔧 Оружие как новое"
			_render())
		rep.add_child(rb)
		_up_box.add_child(rep)
	if w["u"] >= Items.MAX_UPGRADE:
		return
	var cost := Items.upgrade_cost(w["u"])
	var cl := UiKit.label("Стоимость:  🪙 %s" % UiKit.group(cost), 14, UiKit.GOLD if Game.gold >= cost else Color("#ff9a7a"))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_box.add_child(cl)
	var b := UiKit.button("Улучшить", true, 16)
	b.custom_minimum_size = Vector2(240, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.disabled = Game.gold < cost
	b.pressed.connect(func():
		if Game.upgrade_weapon():
			_note.text = "⚒ %s — урон +%d" % [Items.title(Game.equip["weapon"]), Items.stat(Game.equip["weapon"], "dmg")]
		_render())
	_up_box.add_child(b)

func _render_combine() -> void:
	_clear(_list)
	var groups := Game.combine_groups()
	if groups.is_empty():
		_list.add_child(UiKit.label("Нет оружия и снаряжения для соединения", 12, Color(1, 1, 1, 0.6)))
		return
	for g in groups:
		var inst := {"id": g["id"], "r": g["r"], "u": 0, "n": 1}
		var it := Items.get_item(g["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.slot(it["icon"], Items.color(inst), "", "", 36.0))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(it["name"], 12, Items.color(inst)))
		var r: int = g["r"]
		if r < Items.MAX_RANK:
			var cost := Items.combine_cost(r)
			info.add_child(UiKit.label("%s → %s · есть %d / %d · 🔮 %d  🪙 %d" % [Items.RANKS[r]["name"], Items.RANKS[r + 1]["name"], g["count"], Items.COMBINE_COUNT, cost[0], cost[1]], 10, Color(1, 1, 1, 0.75)))
		else:
			info.add_child(UiKit.label("Легендарный — высший ранг", 10, Items.RANKS[r]["color"]))
		row.add_child(info)
		var why := Game.can_combine(g["id"], r)
		var b := UiKit.button("Соединить" if why == "" else why, why == "", 12)
		b.disabled = why != ""
		b.custom_minimum_size = Vector2(110, 0)
		b.pressed.connect(func():
			var res := Game.combine(g["id"], r)
			if not res.is_empty():
				_note.text = "✨ Получено: %s — %s" % [Items.title(res), Items.rank_of(res)["name"]]
			_render())
		row.add_child(b)
		_list.add_child(row)

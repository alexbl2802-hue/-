## Кузница: улучшение надетого оружия за золото и соединение трёх одинаковых вещей
## одного ранга в одну вещь следующего ранга (нужны тёмные осколки из подземелий).
extends Control

signal closed

var _money: Label
var _up_box: VBoxContainer
var _list: VBoxContainer
var _note: Label
var _tab := "main"
var _tab_btns := {}
var _body: Control
var _forge_box: VBoxContainer
var _forge_scroll: Control

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	vb.add_child(head)
	head.add_child(UiKit.label("⚒ Кузница", 18, UiKit.GOLD))
	_money = UiKit.label("", 15, Color("#ffd34d"))
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_money)
	var x := UiKit.button("✕")
	x.pressed.connect(close)
	head.add_child(x)
	# Ранги: от простого к легендарному
	var ranks := HBoxContainer.new()
	ranks.add_theme_constant_override("separation", 6)
	ranks.add_child(UiKit.label("Ранги:", 11, Color(1, 1, 1, 0.6)))
	for i in Items.RANKS.size():
		ranks.add_child(UiKit.label(Items.RANKS[i]["name"] + (" →" if i < Items.MAX_RANK else ""), 11, Items.RANKS[i]["color"]))
	vb.add_child(ranks)
	# Вкладки: «Кузня» (улучшение, починка, соединение) и «Ковка» (уникальное оружие)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	for t in [["main", "⚒ Кузня"], ["forge", "🔥 Ковка"]]:
		var tb := UiKit.button(t[1], false, 13)
		var key: String = t[0]
		tb.pressed.connect(func():
			_tab = key
			_render())
		tabs.add_child(tb)
		_tab_btns[key] = tb
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	vb.add_child(body)
	_body = body
	var fscroll := ScrollContainer.new()
	fscroll.custom_minimum_size = Vector2(740, 230)
	fscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(fscroll)
	_forge_box = VBoxContainer.new()
	_forge_box.add_theme_constant_override("separation", 6)
	_forge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fscroll.add_child(_forge_box)
	_forge_scroll = fscroll
	_up_box = VBoxContainer.new()
	_up_box.add_theme_constant_override("separation", 6)
	body.add_child(_card("Улучшение оружия", _up_box, 300))
	var combine := VBoxContainer.new()
	combine.add_theme_constant_override("separation", 6)
	var hint := UiKit.label("%d одинаковые вещи одного ранга → 1 вещь следующего ранга. Нужны 🔮 тёмные осколки из подземелий." % Items.COMBINE_COUNT, 11, Color(1, 1, 1, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	combine.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	combine.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	body.add_child(_card("Соединение", combine, 430))
	_note = UiKit.label("", 12, UiKit.CREAM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_note)

func _card(title: String, content: Control, w: float) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.45, 0.85, 1.0, 0.05), Color(0.45, 0.85, 1.0, 0.3), 2, 9))
	panel.custom_minimum_size = Vector2(w, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UiKit.label(title, 15, UiKit.CREAM))
	vb.add_child(content)
	return panel

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
	_money.text = "🪙 %d    🔮 %d" % [Game.gold, Game.count_of("shard")]
	for k in _tab_btns:
		(_tab_btns[k] as Button).text = ("● " if k == _tab else "") + ("⚒ Кузня" if k == "main" else "🔥 Ковка")
	_body.visible = _tab == "main"
	_forge_scroll.visible = _tab == "forge"
	if _tab == "forge":
		_render_forge()
		return
	_render_upgrade()
	_render_combine()

## Ковка: уникальное оружие из материалов боссов
func _render_forge() -> void:
	_clear(_forge_box)
	_forge_box.add_child(UiKit.label("Материалы боссов + 🔮 тёмные осколки + 🪙 золото → уникальное оружие со своим свечением", 11, Color(1, 1, 1, 0.75)))
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
		b.custom_minimum_size = Vector2(130, 0)
		b.pressed.connect(func():
			if Game.forge(rec):
				_note.text = "🔥 Выковано: %s" % Items.title(Items.make(rec["id"]))
			_render())
		row.add_child(b)
		_forge_box.add_child(row)

func _render_upgrade() -> void:
	_clear(_up_box)
	var w = Game.equip["weapon"]
	if w == null:
		_up_box.add_child(UiKit.label("Надень оружие, чтобы улучшить его", 12))
		return
	var it := Items.get_item(w["id"])
	# Починка: прочность оружия и цена
	if w.has("d"):
		var rep := HBoxContainer.new()
		rep.add_theme_constant_override("separation", 8)
		var full: bool = w["d"] >= Items.max_dur(w)
		rep.add_child(UiKit.label("🔧 Прочность %d / %d" % [w["d"], Items.max_dur(w)], 12, Color("#ff8a7a") if Items.broken(w) else UiKit.TEXT))
		var rb := UiKit.button("Целое" if full else "Починить за 🪙 %d" % Items.repair_cost(w), not full, 12)
		rb.disabled = full or Game.gold < Items.repair_cost(w)
		rb.pressed.connect(func():
			if Game.repair_weapon():
				_note.text = "🔧 Оружие как новое"
			_render())
		rep.add_child(rb)
		_up_box.add_child(rep)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.slot(it["icon"], Items.color(w), "+%d" % w["u"] if w["u"] > 0 else "", "", 52.0))
	if w["u"] < Items.MAX_UPGRADE:
		row.add_child(UiKit.label("→", 20))
		row.add_child(UiKit.slot(it["icon"], Items.color(w), "+%d" % (w["u"] + 1), "", 52.0))
	_up_box.add_child(row)
	_up_box.add_child(UiKit.label(Items.title(w), 14, Items.color(w)))
	_up_box.add_child(UiKit.label("%s · ступень %d / %d" % [Items.rank_of(w)["name"], w["u"], Items.MAX_UPGRADE], 11, Color(1, 1, 1, 0.7)))
	if w["u"] >= Items.MAX_UPGRADE:
		_up_box.add_child(UiKit.label("Урон +%d — улучшено до предела" % Items.stat(w, "dmg"), 12, Color("#7dff8a")))
		return
	var dmg := Items.stat(w, "dmg")
	_up_box.add_child(UiKit.label("Урон оружия: +%d → +%d" % [dmg, dmg + Items.UPGRADE_DMG], 12))
	var cost := Items.upgrade_cost(w["u"])
	var b := UiKit.button("Улучшить за 🪙 %d" % cost, true, 14)
	b.disabled = Game.gold < cost
	b.pressed.connect(func():
		if Game.upgrade_weapon():
			_note.text = "⚒ %s — урон +%d" % [Items.title(Game.equip["weapon"]), Items.stat(Game.equip["weapon"], "dmg")]
		_render())
	_up_box.add_child(b)
	if Game.gold < cost:
		_up_box.add_child(UiKit.label("Не хватает золота", 11, Color("#ff9a7a")))

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
		b.custom_minimum_size = Vector2(120, 0)
		b.pressed.connect(func():
			var res := Game.combine(g["id"], r)
			if not res.is_empty():
				_note.text = "✨ Получено: %s — %s" % [Items.title(res), Items.rank_of(res)["name"]]
			_render())
		row.add_child(b)
		_list.add_child(row)

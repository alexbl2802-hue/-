## Инвентарь: характеристики героя, 4 слота снаряжения, 20 ячеек и описание выбранного предмета.
extends Control

signal closed

const SLOT_NAMES := {"weapon": ["Оружие", "🗡️"], "armor": ["Доспех", "🧥"], "helm": ["Шлем", "⛑️"], "amulet": ["Амулет", "📿"]}

var hero: Node   # для зелья (всплывающая надпись над героем)
var _gold: Label
var _stats: VBoxContainer
var _equip: HBoxContainer
var _grid: GridContainer
var _info: VBoxContainer
var _sel := {}   # {"i": номер ячейки} или {"eq": слот}

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(UiKit.label("Инвентарь", 18, UiKit.GOLD))
	_gold = UiKit.label("", 15, Color("#ffd34d"))
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_gold)
	var x := UiKit.button("✕")
	x.pressed.connect(close)
	head.add_child(x)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	vb.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 1)
	left.add_child(_stats)
	_equip = HBoxContainer.new()
	_equip.add_theme_constant_override("separation", 6)
	left.add_child(_equip)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	right.add_child(_grid)
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 8, 8, 1))
	info_panel.custom_minimum_size = Vector2(0, 86)
	right.add_child(info_panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 3)
	info_panel.add_child(_info)

func open() -> void:
	_sel = {}
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
	_gold.text = "🪙 %d    🔮 %d" % [Game.gold, Game.count_of("shard")]
	_clear(_stats)
	var need := Game.xp_next(Game.level)
	_stats.add_child(UiKit.label("Уровень %d" % Game.level, 14, UiKit.GOLD))
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = Game.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.add_theme_stylebox_override("background", UiKit.box(Color.BLACK, Color.BLACK, 4, 0, 0))
	bar.add_theme_stylebox_override("fill", UiKit.box(Color("#5ab8e8"), Color("#5ab8e8"), 4, 0, 0))
	_stats.add_child(bar)
	var cut := roundi(100.0 - 10000.0 / (100.0 + Game.armor * 4))
	for t in ["Опыт: %d / %d" % [Game.xp, need], "❤️ Здоровье: %d / %d" % [ceili(Game.hp), roundi(Game.max_hp)],
			"⚔️ Урон: %d–%d" % [Game.dmg, Game.dmg + 8], "🛡️ Броня: %d  (−%d%% урона)" % [Game.armor, cut], "💀 Побеждено врагов: %d" % Game.kills]:
		_stats.add_child(UiKit.label(t, 12))
	_clear(_equip)
	for slot in Items.SLOTS:
		var e = Game.equip[slot]
		var b: Button
		if e == null:
			b = UiKit.slot(SLOT_NAMES[slot][1], Color(1, 1, 1, 0.15), "", SLOT_NAMES[slot][0], 58.0)
			b.modulate.a = 0.45
		else:
			var it := Items.get_item(e["id"])
			b = UiKit.slot(it["icon"], Items.color(e), "+%d" % e["u"] if e["u"] > 0 else "", SLOT_NAMES[slot][0], 58.0, _sel.get("eq", "") == slot)
			b.pressed.connect(func(): _sel = {"eq": slot}; _render())
		_equip.add_child(b)
	_clear(_grid)
	for i in Items.INV_SIZE:
		var b: Button
		if i < Game.inv.size():
			var st: Dictionary = Game.inv[i]
			var it := Items.get_item(st["id"])
			var badge := str(st["n"]) if st["n"] > 1 else ("+%d" % st["u"] if st["u"] > 0 else "")
			b = UiKit.slot(it["icon"], Items.color(st), badge, "", 40.0, _sel.get("i", -1) == i)
			var idx := i
			b.pressed.connect(func(): _sel = {"i": idx}; _render())
		else:
			b = UiKit.slot("", Color(1, 1, 1, 0.15), "", "", 40.0)
		_grid.add_child(b)
	_render_info()

func _render_info() -> void:
	_clear(_info)
	var inst := {}
	var from_inv: bool = _sel.has("i") and _sel["i"] < Game.inv.size()
	var from_eq: bool = _sel.has("eq") and Game.equip[_sel["eq"]] != null
	if from_inv:
		inst = Game.inv[_sel["i"]]
	elif from_eq:
		inst = Game.equip[_sel["eq"]]
	if inst.is_empty():
		var l := UiKit.label("Нажми на предмет, чтобы посмотреть его. Предметы выпадают из монстров и сундуков, а в кузнице их можно улучшать и соединять.", 12, Color(1, 1, 1, 0.6))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(440, 0)
		_info.add_child(l)
		return
	var it := Items.get_item(inst["id"])
	_info.add_child(UiKit.label(Items.title(inst), 15, Items.color(inst)))
	var rank_txt: String = "" if it["kind"] in ["potion", "material"] else Items.rank_of(inst)["name"] + " · "
	_info.add_child(UiKit.label(rank_txt + Items.lines(inst), 12))
	if from_inv and Items.SLOTS.has(it["kind"]) and Game.equip[it["kind"]] != null:
		var cur: Dictionary = Game.equip[it["kind"]]
		_info.add_child(UiKit.label("Сейчас надето: %s, %s (%s)" % [Items.title(cur), Items.rank_of(cur)["name"].to_lower(), Items.lines(cur)], 11, Color(1, 1, 1, 0.6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_info.add_child(row)
	if from_inv:
		var i: int = _sel["i"]
		if it["kind"] == "potion":
			var b := UiKit.button("Выпить", true)
			b.pressed.connect(func():
				if hero:
					hero.drink_potion()
				_render())
			row.add_child(b)
		elif Items.SLOTS.has(it["kind"]):
			var b := UiKit.button("Надеть", true)
			b.pressed.connect(func(): Game.equip_from(i); _sel = {}; _render())
			row.add_child(b)
		var d := UiKit.button("Выбросить")
		d.pressed.connect(func(): Game.drop_item(i); _sel = {}; _render())
		row.add_child(d)
	else:
		var b := UiKit.button("Снять")
		b.pressed.connect(func():
			if not Game.unequip(_sel["eq"]):
				Fx.text("Инвентарь полон", hero.global_position, Color("#ff8a6a"))
			_sel = {}
			_render())
		row.add_child(b)

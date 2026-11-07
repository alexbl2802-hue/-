## Инвентарь: слева вкладки-фильтры, в центре ячейки предметов, справа описание выбранного предмета
## (если ничего не выбрано — герой: уровень, характеристики и 8 слотов снаряжения), внизу золото.
extends Control

signal closed

const SLOT_NAMES := {"weapon": ["Оружие", "🗡️"], "armor": ["Доспех", "🧥"], "helm": ["Шлем", "⛑️"], "amulet": ["Амулет", "📿"],
	"boots": ["Сапоги", "👢"], "ring": ["Кольцо", "💍"], "cloak": ["Плащ", "🧣"], "shield": ["Щит", "🔰"]}
const FILTERS := [
	["all", "▦  Все", []],
	["weapon", "⚔  Оружие", ["weapon"]],
	["armor", "🛡️  Броня", ["armor", "helm", "boots", "cloak", "shield"]],
	["acc", "💍  Аксессуары", ["amulet", "ring"]],
	["potion", "⚗  Расходники", ["potion"]],
	["material", "💎  Материалы", ["material"]],
]
const CELL := 46.0

var hero: Node   # для зелья (всплывающая надпись над героем)
var _count: Label
var _tabs: VBoxContainer
var _grid: GridContainer
var _info: VBoxContainer
var _money: Control
var _bottom: HBoxContainer
var _filter := "all"
var _sel := {}   # {"i": номер ячейки} или {"eq": слот}

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	var extra := UiKit.header(vb, "Инвентарь", close)
	_count = UiKit.label("", 17, Color("#e8eef8"))
	extra.add_child(_count)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var tc: Array = UiKit.tab_column(146)
	body.add_child(tc[0])
	_tabs = tc[1]
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	body.add_child(mid)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(CELL * 5 + 6 * 4 + 4, CELL * 4 + 6 * 3)
	scroll.add_child(_grid)
	mid.add_child(UiKit.card(scroll, 8))
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(_bottom)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 4)
	var ip := UiKit.card(_info, 10)
	ip.custom_minimum_size = Vector2(272, 0)
	body.add_child(ip)

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

func _kinds() -> Array:
	for f in FILTERS:
		if f[0] == _filter:
			return f[2]
	return []

func _render() -> void:
	_count.text = "%d / %d" % [Game.inv.size(), Items.INV_SIZE]
	_clear(_tabs)
	for f in FILTERS:
		var key: String = f[0]
		var tb := UiKit.tab(f[1], key == _filter, 13)
		tb.custom_minimum_size.y = 34
		tb.pressed.connect(func():
			_filter = key
			_sel = {}
			_render())
		_tabs.add_child(tb)
	_clear(_grid)
	var kinds := _kinds()
	var shown := 0
	for i in Game.inv.size():
		var st: Dictionary = Game.inv[i]
		var it := Items.get_item(st["id"])
		if not kinds.is_empty() and not kinds.has(it["kind"]):
			continue
		var badge := str(st["n"]) if st["n"] > 1 else ("+%d" % st["u"] if st["u"] > 0 else "")
		var sel: bool = _sel.get("i", -1) == i
		var b := UiKit.slot(it["icon"], Items.color(st), badge, "", CELL, sel)
		var idx := i
		b.pressed.connect(func():
			_sel = {} if sel else {"i": idx}
			_render())
		_grid.add_child(b)
		shown += 1
	var cells := Items.INV_SIZE if kinds.is_empty() else maxi(10, ceili(shown / 5.0) * 5)
	for k in range(shown, cells):
		_grid.add_child(UiKit.slot("", Color(1, 1, 1, 0.15), "", "", CELL))
	_clear(_bottom)
	_bottom.add_child(UiKit.money_bar(Game.gold, Game.count_of("shard")))
	_render_info()

## Справа: выбранный предмет или герой со снаряжением
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
		_render_hero()
		return
	var it := Items.get_item(inst["id"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_info.add_child(top)
	top.add_child(UiKit.slot(it["icon"], Items.color(inst), "+%d" % inst["u"] if int(inst.get("u", 0)) > 0 else "", "", 60.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var nm := UiKit.label(it["name"], 16, Color("#f4f7fc"))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(nm)
	if not it["kind"] in ["potion", "material"]:
		names.add_child(UiKit.label(Items.rank_of(inst)["name"], 14, Items.color(inst)))
	if int(inst.get("u", 0)) > 0:
		names.add_child(UiKit.label("Улучшение +%d" % inst["u"], 12, UiKit.DIM))
	if int(inst.get("n", 1)) > 1:
		names.add_child(UiKit.label("Количество: %d" % inst["n"], 12, UiKit.DIM))
	_info.add_child(UiKit.line())
	for part in Items.lines(inst).split(" · "):
		var l := UiKit.label(part, 12, Color("#7dff8a") if part.contains("+") else UiKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(l)
	if from_inv and Items.SLOTS.has(it["kind"]) and Game.equip[it["kind"]] != null:
		var cur: Dictionary = Game.equip[it["kind"]]
		_info.add_child(UiKit.line())
		_info.add_child(UiKit.label("Сейчас надето:", 12, GOLD_DIM))
		var cl := UiKit.label("%s, %s" % [Items.title(cur), Items.rank_of(cur)["name"].to_lower()], 11, Items.color(cur))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(cl)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
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
		var b := UiKit.button("Снять", true)
		b.pressed.connect(func():
			if not Game.unequip(_sel["eq"]):
				Fx.text("Инвентарь полон", hero.global_position, Color("#ff8a6a"))
			_sel = {}
			_render())
		row.add_child(b)
		var back := UiKit.button("Назад")
		back.pressed.connect(func(): _sel = {}; _render())
		row.add_child(back)

const GOLD_DIM := Color("#e8c060")

func _render_hero() -> void:
	var need := Game.xp_next(Game.level)
	_info.add_child(UiKit.label("%s · Ур. %d" % [Game.player_name, Game.level], 16, Color("#f4f7fc")))
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = Game.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.add_theme_stylebox_override("background", UiKit.box(Color("#0b1322"), UiKit.LINE, 3, 0, 1))
	bar.add_theme_stylebox_override("fill", UiKit.glow(UiKit.box(Color("#4aa8ff"), Color("#4aa8ff"), 3, 0, 0), 4, 0.5))
	_info.add_child(bar)
	var cut := roundi(100.0 - 10000.0 / (100.0 + Game.armor * 4))
	_info.add_child(UiKit.stat_row("Опыт", "%d / %d" % [Game.xp, need], UiKit.DIM))
	_info.add_child(UiKit.stat_row("❤  Здоровье", "%d / %d" % [ceili(Game.hp), roundi(Game.max_hp)]))
	_info.add_child(UiKit.stat_row("⚔  Урон", "%d–%d" % [Game.dmg, Game.dmg + 8]))
	_info.add_child(UiKit.stat_row("🛡️  Броня", "%d  (−%d%%)" % [Game.armor, cut]))
	_info.add_child(UiKit.stat_row("💀  Побеждено", str(Game.kills)))
	_info.add_child(UiKit.line())
	_info.add_child(UiKit.label("Снаряжение", 12, GOLD_DIM))
	var eq := GridContainer.new()
	eq.columns = 4
	eq.add_theme_constant_override("h_separation", 6)
	eq.add_theme_constant_override("v_separation", 6)
	_info.add_child(eq)
	for slot in Items.SLOTS:
		var e = Game.equip[slot]
		var b: Button
		if e == null:
			b = UiKit.slot(SLOT_NAMES[slot][1], Color(1, 1, 1, 0.15), "", SLOT_NAMES[slot][0], 48.0)
			b.modulate.a = 0.5
		else:
			var it := Items.get_item(e["id"])
			b = UiKit.slot(it["icon"], Items.color(e), "+%d" % e["u"] if e["u"] > 0 else "", SLOT_NAMES[slot][0], 48.0)
			b.pressed.connect(func(): _sel = {"eq": slot}; _render())
		eq.add_child(b)

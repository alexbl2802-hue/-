## Лавка алхимика: зелья только здесь — купить за золото или сварить из эссенций монстров.
extends Control

signal closed

var _money: Label
var _stock: Label
var _buy: Button
var _brew: Button
var _note: Label

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	var extra := UiKit.header(vb, "Лавка алхимика", close)
	_money = UiKit.label("", 16, Color("#ffe08a"))
	extra.add_child(_money)
	vb.add_child(UiKit.label("С монстров зелья не падают — их покупают или варят здесь из эссенций монстров.", 12, UiKit.DIM))
	_stock = UiKit.label("", 14)
	vb.add_child(_stock)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	vb.add_child(rows)
	# Купить
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 12)
	rows.add_child(r1)
	var l1 := UiKit.label("🧪 Зелье лечения (+%d здоровья) — %d 🪙" % [Items.ALL["potion"]["heal"], Items.POTION_PRICE], 14)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(l1)
	_buy = UiKit.button("Купить", true, 14)
	_buy.custom_minimum_size = Vector2(140, 40)
	_buy.pressed.connect(func():
		_note.text = "Куплено зелье лечения" if Game.buy_potion() else "Не хватает золота или места в сумке"
		_render())
	r1.add_child(_buy)
	# Сварить
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 12)
	rows.add_child(r2)
	var l2 := UiKit.label("⚗ Сварить зелье: %d 💠 эссенции + %d 🪙" % [Items.BREW_ESSENCE, Items.BREW_GOLD], 14)
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(l2)
	_brew = UiKit.button("Сварить", false, 14)
	_brew.custom_minimum_size = Vector2(140, 40)
	_brew.pressed.connect(func():
		_note.text = "Зелье сварено" if Game.brew_potion() else "Не хватает эссенции или золота"
		_render())
	r2.add_child(_brew)
	_note = UiKit.label("", 13, UiKit.CREAM)
	vb.add_child(_note)

func open() -> void:
	_note.text = ""
	_render()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _render() -> void:
	_money.text = "🪙 %d" % Game.gold
	_stock.text = "В сумке: 🧪 зелий — %d · 💠 эссенции — %d" % [Game.potions(), Game.count_of("essence")]
	_buy.disabled = Game.gold < Items.POTION_PRICE
	_brew.disabled = Game.count_of("essence") < Items.BREW_ESSENCE or Game.gold < Items.BREW_GOLD

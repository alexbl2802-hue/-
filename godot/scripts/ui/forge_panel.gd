## Кузница: «Улучшение оружия» и «Объединение» — окна уже есть, но пока закрыты.
extends Control

signal closed

const ENABLED := false  # включим, когда доделаем систему улучшения

var _upgrade_info: Label
var _weapon: HBoxContainer

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := UiKit.label("⚒ Кузница", 18, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiKit.button("✕")
	x.pressed.connect(close)
	head.add_child(x)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	vb.add_child(body)
	_weapon = HBoxContainer.new()
	_upgrade_info = UiKit.label("", 12)
	body.add_child(_card("Улучшение оружия", "Закаляй надетое оружие: каждая ступень добавляет урон. Нужны золото и материалы.", _weapon, _upgrade_info, "Улучшить"))
	var combine := HBoxContainer.new()
	combine.alignment = BoxContainer.ALIGNMENT_CENTER
	combine.add_theme_constant_override("separation", 8)
	combine.add_child(UiKit.slot("", Color(1, 1, 1, 0.2), "", "", 48.0))
	combine.add_child(UiKit.label("+", 20))
	combine.add_child(UiKit.slot("", Color(1, 1, 1, 0.2), "", "", 48.0))
	combine.add_child(UiKit.label("=", 20))
	combine.add_child(UiKit.slot("❔", Color(1, 1, 1, 0.2), "", "", 48.0))
	body.add_child(_card("Объединение", "Объедини два предмета, чтобы получить новый — более редкий и сильный.", combine, UiKit.label("Результат зависит от редкости вещей.", 12), "Объединить"))
	var note := UiKit.label("Кузнец ещё разжигает горн — улучшение и объединение появятся в следующих версиях.", 11, Color(1, 1, 1, 0.6))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(note)

func _card(title: String, text: String, row: Control, info: Label, btn: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.12), 10, 10))
	panel.custom_minimum_size = Vector2(340, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UiKit.label(title, 15, UiKit.CREAM))
	var t := UiKit.label(text, 12, Color(1, 1, 1, 0.8))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(320, 0)
	vb.add_child(t)
	if row is HBoxContainer:
		(row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	vb.add_child(info)
	var b := UiKit.button(btn, true)
	b.disabled = not ENABLED
	vb.add_child(b)
	# Замок поверх карточки
	var lock := ColorRect.new()
	lock.color = Color(0.04, 0.03, 0.02, 0.62)
	lock.mouse_filter = Control.MOUSE_FILTER_STOP
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.add_child(cc)
	var l := UiKit.label("🔒\nСкоро будет доступно", 15, UiKit.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(l)
	lock.visible = not ENABLED
	panel.add_child(lock)
	return panel

func open() -> void:
	for c in _weapon.get_children():
		c.queue_free()
	var id = Game.equip["weapon"]
	if id != null:
		var it := Items.get_item(id)
		var col: Color = Items.RARITY[it["rarity"]]["color"]
		_weapon.add_child(UiKit.slot(it["icon"], col, "", "", 48.0))
		_weapon.add_child(UiKit.label("→", 20))
		_weapon.add_child(UiKit.slot(it["icon"], col, "+1", "", 48.0))
		_upgrade_info.text = "%s: урон +%d → +%d" % [it["name"], it["dmg"], it["dmg"] + 3]
	else:
		_upgrade_info.text = "Надень оружие, чтобы улучшить его"
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

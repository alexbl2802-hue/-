## Системное окно CARDINAL: состояние системы (сложность, монстры, ошибки, кадры), журнал событий,
## множитель добычи Cardinal и проверка анимаций и скелетов (Cardinal 2.1).
extends Control

signal closed

var _status: Label
var _loot: Label
var _log: RichTextLabel
var _t := 0.0

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	vb.custom_minimum_size = Vector2(560, 0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	var title := UiKit.label("◈ CARDINAL SYSTEM", 18, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiKit.button("✕")
	x.pressed.connect(close)
	head.add_child(x)
	_status = UiKit.label("", 14)
	vb.add_child(_status)
	# Множитель добычи (добавочные предметы по таблицам Cardinal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	_loot = UiKit.label("", 14)
	_loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_loot)
	for d in [-0.1, 0.1]:
		var b := UiKit.button("Добыча −" if d < 0 else "Добыча +", false, 14)
		b.custom_minimum_size = Vector2(120, 40)
		b.pressed.connect(func():
			CardinalDirector.set_loot_mult(CardinalDirector.loot_mult() + d)
			_render())
		row.add_child(b)
	var chk := UiKit.button("Проверить анимации и скелеты", false, 14)
	chk.custom_minimum_size = Vector2(0, 40)
	chk.pressed.connect(func():
		var n: Node = get_parent()
		while n and not (n.get("hero") != null and n.get("enemies") != null):
			n = n.get_parent()
		if n:
			CardinalDirector.check_animations(n)
		_render())
	vb.add_child(chk)
	vb.add_child(UiKit.label("Журнал Cardinal", 13, Color(1, 1, 1, 0.7)))
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(540, 110)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 12)
	vb.add_child(_log)

func open() -> void:
	_render()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if _t > 0.5:
		_t = 0.0
		_render()

func _render() -> void:
	var c := Cardinal.active_counts()
	var core := CardinalDirector.core
	_status.text = "Сложность: %.2f  ·  урон монстров ×%.2f\nМонстров под надзором: %d  ·  боссов: %d\nОшибок исправлено: %d  ·  кадров в секунду: %d" % [
		Cardinal.difficulty, CardinalDirector.damage_mult(), c["mobs"], c["bosses"],
		core.error_count if core else 0, Engine.get_frames_per_second()]
	_loot.text = "Множитель добычи: ×%.1f" % CardinalDirector.loot_mult()
	var lines: Array = core.event_log if core else []
	var txt := "\n".join(lines.slice(maxi(0, lines.size() - 40))) if not lines.is_empty() else "Пока событий нет"
	if _log.text != txt:
		_log.text = txt

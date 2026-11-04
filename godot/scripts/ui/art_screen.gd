## Полноэкранная картинка (меню, загрузка) «с заполнением»: масштаб по большей стороне, лишнее
## обрезается поровну. map() переводит прямоугольник в пикселях картинки в координаты экрана —
## так настоящие кнопки и полоска ложатся точно на нарисованные.
class_name ArtScreen
extends RefCounted

const SIZE := Vector2(1280, 720)   # размер картинок меню и загрузки

static func background(parent: Control, path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

static func map(screen: Vector2, r: Rect2) -> Rect2:
	var k := maxf(screen.x / SIZE.x, screen.y / SIZE.y)
	var off := (screen - SIZE * k) / 2.0
	return Rect2(off + r.position * k, r.size * k)

static func place(c: Control, screen: Vector2, r: Rect2) -> void:
	var m := map(screen, r)
	c.position = m.position
	c.size = m.size

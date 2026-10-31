## Миникарта: рельеф, леса, город, входы в подземелья, костёр и стрелка героя.
extends Control

const RES := 180

var hero: Node3D
var world: Node3D
var enemies: Node
var dungeon: Node3D   # если герой в подземелье — рисуем его план
var _tex: ImageTexture

func setup(w: Node3D, h: Node3D) -> void:
	world = w
	hero = h
	_tex = ImageTexture.create_from_image(_make_image())

func _to_map(x: float, z: float) -> Vector2:
	return Vector2((x + WorldGen.HALF) / WorldGen.WORLD, (z + WorldGen.HALF) / WorldGen.WORLD) * size

func _make_image() -> Image:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	for y in RES:
		for x in RES:
			var wx := -WorldGen.HALF + (x + 0.5) / RES * WorldGen.WORLD
			var wz := -WorldGen.HALF + (y + 0.5) / RES * WorldGen.WORLD
			var h := WorldGen.ground_at(wx, wz)
			var c: Color
			if h < WorldGen.WATER:
				c = Color8(40, 100, 150)
			elif h < 1.4:
				c = Color8(200, 185, 130)
			elif h > 52.0:
				c = Color8(235, 240, 245)
			elif h > 28.0 or WorldGen.normal_y_at(wx, wz) < 0.78:
				var v := int(110 + h)
				c = Color8(v, v - 5, v - 12)
			else:
				c = Color8(int(70 + h * 2), int(125 + h), 55)
			img.set_pixel(x, y, c)
	var tree := Color(25 / 255.0, 60 / 255.0, 20 / 255.0)
	for key in ["pines", "oaks"]:
		for t in WorldGen.props[key]:
			var px := int((t[0] + WorldGen.HALF) / WorldGen.WORLD * RES)
			var py := int((t[1] + WorldGen.HALF) / WorldGen.WORLD * RES)
			if px >= 0 and py >= 0 and px < RES and py < RES:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(tree, 0.55))
	# Город: улицы, постройки, стена
	var m := func(v: float) -> int: return int((v + WorldGen.HALF) / WorldGen.WORLD * RES)
	var W := WorldGen.TOWN_WALL
	img.fill_rect(Rect2i(m.call(-3), m.call(-W), m.call(3) - m.call(-3) + 1, m.call(W) - m.call(-W)), Color("#c9b48a"))
	img.fill_rect(Rect2i(m.call(-W), m.call(-2.5), m.call(W) - m.call(-W), m.call(2.5) - m.call(-2.5) + 1), Color("#c9b48a"))
	for r in world.town_map:
		img.fill_rect(Rect2i(m.call(r["x0"]), m.call(r["z0"]), maxi(1, m.call(r["x1"]) - m.call(r["x0"])), maxi(1, m.call(r["z1"]) - m.call(r["z0"]))), r["c"])
	var wall := Color("#5a554c")
	var a: int = m.call(-W)
	var b: int = m.call(W)
	for i in range(a, b + 1):
		for p in [Vector2i(i, a), Vector2i(i, b), Vector2i(a, i), Vector2i(b, i)]:
			img.set_pixelv(p, wall)
	return img

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.07))
	if dungeon:
		_draw_dungeon()
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.86, 0.63, 0.4), false, 2.0)
		return
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.86, 0.63, 0.4), false, 2.0)
	if not world:
		return
	for e in world.entrances:
		var p := _to_map(e["x"], e["z"])
		draw_circle(p, 5.0, Color.BLACK)
		draw_circle(p, 4.0, Color("#e04a3a"))
	draw_circle(_to_map(world.campfire.position.x, world.campfire.position.z), 2.0, Color("#ffb040"))
	if enemies:
		for en in enemies.list:
			if not en.dead:
				draw_circle(_to_map(en.global_position.x, en.global_position.z), 1.6, Color("#ff7a3a"))
	if hero:
		var p := _to_map(hero.global_position.x, hero.global_position.z)
		var f: float = hero.facing
		# Стрелка: вперёд по направлению взгляда героя (north = −z вверх)
		var fwd := Vector2(sin(f), cos(f))
		var side := Vector2(fwd.y, -fwd.x)
		var pts := PackedVector2Array([p + fwd * 7, p - fwd * 5 + side * 5, p - fwd * 2, p - fwd * 5 - side * 5])
		draw_colored_polygon(pts, Color.WHITE)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.5)

## План подземелья: клетки, выход, сундук, монстры, герой
func _draw_dungeon() -> void:
	var d := dungeon
	var cs := floorf((size.x - 6.0) / maxf(d.cols, d.rows))
	var o := (size - Vector2(d.cols, d.rows) * cs) / 2.0
	for j in d.rows:
		for i in d.cols:
			draw_rect(Rect2(o + Vector2(i, j) * cs, Vector2(cs, cs)), Color("#1c1a20") if d.solid(i, j) else Color("#6e665c"))
	var to_map := func(p: Vector3) -> Vector2:
		return o + Vector2(p.x / DungeonDefs.CELL + d.cols / 2.0, p.z / DungeonDefs.CELL + d.rows / 2.0) * cs
	draw_circle(to_map.call(d.start_pos), 3.0, Color("#7fd8ff"))
	if not d.chest.get("opened", false):
		draw_circle(to_map.call(d.chest["pos"]), 3.0, Color("#ffd34d"))
	if enemies:
		for en in enemies.list:
			if not en.dead and en.in_dungeon and absf(en.global_position.y - d.Y) < 20.0:
				draw_circle(to_map.call(en.global_position), 1.8, Color("#ff7a3a"))
	if hero:
		_arrow(to_map.call(hero.global_position), hero.facing)

func _arrow(p: Vector2, f: float) -> void:
	var fwd := Vector2(sin(f), cos(f))
	var side := Vector2(fwd.y, -fwd.x)
	var pts := PackedVector2Array([p + fwd * 7, p - fwd * 5 + side * 5, p - fwd * 2, p - fwd * 5 - side * 5])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.5)

## Подземелья (этажи башни): карты клетками по CELL м. Сундук ставится на каждом этаже в случайное место.
## F объект темы в центре зала
## # стена · S вход/выход · C сундук · T факел · P колонна · K кристаллы на стене · B кости
## E монстр подземелья (в склепе — скелет, в пещере — паук) · O кобольд в броне с мечом
## level — уровень монстров: в подземельях они сильнее, чем на этажах башни того же этапа
class_name DungeonDefs
extends RefCounted

const CELL := 5.0      # клетка карты, м (было 4 — комнаты и проходы стали на четверть больше)
const WALL_H := 7.5    # высота стен и потолка, м (было 5)

## Отдельных подземелий (склепа, пещеры) больше нет — только этажи башни
const LIST := []

## Башня из этажей: на каждом этаже — комната босса за воротами (G). Ворота закрываются,
## пока герой внутри и страж жив. После победы открывается лестница наверх (U).
## G ворота · B место стража · U лестница на следующий этаж
const TOWER_Y := -900.0
const TOWER_STEP := 120.0
const TOWER_MAP_A := [
	"##########################",
	"#S....#.........#........#",
	"#.....#...E.....#....E...#",
	"#..T.......O.......T.....#",
	"#.....#.........#........#",
	"###.#####.#######.########",
	"#.......#.....#.......####",
	"#..E....#..E..#..O....####",
	"#......T#.....#T......####",
	"##.###########.###.#######",
	"#...O.....#......E..######",
	"#T........#.........######",
	"#..E......#.........G....#",
	"#.........#........T#..B.#",
	"#.........#.........#T..T#",
	"#..........O........#...U#",
	"##########################",
]
const TOWER_MAP_B := [
	"##########################",
	"#S...#......#............#",
	"#....#..E...#....E.......#",
	"#..T.#......#T...........#",
	"#.......O.........O......#",
	"######.######.#######.####",
	"#..........#.........#...#",
	"#...E.....T#....E...T#...#",
	"#..........#.........#...#",
	"####.######.####.#####.###",
	"#........O.......#.......#",
	"#T...E...........#...E...#",
	"#######G##########.......#",
	"#T........#......#..O....#",
	"#....B....#......#.......#",
	"#T......UT#......#......T#",
	"##########################",
]
## Этажи (по присланной картинке): тема — цвет стен, пола, тумана, света и факелов, монстры,
## уровень, мини-босс (на 10-м — финальный босс). boss_loot — чья добыча и материал у босса
## (материалы этажей прежние — рецепты ковки не меняются). crystals — светящиеся кристаллы на стенах,
## feature — что стоит в центре большого зала. Карта каждого этажа строится генератором (gen_map).
const TOWER := [
	{"name": "Каменный аванпост", "sub": "Руины, стражи, каменные големы", "wall": 0x8a8478, "floor": 0x6a655c, "fog": 0x0e0c0a, "light": 0xffa84a, "torch": 0xff8a30,
		"monster": "skeleton", "monster2": "stone_golem", "level": 2, "boss": "golem_warden", "feature": "fire"},
	{"name": "Подземные пещеры", "sub": "Пещеры, руда, кристаллы, насекомые", "wall": 0x5a6070, "floor": 0x3e4250, "fog": 0x060a14, "light": 0x6ab8ff, "torch": 0x6ab8ff,
		"monster": "spider", "monster2": "venom_spider", "level": 4, "boss": "crystal_spider", "crystals": true, "feature": "crystal"},
	{"name": "Заражённые катакомбы", "sub": "Токсины, мутанты, нежить", "wall": 0x4a5a3a, "floor": 0x343e2a, "fog": 0x0a1406, "light": 0x7aff4a, "torch": 0x7aff4a,
		"monster": "skeleton", "monster2": "venom_spider", "level": 6, "boss": "toxic_mutant", "feature": "crystal"},
	{"name": "Ледяные глубины", "sub": "Лёд, снег, ледяные монстры", "wall": 0xc8e0f0, "floor": 0x8ab0d0, "fog": 0x0a1220, "light": 0x9ad0ff, "torch": 0x9ad0ff,
		"monster": "storm_wolf", "monster2": "skeleton", "level": 8, "boss": "ice_beast", "crystals": true, "feature": "crystal"},
	{"name": "Огненные недра", "sub": "Лава, пламя, огненные существа", "wall": 0x5a2a20, "floor": 0x3a1a14, "fog": 0x1a0604, "light": 0xff6a20, "torch": 0xff5a10,
		"monster": "kobold", "monster2": "wolf", "level": 10, "boss": "fire_demon", "feature": "fire"},
	{"name": "Забытый лес", "sub": "Древний лес, духи, растения", "wall": 0x4a6a3a, "floor": 0x3a4a2a, "fog": 0x081008, "light": 0x6ad0c0, "torch": 0x6ad0a0,
		"monster": "thorn_beast", "monster2": "rabbit", "level": 12, "boss": "forest_keeper", "feature": "crystal"},
	{"name": "Храм стихий", "sub": "Стихии, элементали, испытания", "wall": 0x8a8070, "floor": 0x5a5448, "fog": 0x0c0a08, "light": 0xffd080, "torch": 0xffb050,
		"monster": "stone_golem", "monster2": "storm_wolf", "level": 14, "boss": "elemental_guard", "crystals": true, "feature": "crystal"},
	{"name": "Теневой лабиринт", "sub": "Иллюзии, тени, ловушки", "wall": 0x3a2a5a, "floor": 0x221a36, "fog": 0x06020c, "light": 0xa060ff, "torch": 0xa060ff,
		"monster": "wolf", "monster2": "skeleton", "level": 16, "boss": "shadow_wraith", "crystals": true, "feature": "crystal"},
	{"name": "Некрополь", "sub": "Нежить, проклятия, души", "wall": 0x3a4a48, "floor": 0x243230, "fog": 0x020806, "light": 0x40e0c0, "torch": 0x40e0b0,
		"monster": "skeleton", "monster2": "spider", "level": 18, "boss": "necromancer", "feature": "crystal"},
	{"name": "Обитель босса", "sub": "Финальный этаж: главный босс", "wall": 0x5a2420, "floor": 0x3a1612, "fog": 0x140404, "light": 0xff5030, "torch": 0xff4020,
		"monster": "kobold", "monster2": "stone_golem", "level": 20, "boss": "tower_lord", "feature": "fire", "final": true},
]

## Карта этажа: широкий этаж из комнат в три ряда, соединённых проходами; слева — вход (S),
## посередине — большой зал с колоннами и объектом темы (F), справа — комната мини-босса за
## воротами (G) с боссом (B) и телепортом наверх (U). Своя раскладка у каждого этажа (seed).
const SLOT_W := 8
const SLOT_H := 6
const SLOTS := 4          # колонок комнат до комнаты босса

static func gen_map(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = 9100 + seed * 31
	var cols := (SLOTS + 1) * SLOT_W + 2
	var rows := 3 * SLOT_H + 1
	var g := []
	for j in rows:
		var row := []
		row.resize(cols)
		row.fill("#")
		g.append(row)
	var carve := func(x: int, y: int, c := ".") -> void:
		if x > 0 and y > 0 and x < cols - 1 and y < rows - 1 and g[y][x] in ["#", "."]:
			g[y][x] = c
	var rooms := {}
	for cx in SLOTS:
		for ry in 3:
			if ry != 1 and cx > 0 and r.randf() < 0.25:
				continue   # не в каждом углу комната — у этажей разный рисунок
			var hub := cx == 2 and ry == 1
			var w: int = SLOT_W - 1 if hub else r.randi_range(4, SLOT_W - 2)
			var h: int = SLOT_H - 1 if hub else r.randi_range(3, SLOT_H - 2)
			var x: int = cx * SLOT_W + 1 + r.randi_range(0, SLOT_W - 1 - w)
			var y: int = ry * SLOT_H + 1 + r.randi_range(0, SLOT_H - 1 - h)
			rooms[Vector2i(cx, ry)] = Rect2i(x, y, w, h)
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					carve.call(xx, yy)
	# Комната босса — справа во всю середину
	var bw := SLOT_W - 2
	var bh := SLOT_H + 3
	var bx := SLOTS * SLOT_W + 2
	var by := SLOT_H - 1
	var boss := Rect2i(bx, by, bw, bh)
	for yy in range(by, by + bh):
		for xx in range(bx, bx + bw):
			carve.call(xx, yy)
	var center := func(rc: Rect2i) -> Vector2i: return rc.position + rc.size / 2
	var corridor := func(a: Vector2i, b: Vector2i, wide: bool) -> void:
		var x := a.x
		var y := a.y
		while x != b.x:
			carve.call(x, y)
			if wide:
				carve.call(x, y + 1)
			x += signi(b.x - x)
		while y != b.y:
			carve.call(x, y)
			if wide:
				carve.call(x + 1, y)
			y += signi(b.y - y)
		carve.call(x, y)
	# Главный путь посередине: вход → комнаты → зал → комнаты
	for cx in range(1, SLOTS):
		corridor.call(center.call(rooms[Vector2i(cx - 1, 1)]), center.call(rooms[Vector2i(cx, 1)]), true)
	# Верхние и нижние комнаты — к средней своей колонки; иногда ещё и к соседней
	for cx in SLOTS:
		for ry in [0, 2]:
			var k := Vector2i(cx, ry)
			if not rooms.has(k):
				continue
			corridor.call(center.call(rooms[k]), center.call(rooms[Vector2i(cx, 1)]), false)
			var nb := Vector2i(cx + 1, ry)
			if rooms.has(nb) and r.randf() < 0.5:
				corridor.call(center.call(rooms[k]), center.call(rooms[nb]), false)
	# Проход к комнате босса — узкий, ворота в проёме стены
	var last: Vector2i = center.call(rooms[Vector2i(SLOTS - 1, 1)])
	var door := Vector2i(bx - 1, by + bh / 2)
	corridor.call(last, Vector2i(door.x - 1, door.y), false)
	g[door.y][door.x] = "G"
	# Вход, зал, босс, телепорт
	var st: Rect2i = rooms[Vector2i(0, 1)]
	g[st.position.y + st.size.y / 2][st.position.x + 1] = "S"
	var hub: Rect2i = rooms[Vector2i(2, 1)]
	var hc: Vector2i = center.call(hub)
	g[hc.y][hc.x] = "F"
	for d in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(2, 1)]:
		var pp: Vector2i = hc + d
		if g[pp.y][pp.x] == ".":
			g[pp.y][pp.x] = "P"
	g[by + bh / 2][bx + bw / 2] = "B"
	g[by + bh / 2][bx + bw - 1] = "U"
	for pp in [Vector2i(bx + 1, by + 1), Vector2i(bx + bw - 2, by + 1), Vector2i(bx + 1, by + bh - 2), Vector2i(bx + bw - 2, by + bh - 2)]:
		g[pp.y][pp.x] = "P"
	for pp in [Vector2i(bx, by + 2), Vector2i(bx, by + bh - 3), Vector2i(bx + bw - 1, by + 2), Vector2i(bx + bw - 1, by + bh - 3)]:
		g[pp.y][pp.x] = "T"
	# Монстры, факелы и кристаллы в комнатах (кроме входа)
	var n := 0
	for k in rooms:
		var rc: Rect2i = rooms[k]
		var spots := []
		for yy in range(rc.position.y, rc.end.y):
			for xx in range(rc.position.x, rc.end.x):
				if g[yy][xx] == ".":
					spots.append(Vector2i(xx, yy))
		if spots.is_empty():
			continue
		var walls := spots.filter(func(p): return g[p.y - 1][p.x] == "#" or g[p.y + 1][p.x] == "#" or g[p.y][p.x - 1] == "#" or g[p.y][p.x + 1] == "#")
		for t in 2:
			if not walls.is_empty():
				var p: Vector2i = walls.pop_at(r.randi() % walls.size())
				g[p.y][p.x] = "T"
		if r.randf() < 0.6 and not walls.is_empty():
			var p: Vector2i = walls.pop_at(r.randi() % walls.size())
			g[p.y][p.x] = "K"
		if k == Vector2i(0, 1):
			continue
		var marks := 1 + (1 if rc.size.x * rc.size.y > 16 else 0) + (1 if k == Vector2i(2, 1) else 0)
		for m in marks:
			var free := spots.filter(func(p): return g[p.y][p.x] == ".")
			if free.is_empty():
				break
			var p: Vector2i = free[r.randi() % free.size()]
			g[p.y][p.x] = "E" if n % 3 != 2 else "O"
			n += 1
	var out := []
	for row in g:
		out.append("".join(row))
	return out

## Все подземелья — этажи башни (номер этажа — "floor", с 1)
static func all() -> Array:
	var out: Array = LIST.duplicate()
	for k in TOWER.size():
		var t: Dictionary = TOWER[k].duplicate()
		t["map"] = gen_map(k + 1)
		t["style"] = "tower"
		t["floor"] = k + 1
		t["y"] = TOWER_Y - TOWER_STEP * k
		t["name"] = "Этаж %d · %s" % [k + 1, t["name"]]
		out.append(t)
	return out

## Номер подземелья для этажа башни (с 1)
static func floor_index(f: int) -> int:
	return LIST.size() + f - 1

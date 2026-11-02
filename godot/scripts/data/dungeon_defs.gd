## Подземелья: карты клетками по 4 м.
## # стена · S вход/выход · C сундук · T факел · P колонна · K кристаллы на стене · B кости
## E монстр подземелья (в склепе — скелет, в пещере — паук) · O кобольд в броне с мечом
## level — уровень монстров: в подземельях они сильнее, чем на этажах башни того же этапа
class_name DungeonDefs
extends RefCounted

const CELL := 4.0
const WALL_H := 5.0

const LIST := [
	{
		"name": "Древний склеп", "sub": "Холодный камень и забытые кости", "style": "crypt", "y": -300.0,
		"monster": "skeleton", "boss": "skeleton_king", "level": 6, "chest_loot": ["sword_steel", "amulet_life"],
		"map": [
			"#####################",
			"#S..#.......#.......#",
			"#...#..T....#.E.B...#",
			"#.......P.P.....P...#",
			"#.T.#...E...#.......#",
			"##.####.#####.#######",
			"#......T.#.....E...##",
			"#.######.#.#######..#",
			"#.#....#...#.....#.T#",
			"#.#.BE.###.#O.C.O#..#",
			"#.#....T...#.....#..#",
			"#.###.######P...P#.E#",
			"#.....T.....O.......#",
			"#####################",
		],
	},
	{
		"name": "Пещера кристаллов", "sub": "Глубоко под горами что-то мерцает", "style": "cave", "y": -600.0,
		"monster": "spider", "boss": "spider_queen", "level": 12, "chest_loot": ["sword_crystal", "armor_plate"],
		"map": [
			"########################",
			"####S..######......#####",
			"###.....####..K..E..####",
			"##...T...##....##....###",
			"##......#..E..####...###",
			"###..K.......#####..K..#",
			"####....###...###...E..#",
			"#####..#####.........###",
			"####...######..T..#..###",
			"###.E.K####..O..###..###",
			"##....#####..C...##.T###",
			"##..T..###K..O..######.#",
			"###......#.....#########",
			"########################",
		],
	},
]

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
## Этажи: тема (цвет стен и пола), монстры, уровень монстров, страж этажа
const TOWER := [
	{"name": "Лесной этаж", "sub": "Корни прорастают сквозь камень", "wall": 0x6a8a4a, "floor": 0x5a6a4a, "fog": 0x0c140a, "light": 0x8ac070,
		"monster": "goblin", "monster2": "wolf", "level": 2, "boss": "alpha_wolf", "map": "A", "mirror": false},
	{"name": "Сумрачная чаща", "sub": "Здесь даже днём темно", "wall": 0x3e4a36, "floor": 0x34402e, "fog": 0x05080a, "light": 0x6a8a9a,
		"monster": "rabbit", "monster2": "goblin", "level": 4, "boss": "goblin_chief", "map": "B", "mirror": false},
	{"name": "Песчаный этаж", "sub": "Горячий песок скрипит под ногами", "wall": 0xd8c08a, "floor": 0xc8a870, "fog": 0x1a1408, "light": 0xffc880,
		"monster": "spider", "monster2": "kobold", "level": 6, "boss": "sand_scorpion", "map": "A", "mirror": true},
	{"name": "Ледяной этаж", "sub": "Дыхание замерзает в воздухе", "wall": 0xc8e0f0, "floor": 0x9ab8d0, "fog": 0x0a1220, "light": 0x9ad0ff,
		"monster": "skeleton", "monster2": "wolf", "level": 8, "boss": "frost_king", "map": "B", "mirror": true},
	{"name": "Крепость", "sub": "Здесь правит полководец", "wall": 0x8a7a6a, "floor": 0x6a5a5a, "fog": 0x100808, "light": 0xff9a60,
		"monster": "kobold", "monster2": "skeleton", "level": 10, "boss": "kobold_warlord", "map": "A", "mirror": false},
	{"name": "Топь", "sub": "Под ногами хлюпает, в воздухе туман", "wall": 0x4a5a3a, "floor": 0x3a4a30, "fog": 0x0a1008, "light": 0x9ac070,
		"monster": "spider", "monster2": "rabbit", "level": 12, "boss": "swamp_mother", "map": "B", "mirror": false},
	{"name": "Огненные залы", "sub": "Камень раскалён, воздух дрожит", "wall": 0x8a3a2a, "floor": 0x5a2a20, "fog": 0x1a0604, "light": 0xff7040,
		"monster": "kobold", "monster2": "wolf", "level": 14, "boss": "lava_lord", "map": "A", "mirror": true},
	{"name": "Кристальные своды", "sub": "Стены звенят от каждого шага", "wall": 0x7a6aa8, "floor": 0x4a4070, "fog": 0x0a0818, "light": 0xb090ff,
		"monster": "skeleton", "monster2": "spider", "level": 16, "boss": "crystal_guard", "map": "B", "mirror": true},
	{"name": "Теневой этаж", "sub": "Свет факелов едва пробивает тьму", "wall": 0x3a3a48, "floor": 0x24242e, "fog": 0x020204, "light": 0x7080b0,
		"monster": "wolf", "monster2": "kobold", "level": 18, "boss": "shadow_wolf", "map": "A", "mirror": false},
	{"name": "Небесный чертог", "sub": "Вершина башни. За воротами — лестница в новый мир", "wall": 0xd8c890, "floor": 0xa89860, "fog": 0x101008, "light": 0xffe8a0,
		"monster": "skeleton", "monster2": "kobold", "level": 20, "boss": "sky_king", "map": "B", "mirror": false},
]

## Все подземелья: два обычных и этажи башни (номер этажа — "floor", с 1)
static func all() -> Array:
	var out: Array = LIST.duplicate()
	for k in TOWER.size():
		var t: Dictionary = TOWER[k].duplicate()
		var m: Array = TOWER_MAP_A if t["map"] == "A" else TOWER_MAP_B
		if t["mirror"]:
			var mm := []
			for row in m:
				mm.append((row as String).reverse())
			m = mm
		t["map"] = m
		t["style"] = "tower"
		t["floor"] = k + 1
		t["y"] = TOWER_Y - TOWER_STEP * k
		t["name"] = "Этаж %d · %s" % [k + 1, t["name"]]
		out.append(t)
	return out

## Номер подземелья для этажа башни (с 1)
static func floor_index(f: int) -> int:
	return LIST.size() + f - 1

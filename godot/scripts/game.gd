## Состояние героя и прогресс: уровень, опыт, золото, вещи, снаряжение, навыки.
## Подключён как автозагрузка Game — доступен из любого скрипта.
extends Node

signal changed          # что-то в прогрессе изменилось (для интерфейса)
signal leveled_up(level: int)
signal message(text: String, color: Color, pos: Vector3)  # всплывающая надпись над точкой

const SAVE_PATH := "user://save.json"
## Опыт за монстра: случайно в пределах [от, до]
const ENEMY_XP := {"goblin": [27, 30], "rabbit": [37, 40], "skeleton": [30, 30], "spider": [28, 28], "kobold": [48, 52], "wolf": [68, 74], "skeleton_king": [260, 290], "spider_queen": [240, 270],
	"alpha_wolf": [180, 200], "goblin_chief": [190, 210], "sand_scorpion": [200, 220], "frost_king": [210, 230], "kobold_warlord": [230, 250],
	"swamp_mother": [250, 270], "lava_lord": [270, 290], "crystal_guard": [290, 310], "shadow_wolf": [310, 330], "sky_king": [350, 380],
	"stone_golem": [90, 100], "storm_wolf": [70, 80], "venom_spider": [60, 70], "thorn_beast": [85, 95]}

static func enemy_xp(kind: String) -> int:
	var r: Array = ENEMY_XP.get(kind, [10, 10])
	return randi_range(r[0], r[1])

var player_name := ""
var has_save := false   # игру уже начинали (есть сохранение) — в меню «Продолжить»
var chests: Array = []  # номера подземелий, где сундук уже открыт
var bosses: Array = []  # номера подземелий, где босс побеждён
## Сколько этажей башни открыто: первый — сразу, каждый побеждённый страж открывает следующий
func tower_unlocked() -> int:
	var n := 1
	while n < DungeonDefs.TOWER.size() and bosses.has(DungeonDefs.floor_index(n)):
		n += 1
	return n
var stats := {"str": 0, "agi": 0, "vit": 0}   # очки характеристик: Сила, Ловкость, Выносливость
var time_of_day := 0.33 # время суток: 0 — полночь, 0,25 — рассвет, 0,5 — полдень, 0,75 — закат
var is_night := false
var level := 1
var xp := 0
var gold := 0
var kills := 0
var inv: Array = []     # [{id, n, r, u}] — см. Items.make
var speed_bonus := 0.0   # от сапог: доля к скорости бега
var crit_bonus := 0.0    # от колец: доля к шансу крита
var equip := {"weapon": null, "armor": null, "helm": null, "amulet": null, "boots": null, "ring": null, "cloak": null, "shield": null}   # слот → {id, n, r, u} или null
var skills := {}        # id → ранг

# Боевые характеристики (пересчитываются из уровня, снаряжения и навыков)
var max_hp := 100.0
var hp := 100.0
var dmg := 22
var armor := 0

func _ready() -> void:
	has_save = load_game()
	if not has_save:
		new_game()
	refresh()
	hp = max_hp

## Начать с нуля: ржавый меч и пара зелий
func new_game() -> void:
	level = 1
	xp = 0
	gold = 0
	kills = 0
	inv = [Items.make("potion", 2)]
	equip = {"weapon": Items.make("sword_rusty"), "armor": null, "helm": null, "amulet": null, "boots": null, "ring": null, "cloak": null, "shield": null}
	skills = {}
	chests = []
	bosses = []
	stats = {"str": 0, "agi": 0, "vit": 0}
	time_of_day = 0.33
	refresh()
	hp = max_hp

## «Новая игра» из меню: стереть сохранение
func wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	has_save = false
	new_game()

# ---------- Снаряжение
func equip_from(i: int) -> void:
	var st: Dictionary = inv[i]
	var slot: String = Items.get_item(st["id"])["kind"]
	var prev = equip[slot]
	equip[slot] = st
	inv.remove_at(i)
	if prev != null:
		inv.insert(i, prev)
	refresh()
	save_game()

func unequip(slot: String) -> bool:
	if equip[slot] == null or inv.size() >= Items.INV_SIZE:
		return false
	inv.append(equip[slot])
	equip[slot] = null
	refresh()
	save_game()
	return true

func drop_item(i: int) -> void:
	inv.remove_at(i)
	save_game()
	changed.emit()

func count_of(id: String) -> int:
	var n := 0
	for st in inv:
		if st["id"] == id:
			n += st["n"]
	return n

func _take(id: String, n: int) -> void:
	for i in range(inv.size() - 1, -1, -1):
		if n <= 0:
			return
		if inv[i]["id"] == id:
			var k: int = mini(n, inv[i]["n"])
			inv[i]["n"] -= k
			n -= k
			if inv[i]["n"] <= 0:
				inv.remove_at(i)

# ---------- Кузница: улучшение оружия и соединение вещей
## Улучшить надетое оружие на +1 за золото
func upgrade_weapon() -> bool:
	var w = equip["weapon"]
	if w == null or w["u"] >= Items.MAX_UPGRADE:
		return false
	var cost := Items.upgrade_cost(w["u"])
	if gold < cost:
		return false
	gold -= cost
	w["u"] += 1
	refresh()
	save_game()
	return true

## Группы одинаковых вещей (один вид и один ранг), включая надетую: [{id, r, count}]
func combine_groups() -> Array:
	var groups := {}
	var all := inv.duplicate()
	for slot in Items.SLOTS:
		if equip[slot] != null:
			all.append(equip[slot])
	for st in all:
		if not Items.SLOTS.has(Items.get_item(st["id"])["kind"]):
			continue
		var key := "%s|%d" % [st["id"], st["r"]]
		if not groups.has(key):
			groups[key] = {"id": st["id"], "r": st["r"], "count": 0}
		groups[key]["count"] += 1
	var out := groups.values()
	out.sort_custom(func(a, b): return a["count"] > b["count"] if a["count"] != b["count"] else a["r"] > b["r"])
	return out

func can_combine(id: String, r: int) -> String:
	if r >= Items.MAX_RANK:
		return "Высший ранг"
	var have := 0
	for g in combine_groups():
		if g["id"] == id and g["r"] == r:
			have = g["count"]
	if have < Items.COMBINE_COUNT:
		return "Нужно %d шт." % Items.COMBINE_COUNT
	var cost := Items.combine_cost(r)
	if count_of("shard") < cost[0]:
		return "Мало осколков"
	if gold < cost[1]:
		return "Мало золота"
	return ""

## Соединить 3 одинаковые вещи одного ранга в одну вещь следующего ранга.
## Надетая вещь тоже идёт в дело — результат тогда сразу надевается. Улучшение берётся лучшее.
func combine(id: String, r: int) -> Dictionary:
	if can_combine(id, r) != "":
		return {}
	var cost := Items.combine_cost(r)
	_take("shard", cost[0])
	gold -= cost[1]
	var slot: String = Items.get_item(id)["kind"]
	var left := Items.COMBINE_COUNT
	var best_u := 0
	var was_equipped := false
	if equip[slot] != null and equip[slot]["id"] == id and equip[slot]["r"] == r:
		best_u = equip[slot]["u"]
		equip[slot] = null
		was_equipped = true
		left -= 1
	for i in range(inv.size() - 1, -1, -1):
		if left == 0:
			break
		if inv[i]["id"] == id and inv[i]["r"] == r:
			best_u = maxi(best_u, inv[i]["u"])
			inv.remove_at(i)
			left -= 1
	var res := {"id": id, "n": 1, "r": r + 1, "u": best_u}
	if was_equipped:
		equip[slot] = res
	else:
		inv.append(res)
	refresh()
	save_game()
	return res

static func xp_next(lvl: int) -> int:
	return 30 + lvl * 30

func rank(id: String) -> int:
	return int(skills.get(id, 0))

func points_free() -> int:
	var spent := 0
	for s in SkillDefs.LIST:
		spent += rank(s["id"])
	# Эволюция в Скользящий шаг даёт его 1-й уровень бесплатно, дальше — по очку за уровень
	spent += maxi(0, rank("dash_slide") - 1)
	return level - 1 - spent   # очко навыка — за каждое повышение уровня

func refresh() -> void:
	var hp_b := 0
	var dmg_b := 0
	var arm := 0
	var spd_b := 0
	var crit_b := 0
	for slot in Items.SLOTS:
		var e = equip[slot]
		if e == null:
			continue
		hp_b += Items.stat(e, "hp")
		dmg_b += Items.stat(e, "dmg")
		arm += Items.stat(e, "armor")
		spd_b += Items.stat(e, "speed")
		crit_b += Items.stat(e, "crit")
	max_hp = 100.0 + (level - 1) * 15 + hp_b + rank("vitality") * 20 + stats["vit"] * STAT_VIT
	dmg = 18 + (level - 1) * 4 + dmg_b + rank("strength") * 5 + stats["str"] * STAT_STR
	armor = arm
	speed_bonus = spd_b / 100.0
	crit_bonus = crit_b / 100.0
	hp = minf(hp, max_hp)
	changed.emit()

# ---------- Ковка уникального оружия у кузнеца
func can_forge(rec: Dictionary) -> String:
	if count_of(rec["mat"]) < 1:
		return "Нужен материал"
	if count_of("shard") < rec["shards"]:
		return "Мало осколков"
	if gold < rec["gold"]:
		return "Мало золота"
	if inv.size() >= Items.INV_SIZE:
		return "Нет места"
	return ""

func forge(rec: Dictionary) -> bool:
	if can_forge(rec) != "":
		return false
	_take(rec["mat"], 1)
	_take("shard", rec["shards"])
	gold -= rec["gold"]
	inv.append(Items.make(rec["id"]))
	save_game()
	changed.emit()
	return true

# ---------- Прочность оружия: каждый удар по врагу — минус единица
func wear_weapon() -> void:
	var w = equip["weapon"]
	if w == null or not w.has("d") or w["d"] <= 0:
		return
	w["d"] -= 1
	var mx := Items.max_dur(w)
	if w["d"] == 0:
		refresh()
		message.emit("Оружие сломано! Почини у кузнеца", Color("#ff6a5a"), Vector3.ZERO)
	elif w["d"] == int(mx * 0.2):
		message.emit("Оружие изнашивается", Color("#ffc060"), Vector3.ZERO)

func repair_weapon() -> bool:
	var w = equip["weapon"]
	if w == null or not w.has("d") or w["d"] >= Items.max_dur(w):
		return false
	var cost := Items.repair_cost(w)
	if gold < cost:
		return false
	gold -= cost
	w["d"] = Items.max_dur(w)
	refresh()
	save_game()
	return true

# ---------- Очки характеристик: 2 за каждое повышение уровня
const STAT_PER_LEVEL := 2
const STAT_STR := 3        # урона за очко Силы
const STAT_VIT := 12       # здоровья за очко Выносливости
const STAT_AGI_SPEED := 0.02   # скорость удара за очко Ловкости
const STAT_AGI_CRIT := 0.01    # шанс крита за очко Ловкости

func stat_points_free() -> int:
	return (level - 1) * STAT_PER_LEVEL - stats["str"] - stats["agi"] - stats["vit"]

func add_stat(k: String) -> bool:
	if stat_points_free() <= 0 or not stats.has(k):
		return false
	var before := max_hp
	stats[k] += 1
	refresh()
	if k == "vit":
		hp += max_hp - before
	save_game()
	return true

func reset_stats() -> void:
	stats = {"str": 0, "agi": 0, "vit": 0}
	refresh()
	save_game()

## Щит усиливает блок (доля урона, которую он снимает сверх обычного блока)
func block_bonus() -> float:
	var sh = equip.get("shield")
	return Items.stat(sh, "block") / 100.0 if sh != null else 0.0

## Урон по герою с учётом брони
func reduce_damage(raw: int) -> int:
	return maxi(1, roundi(raw * 100.0 / (100.0 + armor * 4)))

func give_xp(n: int, pos: Vector3) -> void:
	xp += n
	message.emit("+%d опыта" % n, Color("#8fe0ff"), pos)
	while xp >= xp_next(level):
		xp -= xp_next(level)
		level += 1
		refresh()
		hp = max_hp
		leveled_up.emit(level)
	save_game()
	changed.emit()

func add_item(id: String, n := 1, r := -1) -> bool:
	if id == "gold":
		gold += n
		return true
	if Items.STACKS.has(Items.get_item(id)["kind"]):
		for st in inv:
			if st["id"] == id:
				st["n"] += n
				return true
	if inv.size() >= Items.INV_SIZE:
		return false
	inv.append(Items.make(id, n, r))
	return true

## Лавка алхимика: купить зелье за золото
func buy_potion() -> bool:
	if gold < Items.POTION_PRICE or not add_item("potion", 1):
		return false
	gold -= Items.POTION_PRICE
	save_game()
	changed.emit()
	return true

## Сварить зелье у алхимика из эссенций монстров
func brew_potion() -> bool:
	if count_of("essence") < Items.BREW_ESSENCE or gold < Items.BREW_GOLD:
		return false
	if not add_item("potion", 1):
		return false
	take_item("essence", Items.BREW_ESSENCE)
	gold -= Items.BREW_GOLD
	save_game()
	changed.emit()
	return true

## Забрать из инвентаря n штук складываемой вещи
func take_item(id: String, n: int) -> void:
	for i in range(inv.size() - 1, -1, -1):
		if inv[i]["id"] == id and n > 0:
			var k := mini(n, int(inv[i]["n"]))
			inv[i]["n"] -= k
			n -= k
			if inv[i]["n"] <= 0:
				inv.remove_at(i)

func potions() -> int:
	for st in inv:
		if st["id"] == "potion":
			return st["n"]
	return 0

func use_potion() -> float:
	if hp >= max_hp:
		return 0.0
	for i in inv.size():
		if inv[i]["id"] == "potion":
			var heal := minf(float(Items.ALL["potion"]["heal"]), max_hp - hp)
			hp += heal
			inv[i]["n"] -= 1
			if inv[i]["n"] <= 0:
				inv.remove_at(i)
			save_game()
			changed.emit()
			return heal
	return 0.0

func learn(id: String) -> bool:
	# После эволюции очки идут в Скользящий шаг
	if id == "dash" and SkillDefs.dash_form(skills) != "dash":
		if SkillDefs.dash_form(skills) != "slide" or points_free() <= 0 or rank("dash_slide") >= SkillDefs.SLIDE_MAX:
			return false
		skills["dash_slide"] = rank("dash_slide") + 1
		save_game()
		return true
	var s := SkillDefs.find(id)
	if s.is_empty() or points_free() <= 0 or level < s["lvl"] or rank(id) >= s["max"]:
		return false
	var before := max_hp
	skills[id] = rank(id) + 1
	refresh()
	if id == "vitality":
		hp += max_hp - before
	save_game()
	return true

## Эволюция навыка: Рывок (10 ур.) → Скользящий шаг, затем прорыв Скользящий шаг (5 ур.) → Мерцание
func can_evolve(id: String) -> bool:
	if id != "dash":
		return false
	match SkillDefs.dash_form(skills):
		"dash": return rank("dash") >= SkillDefs.find("dash")["max"]
		"slide": return rank("dash_slide") >= SkillDefs.SLIDE_MAX
	return false

func evolve(id: String) -> bool:
	if not can_evolve(id):
		return false
	if SkillDefs.dash_form(skills) == "dash":
		skills["dash_slide"] = 1
	else:
		skills["dash_blink"] = 1
	save_game()
	return true

func reset_skills() -> void:
	skills = {}
	refresh()
	save_game()

# ---------- Сохранение
func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"v": 2, "name": player_name, "chests": chests, "bosses": bosses, "stats": stats, "time": time_of_day, "level": level, "xp": xp, "gold": gold, "kills": kills, "inv": inv, "equip": equip, "skills": skills}))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	player_name = str(d.get("name", ""))
	chests = []
	for c in d.get("chests", []):
		chests.append(int(c))
	time_of_day = clampf(float(d.get("time", 0.33)), 0.0, 1.0)
	var st0: Dictionary = d.get("stats", {})
	stats = {"str": int(st0.get("str", 0)), "agi": int(st0.get("agi", 0)), "vit": int(st0.get("vit", 0))}
	bosses = []
	for c in d.get("bosses", []):
		bosses.append(int(c))
	# Старые сохранения: номера 0 и 1 были у склепа и пещеры, этажи башни шли с 2
	if int(d.get("v", 1)) < 2:
		bosses = bosses.filter(func(i): return i >= 2).map(func(i): return i - 2)
		chests = []
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	gold = int(d.get("gold", 0))
	kills = int(d.get("kills", 0))
	inv = []
	for st in d.get("inv", []):
		var it := Items.normalize(st)
		if not it.is_empty():
			inv.append(it)
	for slot in Items.SLOTS:
		var e := Items.normalize(d.get("equip", {}).get(slot))
		equip[slot] = null if e.is_empty() else e
	skills = {}
	for s in SkillDefs.LIST:
		var r := int(d.get("skills", {}).get(s["id"], 0))
		if r > 0:
			skills[s["id"]] = mini(r, s["max"])
	# Эволюция рывка
	var sl := int(d.get("skills", {}).get("dash_slide", 0))
	if sl > 0 and rank("dash") >= SkillDefs.find("dash")["max"]:
		skills["dash_slide"] = mini(sl, SkillDefs.SLIDE_MAX)
		if int(d.get("skills", {}).get("dash_blink", 0)) > 0 and skills["dash_slide"] >= SkillDefs.SLIDE_MAX:
			skills["dash_blink"] = 1
	return true

## Состояние героя и прогресс: уровень, опыт, золото, вещи, снаряжение, навыки.
## Подключён как автозагрузка Game — доступен из любого скрипта.
extends Node

signal changed          # что-то в прогрессе изменилось (для интерфейса)
signal leveled_up(level: int)
signal message(text: String, color: Color, pos: Vector3)  # всплывающая надпись над точкой

const SAVE_PATH := "user://save.json"
const ENEMY_XP := {"slime": 12, "goblin": 20, "skeleton": 30, "spider": 28}

var level := 1
var xp := 0
var gold := 0
var kills := 0
var inv: Array = []     # [{id, n}]
var equip := {"weapon": null, "armor": null, "helm": null, "amulet": null}
var skills := {}        # id → ранг

# Боевые характеристики (пересчитываются из уровня, снаряжения и навыков)
var max_hp := 100.0
var hp := 100.0
var dmg := 22
var armor := 0

func _ready() -> void:
	if not load_game():
		new_game()
	refresh()
	hp = max_hp

## Начать с нуля: ржавый меч и пара зелий
func new_game() -> void:
	level = 1
	xp = 0
	gold = 0
	kills = 0
	inv = [{"id": "potion", "n": 2}]
	equip = {"weapon": "sword_rusty", "armor": null, "helm": null, "amulet": null}
	skills = {}
	refresh()
	hp = max_hp

static func xp_next(lvl: int) -> int:
	return 30 + lvl * 30

func rank(id: String) -> int:
	return int(skills.get(id, 0))

func points_free() -> int:
	var spent := 0
	for s in SkillDefs.LIST:
		spent += rank(s["id"])
	return mini(level, SkillDefs.MAX_SKILL_LEVEL) - 1 - spent

func refresh() -> void:
	var hp_b := 0
	var dmg_b := 0
	var arm := 0
	for slot in Items.SLOTS:
		var id = equip[slot]
		if id == null:
			continue
		var it := Items.get_item(id)
		hp_b += int(it.get("hp", 0))
		dmg_b += int(it.get("dmg", 0))
		arm += int(it.get("armor", 0))
	max_hp = 100.0 + (level - 1) * 15 + hp_b + rank("vitality") * 20
	dmg = 18 + (level - 1) * 4 + dmg_b + rank("strength") * 5
	armor = arm
	hp = minf(hp, max_hp)
	changed.emit()

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

func add_item(id: String, n := 1) -> bool:
	if id == "gold":
		gold += n
		return true
	if id == "potion":
		for st in inv:
			if st["id"] == "potion":
				st["n"] += n
				return true
	if inv.size() >= Items.INV_SIZE:
		return false
	inv.append({"id": id, "n": n})
	return true

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

func reset_skills() -> void:
	skills = {}
	refresh()
	save_game()

# ---------- Сохранение
func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"level": level, "xp": xp, "gold": gold, "kills": kills, "inv": inv, "equip": equip, "skills": skills}))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	gold = int(d.get("gold", 0))
	kills = int(d.get("kills", 0))
	inv = []
	for st in d.get("inv", []):
		if Items.ALL.has(st["id"]):
			inv.append({"id": st["id"], "n": int(st["n"])})
	for slot in Items.SLOTS:
		var id = d.get("equip", {}).get(slot)
		equip[slot] = id if id != null and Items.ALL.has(id) else null
	skills = {}
	for s in SkillDefs.LIST:
		var r := int(d.get("skills", {}).get(s["id"], 0))
		if r > 0:
			skills[s["id"]] = mini(r, s["max"])
	return true

## Предметы, ранги и добыча с монстров.
## Вещь в инвентаре или на герое — словарь {id, n, r, u}: r — ранг (0–4), u — улучшение оружия (+0…+10).
class_name Items
extends RefCounted

## Ранги: характеристики вещи умножаются на mult
const RANKS := [
	{"name": "Простой", "color": Color("#b4b4b4"), "mult": 1.0},
	{"name": "Обычный", "color": Color("#7fd87f"), "mult": 1.3},
	{"name": "Редкий", "color": Color("#5ab0ff"), "mult": 1.65},
	{"name": "Великий", "color": Color("#c87dff"), "mult": 2.1},
	{"name": "Легендарный", "color": Color("#ffa53a"), "mult": 2.7},
]
const MAX_RANK := 4

## rank — ранг, с которым вещь выпадает из монстров и сундуков
const ALL := {
	"gold": {"name": "Золото", "icon": "🪙", "kind": "gold", "rank": 0},
	"potion": {"name": "Зелье лечения", "icon": "🧪", "kind": "potion", "rank": 0, "heal": 50},
	"shard": {"name": "Тёмный осколок", "icon": "🔮", "kind": "material", "rank": 3},
	"sword_rusty": {"name": "Ржавый меч", "icon": "🗡️", "kind": "weapon", "rank": 0, "dmg": 4, "color": 0x9a7a60, "len": 0.9},
	"sword_iron": {"name": "Железный меч", "icon": "🗡️", "kind": "weapon", "rank": 0, "dmg": 9, "color": 0xc0c8d0, "len": 1.0},
	"sword_bone": {"name": "Костяной меч", "icon": "🦴", "kind": "weapon", "rank": 1, "dmg": 13, "color": 0xe6dfc8, "len": 1.05},
	"sword_steel": {"name": "Стальной меч", "icon": "⚔️", "kind": "weapon", "rank": 1, "dmg": 16, "color": 0xeef4fa, "len": 1.15},
	"sword_crystal": {"name": "Кристальный клинок", "icon": "🔷", "kind": "weapon", "rank": 2, "dmg": 25, "color": 0x8fe8ff, "len": 1.25, "glow": 0x1a7aa8},
	"armor_leather": {"name": "Кожаная куртка", "icon": "🧥", "kind": "armor", "rank": 0, "armor": 4, "color": 0x7a5230},
	"armor_chain": {"name": "Кольчуга", "icon": "⛓️", "kind": "armor", "rank": 1, "armor": 9, "color": 0x8f979f, "metal": true},
	"armor_plate": {"name": "Латы", "icon": "🛡️", "kind": "armor", "rank": 2, "armor": 15, "color": 0xc8ccd4, "metal": true},
	"helm_leather": {"name": "Кожаный шлем", "icon": "🧢", "kind": "helm", "rank": 0, "armor": 2, "color": 0x6a4626},
	"helm_iron": {"name": "Железный шлем", "icon": "⛑️", "kind": "helm", "rank": 1, "armor": 5, "color": 0xa0a8b0},
	"amulet_life": {"name": "Амулет жизни", "icon": "📿", "kind": "amulet", "rank": 1, "hp": 25},
	"amulet_crystal": {"name": "Кристальный амулет", "icon": "💎", "kind": "amulet", "rank": 2, "hp": 40, "dmg": 5},
	# Сапоги: броня и скорость бега (%)
	"boots_leather": {"name": "Кожаные сапоги", "icon": "👢", "kind": "boots", "rank": 0, "armor": 2, "speed": 5, "color": 0x5a3a20},
	"boots_iron": {"name": "Железные сапоги", "icon": "🥾", "kind": "boots", "rank": 1, "armor": 5, "speed": 3, "color": 0x8f979f, "metal": true},
	"boots_wind": {"name": "Сапоги ветра", "icon": "👢", "kind": "boots", "rank": 2, "armor": 3, "speed": 12, "color": 0x6fb8c8},
	# Кольца: урон и шанс крита (%)
	"ring_copper": {"name": "Медное кольцо", "icon": "💍", "kind": "ring", "rank": 0, "dmg": 3},
	"ring_silver": {"name": "Серебряное кольцо", "icon": "💍", "kind": "ring", "rank": 1, "dmg": 4, "crit": 5},
	"ring_ruby": {"name": "Рубиновое кольцо", "icon": "💍", "kind": "ring", "rank": 2, "dmg": 8, "crit": 6, "hp": 15},
	# Плащи: броня и здоровье
	"cloak_wool": {"name": "Шерстяной плащ", "icon": "🧣", "kind": "cloak", "rank": 0, "armor": 2, "hp": 10, "color": 0x7a3a2a},
	"cloak_ranger": {"name": "Плащ следопыта", "icon": "🧣", "kind": "cloak", "rank": 1, "armor": 4, "hp": 20, "color": 0x3a5a3a},
	"cloak_shadow": {"name": "Плащ тени", "icon": "🧣", "kind": "cloak", "rank": 2, "armor": 6, "hp": 35, "color": 0x2a2440},
	# Щиты: броня и сила блока (% урона, который снимает блок сверх обычного)
	"shield_wood": {"name": "Деревянный щит", "icon": "🪵", "kind": "shield", "rank": 0, "armor": 3, "block": 10, "color": 0x7a5230},
	"shield_iron": {"name": "Железный щит", "icon": "🔰", "kind": "shield", "rank": 1, "armor": 6, "block": 18, "color": 0x9aa2ac, "metal": true},
	"shield_tower": {"name": "Башенный щит", "icon": "🔰", "kind": "shield", "rank": 2, "armor": 10, "block": 25, "color": 0xc8ccd4, "metal": true},
}

const SLOTS := ["weapon", "armor", "helm", "amulet", "boots", "ring", "cloak", "shield"]
const INV_SIZE := 20
const STACKS := ["potion", "material"]   # такие вещи складываются в одну ячейку

# ---------- Кузница
const MAX_UPGRADE := 10
const UPGRADE_DMG := 3          # урона за каждую ступень улучшения оружия
const COMBINE_COUNT := 3        # сколько одинаковых вещей соединяется в одну

static func upgrade_cost(u: int) -> int:
	return 25 + 20 * u

## Цена соединения в ранг r + 1: [осколки, золото]
static func combine_cost(r: int) -> Array:
	return [2 + r * 2, 30 + 30 * r]

## Что выпадает: [шанс, мин, макс] золота, шанс зелья, шанс предмета, список предметов
## и [шанс, мин, макс] тёмных осколков (только в подземельях)
const LOOT := {
	"goblin": {"gold": [0.75, 4, 10], "potion": 0.25, "item": 0.15, "pool": ["sword_rusty", "sword_iron", "armor_leather", "helm_leather", "helm_iron", "boots_leather", "ring_copper", "cloak_wool", "shield_wood"]},
	"rabbit": {"gold": [0.65, 5, 12], "potion": 0.25, "item": 0.16, "pool": ["sword_iron", "armor_leather", "helm_leather", "helm_iron", "armor_chain", "boots_leather", "boots_iron", "ring_copper", "ring_silver", "cloak_wool", "shield_wood"]},
	"skeleton": {"gold": [0.6, 6, 14], "potion": 0.3, "item": 0.25, "pool": ["sword_iron", "sword_bone", "armor_chain", "helm_iron", "amulet_life", "sword_steel", "boots_iron", "ring_silver", "cloak_ranger", "shield_iron"], "shard": [0.45, 1, 2]},
	"spider": {"gold": [0.5, 6, 14], "potion": 0.35, "item": 0.25, "pool": ["sword_steel", "armor_chain", "helm_iron", "amulet_life", "sword_crystal", "amulet_crystal", "armor_plate", "boots_wind", "ring_silver", "cloak_ranger", "shield_iron"], "shard": [0.45, 1, 2]},
	"wolf": {"gold": [0.85, 10, 20], "potion": 0.3, "item": 0.3, "pool": ["sword_steel", "sword_bone", "armor_chain", "helm_iron", "armor_plate", "amulet_life", "boots_iron", "boots_wind", "ring_silver", "cloak_ranger", "cloak_shadow", "shield_iron"]},
	"kobold": {"gold": [0.85, 12, 24], "potion": 0.35, "item": 0.35, "pool": ["sword_steel", "sword_bone", "armor_chain", "helm_iron", "armor_plate", "amulet_life", "amulet_crystal", "ring_ruby", "cloak_shadow", "shield_tower", "boots_wind"], "shard": [0.8, 2, 3]},
}

static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {})

## Новая вещь: ранг по умолчанию — тот, с которым она выпадает
static func make(id: String, n := 1, r := -1) -> Dictionary:
	return {"id": id, "n": n, "r": ALL[id]["rank"] if r < 0 else r, "u": 0}

## Привести вещь из старого сохранения к нынешнему виду
static func normalize(v) -> Dictionary:
	if v == null:
		return {}
	if v is String:
		return make(v) if ALL.has(v) else {}
	var id := str(v.get("id", ""))
	if not ALL.has(id):
		return {}
	return {"id": id, "n": int(v.get("n", 1)), "r": clampi(int(v.get("r", ALL[id]["rank"])), 0, MAX_RANK), "u": clampi(int(v.get("u", 0)), 0, MAX_UPGRADE)}

static func rank_of(inst: Dictionary) -> Dictionary:
	return RANKS[int(inst.get("r", 0))]

static func color(inst: Dictionary) -> Color:
	return rank_of(inst)["color"]

## Характеристика вещи с учётом ранга и улучшения
static func stat(inst: Dictionary, key: String) -> int:
	var base: int = int(ALL[inst["id"]].get(key, 0))
	if base == 0:
		return 0
	var v := roundi(base * rank_of(inst)["mult"])
	if key == "dmg" and ALL[inst["id"]]["kind"] == "weapon":
		v += UPGRADE_DMG * int(inst.get("u", 0))
	return v

static func title(inst: Dictionary) -> String:
	var it: Dictionary = ALL[inst["id"]]
	var u := int(inst.get("u", 0))
	return "%s %s%s" % [it["icon"], it["name"], " +%d" % u if u > 0 else ""]

## Свойства вещи одной строкой
static func lines(inst: Dictionary) -> String:
	var l := []
	var dmg := stat(inst, "dmg")
	var arm := stat(inst, "armor")
	var hp := stat(inst, "hp")
	if dmg: l.append("Урон +%d" % dmg)
	if arm: l.append("Броня +%d" % arm)
	if hp: l.append("Здоровье +%d" % hp)
	var spd := stat(inst, "speed")
	var crit := stat(inst, "crit")
	var blk := stat(inst, "block")
	if spd: l.append("Бег +%d%%" % spd)
	if crit: l.append("Крит +%d%%" % crit)
	if blk: l.append("Блок +%d%%" % blk)
	var it: Dictionary = ALL[inst["id"]]
	if it.has("heal"): l.append("Лечит %d здоровья" % it["heal"])
	if it["kind"] == "material": l.append("Нужен в кузнице для соединения вещей")
	return " · ".join(l)

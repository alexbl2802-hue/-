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
	# Эссенция монстра — падает с монстров, из неё алхимик варит зелья
	"essence": {"name": "Эссенция монстра", "icon": "💠", "kind": "material", "rank": 0},
	"shard": {"name": "Тёмный осколок", "icon": "🔮", "kind": "material", "rank": 3},
	# Материалы боссов — для ковки уникального оружия
	"mat_crown": {"name": "Корона Короля-скелета", "icon": "👑", "kind": "material", "rank": 3},
	"mat_chitin": {"name": "Хитин Королевы", "icon": "🪲", "kind": "material", "rank": 3},
	"mat_fang": {"name": "Клык Альфы", "icon": "🦷", "kind": "material", "rank": 3},
	"mat_totem": {"name": "Тотем вождя", "icon": "🗿", "kind": "material", "rank": 3},
	"mat_ember": {"name": "Пустынный уголь", "icon": "🔥", "kind": "material", "rank": 3},
	"mat_frost": {"name": "Ледяное ядро", "icon": "❄️", "kind": "material", "rank": 4},
	"mat_banner": {"name": "Знамя полководца", "icon": "🚩", "kind": "material", "rank": 4},
	"sword_rusty": {"name": "Ржавый меч", "icon": "🗡️", "kind": "weapon", "rank": 0, "dmg": 4, "color": 0x9a7a60, "len": 0.9},
	"sword_iron": {"name": "Железный меч", "icon": "🗡️", "kind": "weapon", "rank": 0, "dmg": 9, "color": 0xc0c8d0, "len": 1.0},
	"sword_bone": {"name": "Костяной меч", "icon": "🦴", "kind": "weapon", "rank": 1, "dmg": 13, "color": 0xe6dfc8, "len": 1.05},
	"sword_steel": {"name": "Стальной меч", "icon": "⚔️", "kind": "weapon", "rank": 1, "dmg": 16, "color": 0xeef4fa, "len": 1.15},
	"sword_crystal": {"name": "Кристальный клинок", "icon": "🔷", "kind": "weapon", "rank": 2, "dmg": 25, "color": 0x8fe8ff, "len": 1.25, "glow": 0x1a7aa8},
	# Двуручники, рапиры, кинжалы — у оружия есть тип (wt), см. WTYPES
	"great_iron": {"name": "Железный двуручник", "icon": "🗡️", "kind": "weapon", "wt": "great", "rank": 0, "dmg": 15, "color": 0xb8c0c8, "len": 1.4},
	"great_obsidian": {"name": "Обсидиановый двуручник", "icon": "🗡️", "kind": "weapon", "wt": "great", "rank": 2, "dmg": 33, "color": 0x3a3048, "len": 1.5, "glow": 0x6a30c0},
	"rapier_steel": {"name": "Стальная рапира", "icon": "🤺", "kind": "weapon", "wt": "rapier", "rank": 1, "dmg": 11, "color": 0xe8eef4, "len": 1.15},
	"rapier_star": {"name": "Звёздная рапира", "icon": "🤺", "kind": "weapon", "wt": "rapier", "rank": 2, "dmg": 19, "color": 0xcfe8ff, "len": 1.2, "glow": 0x4a8aff},
	"dagger_iron": {"name": "Железный кинжал", "icon": "🔪", "kind": "weapon", "wt": "dagger", "rank": 0, "dmg": 6, "color": 0xc0c8d0, "len": 0.55},
	"dagger_venom": {"name": "Ядовитый кинжал", "icon": "🔪", "kind": "weapon", "wt": "dagger", "rank": 1, "dmg": 10, "color": 0x8fd070, "len": 0.6, "glow": 0x40c020},
	# Уникальное оружие — куётся у кузнеца из материалов боссов
	"u_bone_king": {"name": "Клинок Костяного Короля", "icon": "🗡️", "kind": "weapon", "wt": "sword", "rank": 3, "dmg": 30, "color": 0xe8dcc0, "len": 1.2, "glow": 0xff3020, "unique": true},
	"u_queen": {"name": "Жало Королевы", "icon": "🤺", "kind": "weapon", "wt": "rapier", "rank": 3, "dmg": 24, "color": 0x9ad080, "len": 1.2, "glow": 0x40ff30, "unique": true},
	"u_alpha": {"name": "Клык Альфы", "icon": "🗡️", "kind": "weapon", "wt": "great", "rank": 3, "dmg": 44, "color": 0xd8d8e0, "len": 1.5, "glow": 0x90a0ff, "unique": true},
	"u_chief": {"name": "Тесак вождя", "icon": "🔪", "kind": "weapon", "wt": "dagger", "rank": 3, "dmg": 18, "color": 0xa07040, "len": 0.65, "glow": 0xffa020, "unique": true},
	"u_ember": {"name": "Пламенная рапира", "icon": "🤺", "kind": "weapon", "wt": "rapier", "rank": 4, "dmg": 30, "color": 0xff9050, "len": 1.2, "glow": 0xff5010, "unique": true},
	"u_frost": {"name": "Ледяной осколок", "icon": "🔪", "kind": "weapon", "wt": "dagger", "rank": 4, "dmg": 26, "color": 0xbfe8ff, "len": 0.7, "glow": 0x40d0ff, "unique": true},
	"u_warlord": {"name": "Меч Полководца", "icon": "⚔️", "kind": "weapon", "wt": "sword", "rank": 4, "dmg": 42, "color": 0xffe090, "len": 1.25, "glow": 0xffd040, "unique": true},
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
	# Мантия Теневого стража: видна на герое (models/cloak_mantle.glb), выпадает только из сундуков этажей башни (10%)
	"cloak_mantle": {"name": "Мантия Теневого стража", "icon": "🧥", "kind": "cloak", "rank": 3, "armor": 10, "hp": 60, "color": 0x1a1a22},
	# Щиты: броня и сила блока (% урона, который снимает блок сверх обычного)
	"shield_wood": {"name": "Деревянный щит", "icon": "🪵", "kind": "shield", "rank": 0, "armor": 3, "block": 10, "color": 0x7a5230},
	"shield_iron": {"name": "Железный щит", "icon": "🔰", "kind": "shield", "rank": 1, "armor": 6, "block": 18, "color": 0x9aa2ac, "metal": true},
	"shield_tower": {"name": "Башенный щит", "icon": "🔰", "kind": "shield", "rank": 2, "armor": 10, "block": 25, "color": 0xc8ccd4, "metal": true},
}

## Ковка у кузнеца: уникальное оружие из материала босса, тёмных осколков и золота
const RECIPES := [
	{"id": "u_bone_king", "mat": "mat_crown", "shards": 6, "gold": 400},
	{"id": "u_queen", "mat": "mat_chitin", "shards": 6, "gold": 400},
	{"id": "u_alpha", "mat": "mat_fang", "shards": 8, "gold": 600},
	{"id": "u_chief", "mat": "mat_totem", "shards": 8, "gold": 600},
	{"id": "u_ember", "mat": "mat_ember", "shards": 10, "gold": 900},
	{"id": "u_frost", "mat": "mat_frost", "shards": 12, "gold": 1100},
	{"id": "u_warlord", "mat": "mat_banner", "shards": 14, "gold": 1400},
]

## Типы оружия: скорость удара, урон, дальность, прибавка к криту, ширина клинка
const WTYPES := {
	"sword": {"name": "Одноручный меч", "speed": 1.0, "dmg": 1.0, "reach": 1.0, "crit": 0.0, "width": 1.0},
	"great": {"name": "Двуручный меч", "speed": 0.7, "dmg": 1.6, "reach": 1.25, "crit": 0.0, "width": 1.6},
	"rapier": {"name": "Рапира", "speed": 1.35, "dmg": 0.8, "reach": 1.1, "crit": 0.1, "width": 0.45},
	"dagger": {"name": "Кинжал", "speed": 1.7, "dmg": 0.6, "reach": 0.75, "crit": 0.15, "width": 0.7},
}

static func wtype_of(inst) -> Dictionary:
	if inst == null:
		return WTYPES["sword"]
	return WTYPES[ALL[inst["id"]].get("wt", "sword")]

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

## Алхимик: зелья только покупаются или варятся у него — с монстров они не падают
const POTION_PRICE := 30            # золота за зелье
const BREW_ESSENCE := 3             # эссенций на одно зелье
const BREW_GOLD := 5                # и немного золота за работу

## Что выпадает: [шанс, мин, макс] золота, шанс эссенции (поле "potion"), шанс предмета, список предметов
## и [шанс, мин, макс] тёмных осколков (только в подземельях)
const LOOT := {
	"goblin": {"gold": [0.75, 4, 10], "potion": 0.25, "item": 0.15, "pool": ["sword_rusty", "sword_iron", "armor_leather", "helm_leather", "helm_iron", "boots_leather", "ring_copper", "cloak_wool", "shield_wood", "dagger_iron", "great_iron"]},
	"rabbit": {"gold": [0.65, 5, 12], "potion": 0.25, "item": 0.16, "pool": ["sword_iron", "armor_leather", "helm_leather", "helm_iron", "armor_chain", "boots_leather", "boots_iron", "ring_copper", "ring_silver", "cloak_wool", "shield_wood", "dagger_iron", "rapier_steel"]},
	"skeleton": {"gold": [0.6, 6, 14], "potion": 0.3, "item": 0.25, "pool": ["sword_iron", "sword_bone", "armor_chain", "helm_iron", "amulet_life", "sword_steel", "boots_iron", "ring_silver", "cloak_ranger", "shield_iron", "great_iron", "rapier_steel", "dagger_venom"], "shard": [0.45, 1, 2]},
	"spider": {"gold": [0.5, 6, 14], "potion": 0.35, "item": 0.25, "pool": ["sword_steel", "armor_chain", "helm_iron", "amulet_life", "sword_crystal", "amulet_crystal", "armor_plate", "boots_wind", "ring_silver", "cloak_ranger", "shield_iron", "rapier_star", "dagger_venom"], "shard": [0.45, 1, 2]},
	"wolf": {"gold": [0.85, 10, 20], "potion": 0.3, "item": 0.3, "pool": ["sword_steel", "sword_bone", "armor_chain", "helm_iron", "armor_plate", "amulet_life", "boots_iron", "boots_wind", "ring_silver", "cloak_ranger", "cloak_shadow", "shield_iron", "great_iron", "dagger_venom", "rapier_steel"]},
	# Боссы: много золота, два предмета, зелья и осколки
	"skeleton_king": {"mat": "mat_crown", "gold": [1.0, 90, 130], "potion": 1.0, "item": 1.0, "items": 2, "pool": ["sword_steel", "armor_plate", "helm_iron", "shield_tower", "ring_ruby", "cloak_shadow", "amulet_crystal"], "shard": [1.0, 4, 6]},
	"spider_queen": {"mat": "mat_chitin", "gold": [1.0, 80, 120], "potion": 1.0, "item": 1.0, "items": 2, "pool": ["sword_crystal", "amulet_crystal", "boots_wind", "ring_ruby", "cloak_shadow", "shield_tower"], "shard": [1.0, 4, 6]},
	# Стражи этажей башни
	"alpha_wolf": {"mat": "mat_fang", "gold": [1.0, 100, 140], "potion": 1.0, "item": 1.0, "items": 2, "pool": ["sword_steel", "armor_chain", "boots_wind", "cloak_ranger", "ring_silver", "dagger_venom", "rapier_steel"], "shard": [1.0, 4, 6]},
	"goblin_chief": {"mat": "mat_totem", "gold": [1.0, 120, 160], "potion": 1.0, "item": 1.0, "items": 2, "pool": ["sword_bone", "armor_plate", "helm_iron", "shield_iron", "great_iron", "ring_ruby", "cloak_shadow"], "shard": [1.0, 5, 7]},
	"sand_scorpion": {"mat": "mat_ember", "gold": [1.0, 140, 190], "potion": 1.0, "item": 1.0, "items": 2, "pool": ["sword_crystal", "amulet_crystal", "boots_wind", "rapier_star", "dagger_venom", "shield_tower"], "shard": [1.0, 6, 8]},
	"frost_king": {"mat": "mat_frost", "gold": [1.0, 160, 220], "potion": 1.0, "item": 1.0, "items": 2, "pool": ["sword_crystal", "armor_plate", "great_obsidian", "amulet_crystal", "cloak_shadow", "ring_ruby"], "shard": [1.0, 7, 9]},
	"kobold_warlord": {"mat": "mat_banner", "gold": [1.0, 200, 260], "potion": 1.0, "item": 1.0, "items": 3, "pool": ["great_obsidian", "rapier_star", "armor_plate", "shield_tower", "amulet_crystal", "ring_ruby", "cloak_shadow", "boots_wind"], "shard": [1.0, 8, 10]},
	"swamp_mother": {"mat": "mat_chitin", "gold": [1.0, 220, 280], "potion": 0.0, "item": 1.0, "items": 2, "pool": ["dagger_venom", "rapier_star", "boots_wind", "cloak_shadow", "ring_ruby", "amulet_crystal"], "shard": [1.0, 8, 10]},
	"lava_lord": {"mat": "mat_ember", "gold": [1.0, 240, 300], "potion": 0.0, "item": 1.0, "items": 2, "pool": ["great_obsidian", "armor_plate", "shield_tower", "helm_iron", "ring_ruby"], "shard": [1.0, 9, 11]},
	"crystal_guard": {"mat": "mat_frost", "gold": [1.0, 260, 320], "potion": 0.0, "item": 1.0, "items": 3, "pool": ["sword_crystal", "rapier_star", "amulet_crystal", "armor_plate", "cloak_shadow"], "shard": [1.0, 10, 12]},
	"shadow_wolf": {"mat": "mat_fang", "gold": [1.0, 280, 340], "potion": 0.0, "item": 1.0, "items": 3, "pool": ["dagger_venom", "cloak_shadow", "boots_wind", "ring_ruby", "sword_bone"], "shard": [1.0, 11, 13]},
	"sky_king": {"mat": "mat_crown", "gold": [1.0, 400, 500], "potion": 0.0, "item": 1.0, "items": 3, "pool": ["great_obsidian", "sword_crystal", "rapier_star", "armor_plate", "shield_tower", "amulet_crystal", "ring_ruby"], "shard": [1.0, 14, 16]},
	# Плато ветров
	"stone_golem": {"gold": [0.9, 30, 50], "potion": 0.0, "item": 0.35, "pool": ["armor_plate", "shield_tower", "helm_iron", "great_obsidian"], "shard": [0.8, 3, 5]},
	"storm_wolf": {"gold": [0.9, 25, 40], "potion": 0.0, "item": 0.3, "pool": ["boots_wind", "cloak_shadow", "rapier_star", "ring_ruby"], "shard": [0.6, 2, 4]},
	"venom_spider": {"gold": [0.9, 22, 36], "potion": 0.0, "item": 0.3, "pool": ["dagger_venom", "amulet_crystal", "ring_ruby", "cloak_shadow"], "shard": [0.6, 2, 4]},
	"thorn_beast": {"gold": [0.9, 28, 46], "potion": 0.0, "item": 0.35, "pool": ["sword_crystal", "armor_plate", "boots_wind", "amulet_crystal"], "shard": [0.7, 3, 5]},
	"kobold": {"gold": [0.85, 12, 24], "potion": 0.35, "item": 0.35, "pool": ["sword_steel", "sword_bone", "armor_chain", "helm_iron", "armor_plate", "amulet_life", "amulet_crystal", "ring_ruby", "cloak_shadow", "shield_tower", "boots_wind", "great_obsidian", "rapier_star"], "shard": [0.8, 2, 3]},
}

static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {})

## Новая вещь: ранг по умолчанию — тот, с которым она выпадает
static func make(id: String, n := 1, r := -1) -> Dictionary:
	var inst := {"id": id, "n": n, "r": ALL[id]["rank"] if r < 0 else r, "u": 0}
	if ALL[id]["kind"] == "weapon":
		inst["d"] = max_dur(inst)
	return inst

## Прочность оружия: 200 у простого, +100 за каждый ранг
static func max_dur(inst: Dictionary) -> int:
	return 200 + 100 * int(inst.get("r", 0))

static func broken(inst) -> bool:
	return inst != null and inst.has("d") and int(inst["d"]) <= 0

## Цена починки у кузнеца
static func repair_cost(inst: Dictionary) -> int:
	return 5 + ceili((max_dur(inst) - int(inst.get("d", 0))) * 0.3)

## Привести вещь из старого сохранения к нынешнему виду
static func normalize(v) -> Dictionary:
	if v == null:
		return {}
	if v is String:
		return make(v) if ALL.has(v) else {}
	var id := str(v.get("id", ""))
	if not ALL.has(id):
		return {}
	var inst := {"id": id, "n": int(v.get("n", 1)), "r": clampi(int(v.get("r", ALL[id]["rank"])), 0, MAX_RANK), "u": clampi(int(v.get("u", 0)), 0, MAX_UPGRADE)}
	if ALL[id]["kind"] == "weapon":
		inst["d"] = clampi(int(v.get("d", max_dur(inst))), 0, max_dur(inst))
	return inst

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
		if broken(inst):
			v = roundi(v * 0.3)   # сломанное оружие бьёт слабо
	return v

static func title(inst: Dictionary) -> String:
	var it: Dictionary = ALL[inst["id"]]
	var u := int(inst.get("u", 0))
	return "%s %s%s" % [it["icon"], it["name"], " +%d" % u if u > 0 else ""]

## Свойства вещи одной строкой
static func lines(inst: Dictionary) -> String:
	var l := []
	if ALL[inst["id"]]["kind"] == "weapon":
		l.append(wtype_of(inst)["name"])
		l.append(("СЛОМАНО — почини у кузнеца" if broken(inst) else "Прочность %d / %d") % ([] if broken(inst) else [int(inst.get("d", 0)), max_dur(inst)]))
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

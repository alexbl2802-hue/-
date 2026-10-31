## Предметы, редкость и добыча с монстров (как в веб-версии)
class_name Items
extends RefCounted

const RARITY := [
	{"name": "Обычный", "color": Color("#e0e0e0")},
	{"name": "Редкий", "color": Color("#5ab0ff")},
	{"name": "Эпический", "color": Color("#c87dff")},
]

const ALL := {
	"gold": {"name": "Золото", "icon": "🪙", "kind": "gold", "rarity": 0},
	"potion": {"name": "Зелье лечения", "icon": "🧪", "kind": "potion", "rarity": 0, "heal": 50},
	"sword_rusty": {"name": "Ржавый меч", "icon": "🗡️", "kind": "weapon", "rarity": 0, "dmg": 4, "color": 0x9a7a60, "len": 0.9},
	"sword_iron": {"name": "Железный меч", "icon": "🗡️", "kind": "weapon", "rarity": 0, "dmg": 9, "color": 0xc0c8d0, "len": 1.0},
	"sword_bone": {"name": "Костяной меч", "icon": "🦴", "kind": "weapon", "rarity": 1, "dmg": 13, "color": 0xe6dfc8, "len": 1.05},
	"sword_steel": {"name": "Стальной меч", "icon": "⚔️", "kind": "weapon", "rarity": 1, "dmg": 16, "color": 0xeef4fa, "len": 1.15},
	"sword_crystal": {"name": "Кристальный клинок", "icon": "🔷", "kind": "weapon", "rarity": 2, "dmg": 25, "color": 0x8fe8ff, "len": 1.25, "glow": 0x1a7aa8},
	"armor_leather": {"name": "Кожаная куртка", "icon": "🧥", "kind": "armor", "rarity": 0, "armor": 4, "color": 0x7a5230},
	"armor_chain": {"name": "Кольчуга", "icon": "⛓️", "kind": "armor", "rarity": 1, "armor": 9, "color": 0x8f979f, "metal": true},
	"armor_plate": {"name": "Латы", "icon": "🛡️", "kind": "armor", "rarity": 2, "armor": 15, "color": 0xc8ccd4, "metal": true},
	"helm_leather": {"name": "Кожаный шлем", "icon": "🧢", "kind": "helm", "rarity": 0, "armor": 2, "color": 0x6a4626},
	"helm_iron": {"name": "Железный шлем", "icon": "⛑️", "kind": "helm", "rarity": 1, "armor": 5, "color": 0xa0a8b0},
	"amulet_life": {"name": "Амулет жизни", "icon": "📿", "kind": "amulet", "rarity": 1, "hp": 25},
	"amulet_crystal": {"name": "Кристальный амулет", "icon": "💎", "kind": "amulet", "rarity": 2, "hp": 40, "dmg": 5},
}

const SLOTS := ["weapon", "armor", "helm", "amulet"]
const INV_SIZE := 20

## Что выпадает: [шанс, мин, макс] золота, шанс зелья, шанс предмета и список предметов
const LOOT := {
	"slime": {"gold": [0.6, 2, 6], "potion": 0.2, "item": 0.07, "pool": ["sword_rusty", "helm_leather", "armor_leather"]},
	"goblin": {"gold": [0.75, 4, 10], "potion": 0.25, "item": 0.15, "pool": ["sword_rusty", "sword_iron", "armor_leather", "helm_leather", "helm_iron"]},
	"skeleton": {"gold": [0.6, 6, 14], "potion": 0.3, "item": 0.25, "pool": ["sword_iron", "sword_bone", "armor_chain", "helm_iron", "amulet_life", "sword_steel"]},
	"spider": {"gold": [0.5, 6, 14], "potion": 0.35, "item": 0.25, "pool": ["sword_steel", "armor_chain", "helm_iron", "amulet_life", "sword_crystal", "amulet_crystal", "armor_plate"]},
}

static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {})

## Свойства предмета одной строкой
static func lines(it: Dictionary) -> String:
	var l := []
	if it.has("dmg"): l.append("Урон +%d" % it["dmg"])
	if it.has("armor"): l.append("Броня +%d" % it["armor"])
	if it.has("hp"): l.append("Здоровье +%d" % it["hp"])
	if it.has("heal"): l.append("Лечит %d здоровья" % it["heal"])
	return " · ".join(l)

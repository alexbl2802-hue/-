extends RefCounted
class_name CardinalItemSystem
enum Rarity {COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC}
const LABELS := ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный", "Мифический"]
const COLORS := [Color.GRAY, Color.GREEN, Color.DODGER_BLUE, Color.MEDIUM_PURPLE, Color.GOLD, Color.RED]
const BONUS_RANGES := [Vector2(0.0,0.05), Vector2(0.05,0.12), Vector2(0.12,0.22), Vector2(0.22,0.35), Vector2(0.35,0.50), Vector2(0.50,0.70)]
static func roll_item(base_stats: Dictionary, rarity: int, rng: RandomNumberGenerator = null) -> Dictionary:
 rarity = clampi(rarity, 0, 5)
 if rng == null:
  rng = RandomNumberGenerator.new()
  rng.randomize()
 var rolled := {}
 var bounds: Vector2 = BONUS_RANGES[rarity]
 for stat in base_stats:
  var base = base_stats[stat]
  if base is int or base is float:
   var bonus := rng.randf_range(bounds.x, bounds.y)
   rolled[stat] = roundi(float(base) * (1.0 + bonus)) if base is int else float(base) * (1.0 + bonus)
  else:
   rolled[stat] = base
 return {"rarity": rarity, "rarity_name": LABELS[rarity], "stats": rolled}

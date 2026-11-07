extends RefCounted
class_name CardinalLootManager
## Unified reward resolver: uses Items.LOOT as the authoritative monster/boss registry.
var rng := RandomNumberGenerator.new()
func _init() -> void:
	rng.randomize()

func roll(table: Array, difficulty: float = 1.0, rolls: int = 1) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var valid: Array[Dictionary] = []
	var total := 0.0
	for entry in table:
		if not entry is Dictionary:
			continue
		var id := str(entry.get("id", ""))
		var weight := float(entry.get("weight", 0.0))
		if not Items.ALL.has(id) or not is_finite(weight) or weight <= 0.0:
			continue
		valid.append(entry)
		total += weight
	if total <= 0.0:
		return output
	for _i in range(clampi(rolls, 0, 100)):
		var ticket := rng.randf() * total
		for entry in valid:
			ticket -= float(entry.get("weight", 0.0))
			if ticket > 0.0:
				continue
			if rng.randf() <= clampf(float(entry.get("chance", 1.0)), 0.0, 1.0):
				var low := maxi(1, int(entry.get("min", 1)))
				var high := maxi(low, int(entry.get("max", low)))
				var id := str(entry["id"])
				var amount := rng.randi_range(low, high)
				if id == "gold" or Items.ALL[id].get("kind", "") == "material":
					amount = maxi(1, roundi(amount * clampf(difficulty, 0.5, 3.0)))
				var rank := int(Items.ALL[id].get("rank", 0))
				if Items.ALL[id].get("kind", "") in ["weapon", "armor", "helm", "boots", "ring", "amulet", "cloak", "shield"]:
					rank = Items.roll_rank(rank, rng, difficulty)
				output.append({"id": id, "amount": amount, "rank": rank})
			break
	return output

func roll_enemy(enemy_id: String, difficulty: float = 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not Items.LOOT.has(enemy_id):
		return result
	var data: Dictionary = Items.LOOT[enemy_id]
	if data.has("mat") and Items.ALL.has(str(data["mat"])):
		result.append({"id": str(data["mat"]), "amount": 1, "rank": int(Items.ALL[str(data["mat"])]["rank"])})
	var gold: Array = data.get("gold", [])
	if gold.size() >= 3 and rng.randf() < float(gold[0]):
		result.append({"id": "gold", "amount": rng.randi_range(int(gold[1]), int(gold[2])), "rank": 0})
	if rng.randf() < maxf(float(data.get("potion", 0.0)), 0.45):
		result.append({"id": "essence", "amount": rng.randi_range(3, 5) if data.has("mat") else 1, "rank": 0})
	var pool: Array = data.get("pool", [])
	var table: Array = []
	for id in pool:
		if Items.ALL.has(str(id)):
			var base := clampi(int(Items.ALL[str(id)].get("rank", 0)), 0, Items.MAX_RANK)
			table.append({"id": str(id), "weight": Items.RANK_WEIGHTS[base], "chance": 1.0})
	for _i in range(clampi(int(data.get("items", 1)), 0, 20)):
		if rng.randf() < clampf(float(data.get("item", 0.0)), 0.0, 1.0):
			result.append_array(roll(table, difficulty))
	var shard: Array = data.get("shard", [])
	if shard.size() >= 3 and rng.randf() < float(shard[0]):
		result.append({"id": "shard", "amount": rng.randi_range(int(shard[1]), int(shard[2])), "rank": int(Items.ALL["shard"]["rank"])})
	return result

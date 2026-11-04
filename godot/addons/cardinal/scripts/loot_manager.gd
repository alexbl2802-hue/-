extends RefCounted
class_name CardinalLootManager
## Формат записи: {"id":"wolf_fang", "weight":50.0, "min":1, "max":2, "chance":0.7}
var rng := RandomNumberGenerator.new()
func _init() -> void:
    rng.randomize()

func roll(table: Array, difficulty: float = 1.0, rolls: int = 1) -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    if table.is_empty(): return output
    var valid: Array[Dictionary] = []
    var total := 0.0
    for item in table:
        if not item is Dictionary: continue
        var weight := float(item.get('weight', 0.0))
        if not is_finite(weight) or weight <= 0.0: continue
        if str(item.get('id', '')).is_empty(): continue
        valid.append(item)
        total += weight
    if total <= 0.0: return output
    for _i in range(clampi(rolls, 0, 100)):
        var ticket := rng.randf_range(0.0, total)
        var cumulative := 0.0
        for item in valid:
            cumulative += float(item['weight'])
            if ticket <= cumulative:
                var chance := clampf(float(item.get('chance', 1.0)), 0.0, 1.0)
                if rng.randf() <= chance:
                    var minimum := maxi(0, int(item.get('min', 1)))
                    var maximum := maxi(minimum, int(item.get('max', minimum)))
                    var amount := rng.randi_range(minimum, maximum)
                    amount = maxi(1, roundi(float(amount) * clampf(difficulty, 0.5, 3.0)))
                    output.append({'id': str(item['id']), 'amount': amount})
                break
    return output

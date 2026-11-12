## ANIMATE 4.0 — шаг 1–2 конвейера: разбор описания → параметры движения.
## Это детерминированный разбор по словарю ключевых слов (русский и английский), а не ИИ
## «текст → движение»: незнакомые слова не угадываются, а попадают в отчёт (unknown).
class_name AnimateSpec
extends RefCounted


## Ключевые слова → движение. Порядок важен: первое совпадение побеждает
const MOTION_WORDS := [
	["thrust_dash", ["выпад", "укол", "колющ", "thrust", "lunge", "stab"]],
	["whirl", ["вихрь", "кругов", "разворот", "whirl", "spin", "360"]],
	["horizontal", ["горизонт", "горизонтальн", "взмах", "рубящ", "horizontal", "slash", "sweep"]],
	["block_shield", ["щит", "shield"]],
	["block_sword", ["блок", "защит", "парир", "block", "guard", "parry"]],
	["dash", ["рывок", "рывк", "dash", "сдвиг", "уклон"]],
	["sheathe", ["ножн", "убра", "sheath"]],
	["stance", ["стойк", "stance", "idle"]],
]
const DIR_WORDS := {
	"forward": ["вперёд", "вперед", "forward"], "back": ["назад", "back", "backward"],
	"left": ["влево", "налево", "left"], "right": ["вправо", "направо", "right"],
}
const RUN_WORDS := ["с бега", "на бегу", "из бега", "from run", "running"]
const FAST_WORDS := ["молниенос", "быстр", "резк", "lightning", "fast", "quick"]
const SLOW_WORDS := ["медлен", "плавн", "slow"]

## Итог: {motion, dir, from_run, speed, matched: [...], unknown: [...], ok, error}
static func parse(text: String) -> Dictionary:
	var t := text.to_lower().strip_edges()
	var spec := {"motion": "", "dir": "forward", "from_run": false, "speed": 1.0, "matched": [], "unknown": [], "ok": false, "error": "", "text": text}
	for pair in MOTION_WORDS:
		for w in pair[1]:
			if t.contains(w):
				spec["motion"] = pair[0]
				spec["matched"].append(w)
				break
		if spec["motion"] != "":
			break
	# «выпад с рывком» — это выпад, а не отдельный рывок
	for d in DIR_WORDS:
		for w in DIR_WORDS[d]:
			if t.contains(w):
				spec["dir"] = d
				spec["matched"].append(w)
	for w in RUN_WORDS:
		if t.contains(w):
			spec["from_run"] = true
			spec["matched"].append(w)
	for w in FAST_WORDS:
		if t.contains(w):
			spec["speed"] = 1.35
			spec["matched"].append(w)
	for w in SLOW_WORDS:
		if t.contains(w):
			spec["speed"] = 0.75
			spec["matched"].append(w)
	var vocab: Array = ["удар", "меч", "sword", "атак", "attack", "места", "with", "the", "and"]
	for pair in MOTION_WORDS:
		vocab.append_array(pair[1])
	for d in DIR_WORDS:
		vocab.append_array(DIR_WORDS[d])
	for w in RUN_WORDS + FAST_WORDS + SLOW_WORDS:
		vocab.append_array(w.split(" "))
	for word in t.replace(",", " ").replace(".", " ").replace("—", " ").split(" ", false):
		var known := word.length() <= 2
		for v in vocab:
			if v.length() > 2 and word.contains(v):
				known = true
				break
		if not known:
			spec["unknown"].append(word)
	if spec["motion"] == "":
		spec["error"] = "Не распознано движение. Известны: выпад, горизонтальный удар, вихрь, блок мечом, блок щитом, рывок (+ вперёд/назад/влево/вправо, с бега)."
	else:
		spec["ok"] = true
	return spec

## Монстр: модель, поведение (бродит → гонится → замах → удар → отдых → домой),
## вспышка при попадании, падение при смерти и возвращение в долину через время.
extends CharacterBody3D

const TYPES := {
	"goblin": {"name": "Гоблин", "hp": 70, "dmg": 10, "speed": 4.6, "walk": 0.8, "r": 0.45, "aggro": 15.0, "reach": 1.7, "cd": 1.1, "windup": 0.4, "bar": 2.0},
	"skeleton": {"name": "Скелет", "hp": 80, "dmg": 12, "speed": 3.9, "r": 0.45, "aggro": 13.0, "reach": 1.8, "cd": 1.2, "windup": 0.45, "bar": 2.4},
	"spider": {"name": "Паук", "hp": 55, "dmg": 9, "speed": 5.2, "r": 0.7, "aggro": 12.0, "reach": 1.7, "cd": 0.9, "windup": 0.35, "bar": 1.4, "lunge": true},
	# Кролик с длинными когтями: сильнее гоблина, бродит по всему миру
	"rabbit": {"name": "Кролик-оборотень", "hp": 85, "dmg": 16, "speed": 7.8, "walk": 0.9, "r": 0.45, "aggro": 14.0, "reach": 1.7, "cd": 0.75, "windup": 0.06, "bar": 2.0, "lunge": true, "roam": true},
	# Кобольд в броне с мечом: живёт в подземельях, крепкий и бьёт больно
	# Шипастый волк-убийца: бьёт лапой вблизи, издалека поднимает хвост и стреляет шипами
	"wolf": {"name": "Шипастый волк-убийца", "hp": 100, "dmg": 20, "speed": 6.4, "r": 0.55, "aggro": 18.0, "reach": 1.9, "cd": 0.9, "windup": 0.22, "bar": 1.7,
		"spikes": {"near": 5.0, "far": 15.0, "cd": 3.0, "aim": 0.55, "count": 3, "speed": 24.0}},
	# Боссы подземелий — стерегут сундук; побеждённый босс больше не появляется
	"skeleton_king": {"name": "Король-скелет", "boss": true, "hp": 650, "dmg": 32, "speed": 3.8, "r": 0.85, "aggro": 16.0, "reach": 2.9, "cd": 1.3, "windup": 0.6, "bar": 4.1, "scale": 1.8,
		"slam": {"radius": 5.0, "cd": 7.0, "aim": 1.0, "dmg": 40}},
	"spider_queen": {"name": "Королева-паучиха", "boss": true, "hp": 550, "dmg": 28, "speed": 4.8, "r": 1.2, "aggro": 16.0, "reach": 2.9, "cd": 1.0, "windup": 0.4, "bar": 2.8, "scale": 2.0, "lunge": true,
		"spit": {"near": 4.0, "far": 16.0, "cd": 4.0, "aim": 0.6, "count": 5, "speed": 16.0}},
	# Стражи этажей башни: модель обычного монстра ("model"), свой цвет ("tint"), корона и размер
	"alpha_wolf": {"name": "Альфа-волк", "model": "wolf", "tint": 0x8a8090, "boss": true, "hp": 520, "dmg": 24, "speed": 6.8, "r": 0.9, "aggro": 18.0, "reach": 2.8, "cd": 0.9, "windup": 0.3, "bar": 2.9, "scale": 1.7,
		"spikes": {"near": 5.0, "far": 16.0, "cd": 3.5, "aim": 0.6, "count": 5, "speed": 24.0}},
	"goblin_chief": {"name": "Вождь гоблинов", "model": "goblin", "boss": true, "hp": 600, "dmg": 26, "speed": 4.4, "r": 0.8, "aggro": 16.0, "reach": 2.7, "cd": 1.1, "windup": 0.5, "bar": 3.3, "scale": 1.7,
		"slam": {"radius": 5.0, "cd": 6.5, "aim": 0.9, "dmg": 30}},
	"sand_scorpion": {"name": "Песчаный скорпион", "model": "spider", "tint": 0xd8a860, "boss": true, "hp": 620, "dmg": 26, "speed": 5.0, "r": 1.2, "aggro": 16.0, "reach": 2.9, "cd": 0.95, "windup": 0.4, "bar": 2.8, "scale": 2.1, "lunge": true,
		"spit": {"near": 4.0, "far": 16.0, "cd": 3.5, "aim": 0.6, "count": 5, "speed": 17.0}},
	"frost_king": {"name": "Ледяной король", "model": "skeleton_king", "tint": 0x9ad0ff, "boss": true, "hp": 700, "dmg": 30, "speed": 3.9, "r": 0.85, "aggro": 16.0, "reach": 2.9, "cd": 1.2, "windup": 0.55, "bar": 4.1, "scale": 1.9,
		"slam": {"radius": 5.5, "cd": 6.0, "aim": 0.9, "dmg": 36}},
	"kobold_warlord": {"name": "Полководец кобольдов", "model": "kobold", "tint": 0xb07050, "boss": true, "hp": 800, "dmg": 32, "speed": 4.4, "r": 0.8, "aggro": 16.0, "reach": 2.9, "cd": 0.9, "windup": 0.35, "bar": 3.6, "scale": 1.7,
		"slam": {"radius": 5.5, "cd": 6.0, "aim": 0.8, "dmg": 40}},
	"swamp_mother": {"name": "Болотная матка", "model": "spider", "tint": 0x7aa060, "boss": true, "hp": 660, "dmg": 27, "speed": 4.8, "r": 1.3, "aggro": 16.0, "reach": 3.0, "cd": 1.0, "windup": 0.4, "bar": 3.0, "scale": 2.3, "lunge": true,
		"spit": {"near": 4.0, "far": 17.0, "cd": 3.2, "aim": 0.6, "count": 7, "speed": 17.0}},
	"lava_lord": {"name": "Огненный повелитель", "model": "kobold", "tint": 0xff7050, "boss": true, "hp": 760, "dmg": 31, "speed": 4.6, "r": 0.85, "aggro": 16.0, "reach": 3.0, "cd": 0.9, "windup": 0.35, "bar": 3.8, "scale": 1.85,
		"slam": {"radius": 6.0, "cd": 5.5, "aim": 0.8, "dmg": 40}},
	"crystal_guard": {"name": "Кристальный страж", "model": "skeleton_king", "tint": 0xb090ff, "boss": true, "hp": 820, "dmg": 32, "speed": 4.0, "r": 0.9, "aggro": 16.0, "reach": 3.0, "cd": 1.1, "windup": 0.5, "bar": 4.3, "scale": 2.0,
		"slam": {"radius": 6.0, "cd": 5.5, "aim": 0.85, "dmg": 42}},
	"shadow_wolf": {"name": "Теневой волк", "model": "wolf", "tint": 0x3a3a50, "boss": true, "hp": 720, "dmg": 33, "speed": 7.4, "r": 1.0, "aggro": 18.0, "reach": 3.0, "cd": 0.8, "windup": 0.25, "bar": 3.1, "scale": 1.9,
		"spikes": {"near": 5.0, "far": 18.0, "cd": 3.0, "aim": 0.5, "count": 7, "speed": 26.0}},
	"sky_king": {"name": "Небесный король", "model": "skeleton_king", "tint": 0xffe090, "boss": true, "hp": 950, "dmg": 35, "speed": 4.2, "r": 0.95, "aggro": 18.0, "reach": 3.2, "cd": 1.0, "windup": 0.45, "bar": 4.5, "scale": 2.2,
		"slam": {"radius": 6.5, "cd": 5.0, "aim": 0.8, "dmg": 46}},
	# Мини-боссы этажей башни (по картинке этажей; характеристики и добыча — от прежних стражей этажей)
	"golem_warden": {"name": "Каменный голем-страж", "model": "golem", "tint": 0xa8a090, "boss": true, "hp": 520, "dmg": 24, "speed": 3.6, "r": 0.9, "aggro": 16.0, "reach": 2.8, "cd": 1.2, "windup": 0.55, "bar": 3.8, "scale": 1.35,
		"slam": {"radius": 5.0, "cd": 6.0, "aim": 0.9, "dmg": 28}},
	"crystal_spider": {"name": "Кристальный паук", "model": "spider", "tint": 0x6ab8ff, "boss": true, "hp": 600, "dmg": 26, "speed": 4.8, "r": 1.2, "aggro": 16.0, "reach": 2.9, "cd": 1.0, "windup": 0.4, "bar": 2.8, "scale": 2.1, "lunge": true},
	"toxic_mutant": {"name": "Токсичный мутант", "model": "golem", "tint": 0x6ad040, "boss": true, "hp": 620, "dmg": 26, "speed": 3.8, "r": 0.9, "aggro": 16.0, "reach": 2.9, "cd": 1.1, "windup": 0.5, "bar": 3.8, "scale": 1.4,
		"slam": {"radius": 5.0, "cd": 6.0, "aim": 0.9, "dmg": 32}},
	"ice_beast": {"name": "Ледяной зверь", "model": "wolf", "tint": 0xb0e4ff, "boss": true, "hp": 700, "dmg": 30, "speed": 7.0, "r": 0.95, "aggro": 18.0, "reach": 2.9, "cd": 0.9, "windup": 0.3, "bar": 3.0, "scale": 1.9,
		"spikes": {"near": 5.0, "far": 16.0, "cd": 3.2, "aim": 0.55, "count": 6, "speed": 25.0}},
	"fire_demon": {"name": "Огненный демон", "model": "golem", "tint": 0xff5a20, "boss": true, "hp": 800, "dmg": 32, "speed": 4.0, "r": 0.9, "aggro": 16.0, "reach": 3.0, "cd": 1.0, "windup": 0.4, "bar": 4.0, "scale": 1.5,
		"slam": {"radius": 6.0, "cd": 5.5, "aim": 0.8, "dmg": 40}},
	"forest_keeper": {"name": "Хранитель леса", "model": "golem", "tint": 0x7a9a4a, "boss": true, "hp": 660, "dmg": 27, "speed": 3.6, "r": 1.0, "aggro": 16.0, "reach": 3.0, "cd": 1.1, "windup": 0.5, "bar": 4.2, "scale": 1.6,
		"slam": {"radius": 6.0, "cd": 6.0, "aim": 0.9, "dmg": 36}},
	"elemental_guard": {"name": "Страж стихий", "model": "skeleton_king", "tint": 0x7ab8ff, "boss": true, "hp": 760, "dmg": 31, "speed": 4.4, "r": 0.9, "aggro": 16.0, "reach": 3.0, "cd": 0.9, "windup": 0.4, "bar": 4.2, "scale": 2.0,
		"slam": {"radius": 6.0, "cd": 5.5, "aim": 0.8, "dmg": 40}},
	"shadow_wraith": {"name": "Теневой призрак", "model": "skeleton_king", "tint": 0x6a3aa8, "boss": true, "hp": 820, "dmg": 32, "speed": 4.6, "r": 0.9, "aggro": 16.0, "reach": 3.0, "cd": 1.0, "windup": 0.4, "bar": 4.3, "scale": 2.0,
		"slam": {"radius": 6.0, "cd": 5.5, "aim": 0.85, "dmg": 42}},
	"necromancer": {"name": "Некромант", "model": "skeleton_king", "tint": 0x3ae0b0, "boss": true, "hp": 760, "dmg": 33, "speed": 4.2, "r": 0.9, "aggro": 16.0, "reach": 3.1, "cd": 1.0, "windup": 0.45, "bar": 4.3, "scale": 2.0,
		"slam": {"radius": 6.5, "cd": 5.0, "aim": 0.8, "dmg": 44}},
	"tower_lord": {"name": "Повелитель башни", "model": "golem", "tint": 0xd03a20, "boss": true, "hp": 1100, "dmg": 35, "speed": 4.0, "r": 1.1, "aggro": 18.0, "reach": 3.4, "cd": 1.0, "windup": 0.45, "bar": 5.0, "scale": 2.1,
		"slam": {"radius": 7.0, "cd": 5.0, "aim": 0.8, "dmg": 48}},
	# Монстры Плато ветров (второй мир над башней)
	"stone_golem": {"name": "Каменный голем", "model": "golem", "hp": 260, "dmg": 30, "speed": 3.4, "r": 0.8, "aggro": 14.0, "reach": 2.4, "cd": 1.4, "windup": 0.6, "bar": 3.2,
		"slam": {"radius": 4.0, "cd": 6.0, "aim": 0.9, "dmg": 34}},
	"storm_wolf": {"name": "Грозовой волк", "model": "wolf", "tint": 0xa8c4ff, "hp": 150, "dmg": 24, "speed": 7.2, "r": 0.6, "aggro": 20.0, "reach": 2.0, "cd": 0.8, "windup": 0.2, "bar": 1.8,
		"spikes": {"near": 5.0, "far": 16.0, "cd": 2.6, "aim": 0.45, "count": 4, "speed": 26.0}},
	"venom_spider": {"name": "Ядовитый паук", "model": "spider", "tint": 0xb070d8, "hp": 120, "dmg": 20, "speed": 5.6, "r": 0.8, "aggro": 14.0, "reach": 1.9, "cd": 0.9, "windup": 0.3, "bar": 1.6, "lunge": true, "scale": 1.3,
		"spit": {"near": 4.0, "far": 14.0, "cd": 3.0, "aim": 0.5, "count": 3, "speed": 16.0}},
	"thorn_beast": {"name": "Тернистый зверь", "model": "wolf", "tint": 0x6a9a48, "hp": 210, "dmg": 28, "speed": 6.0, "r": 0.75, "aggro": 16.0, "reach": 2.2, "cd": 0.9, "windup": 0.25, "bar": 2.2, "scale": 1.35,
		"spikes": {"near": 4.0, "far": 14.0, "cd": 2.2, "aim": 0.4, "count": 6, "speed": 22.0}},
	"kobold": {"name": "Кобольд", "hp": 130, "dmg": 23, "speed": 4.2, "r": 0.45, "aggro": 13.0, "reach": 2.0, "cd": 0.85, "windup": 0.06, "bar": 2.1},
}
const GRAVITY := 25.0

var type := "goblin"
var dungeon_idx := -1       # номер подземелья (для босса — какой сундук он стережёт)
var level := 1               # уровень монстра — показывается над ним; в башне растёт от этажа к этажу
var guard_room: Node3D = null   # этаж башни, если это страж (не покидает комнату)
var model := ""              # чья модель (у стражей башни — обычного монстра)
var in_dungeon := false
var world2 := false          # монстр Плато ветров (второй мир над башней)
var T: Dictionary
var hero: Node3D
var home := Vector3.ZERO
var hp := 1.0
var st := "idle"
var dead := false
var facing := 0.0

var _t := 0.0
var _kb := Vector3.ZERO
var _flash := 0.0
var _walk := 0.0
var _hop := randf() * 6.0
var _speed_now := 0.0
var _moving := false
var _wander = null
var _wander_t := randf() * 3.0
var _dead_t := 0.0
var _model: Node3D
var _body: Node3D
var _legs: Array = []
var _arms: Array = []
var _mats: Array = []
var _shape: CollisionShape3D
var _char: Node3D            # модель с анимациями (сейчас — гоблин из models/goblin.glb)
var _ap: AnimationPlayer
var _flash_mat: StandardMaterial3D
var _anim_on := true
var _swing := false

const GOBLIN_MODEL := "res://models/goblin.glb"
const BUNNY_MODEL := "res://models/bunny.glb"
var _wind_len := 0.0         # замах до первого удара (у кролика — свой у каждой атаки)
var _rec_len := 0.0          # отдых после удара
var _extra_hits := []        # следующие удары комбо: время от первого удара
var _leap_dir := Vector3.ZERO
var _leap_hit_done := false
var _leap_cd := 2.0
var _spike_cd := 1.0
var _tail: Node3D          # хвост волка (поднимается при выстреле)
var _tail_tip: Node3D      # откуда вылетают шипы

var _leap_atk := false
var _leap_dist := 0.0
const LEAP_DUR := 0.95
const LEAP_AIR := [0.28, 0.78]
const LEAP_HIT := 0.8
var _dodge_t := -1.0

## Сила монстра по уровню: здоровье +35%, урон +20% за каждый уровень выше первого
static func scaled(kind: String, lvl: int) -> Dictionary:
	var t: Dictionary = TYPES[kind].duplicate(true)
	if lvl > 1:
		var hp_k := 1.0 + 0.35 * (lvl - 1)
		var dmg_k := 1.0 + 0.2 * (lvl - 1)
		t["hp"] = roundi(t["hp"] * hp_k)
		t["dmg"] = roundi(t["dmg"] * dmg_k)
		for k in ["slam"]:
			if t.has(k):
				t[k]["dmg"] = roundi(t[k]["dmg"] * dmg_k)
	return t

func setup(kind: String, pos: Vector3, h: Node3D, lvl := 1) -> void:
	type = kind
	level = lvl
	T = scaled(kind, lvl) if lvl > 1 else TYPES[kind]
	model = T.get("model", kind)
	hero = h
	home = pos
	hp = T["hp"]
	facing = randf() * TAU

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.5
	var shape := CapsuleShape3D.new()
	shape.radius = T["r"]
	shape.height = maxf(1.2, T["r"] * 2.0 + 0.2)
	_shape = CollisionShape3D.new()
	_shape.shape = shape
	_shape.position.y = shape.height / 2.0
	add_child(_shape)
	_model = Node3D.new()
	add_child(_model)
	match model:
		"goblin": _build_humanoid(0.82, 0x6aa84f, 0x6b4a2b, 0x3d2a18, 0xffd400, 0.6, 0.56, 0.2, true, false, "club")
		"skeleton": _build_humanoid(1.0, 0xe6dfc8, 0xd8d0b8, 0x3a3228, 0x6fd0ff, 1.5, 0.46, 0.13, false, true, "sword")
		"spider": _build_spider()
		"rabbit": _build_rabbit()
		"kobold": _build_kobold()
		"wolf": _build_wolf()
		"golem":
			# Каменный голем: крупный, широкий, светящиеся глаза, без оружия
			_build_humanoid(1.5, 0x8a8478, 0x6a645c, 0x3a3630, 0x60ffb0, 1.4, 0.9, 0.32, false, false, "none")
		"skeleton_king":
			_build_humanoid(1.0, 0xd8d0b8, 0x7a1f2a, 0x2a1a14, 0xff4020, 2.2, 0.5, 0.14, false, true, "sword")
			_add_crown(1.93)
		"spider_queen":
			_build_spider()
			_add_crown(0.98, Vector3(0, 0, 0.18))
	# Цвет стража этажа
	if T.has("tint"):
		var tint := WorldGen.hex(T["tint"])
		for m in _mats:
			m.set_shader_parameter("albedo", (m.get_shader_parameter("albedo") as Color) * tint)
	# Корона у стражей башни (у королей она уже есть)
	if T.get("boss", false) and T.has("model") and model != "skeleton_king" and model != "goblin":
		_add_crown(_crown_at().y, _crown_at())
	# Боссы крупнее обычных монстров
	if T.has("scale"):
		for c in _model.get_children():
			c.scale *= T["scale"]
			c.position *= T["scale"]
	Cardinal.register_mob(self, T.get("boss", false))   # учёт монстров системой Cardinal
	if CHARS.has(model) and ResourceLoader.exists(CHARS[model]["glb"]):
		_attach_char()
	if _char and T.has("scale"):
		_char.scale *= T["scale"]
	# Корона у стражей на моделях — поверх модели, в размер стража
	if _char and (T.get("boss", false) or model == "skeleton_king"):
		var hgt: float = (1.62 if C["glb"] == GOBLIN_MODEL else 1.85) * C["scale"] * T.get("scale", 1.0)
		var at := Vector3.ZERO
		if C.has("crown"):
			at = C["crown"] * C["scale"] * T.get("scale", 1.0)
			hgt = at.y
		_add_crown(hgt, at)
		_model.get_child(_model.get_child_count() - 1).scale = Vector3.ONE * T.get("scale", 1.0) * 0.8
	global_position = home

# ---------- Мобы на моделях Meshy: все движения — клипы Meshy (свои у модели или перенесённые
# с героя: tools/prepare_models.py meshy_to), раскраска — перекраска Meshy в аниме-стиле.
const HERO_MODEL := "res://models/hero.glb"
const WOLF_MODEL := "res://models/wolf.glb"
const SKELETON_MODEL := "res://models/skeleton.glb"   # присланный скелет-воин со своими движениями
const SPIDER_MODEL := "res://models/spider.glb"
const SKIN_DIR := "res://models/skins/"
## Удары монстров-людей — из присланного файла (tools/rig_from_mannequin.py): [клип, момент удара]
const CHAR_ATK := {"slash": ["Double_Combo_Attack", 0.63], "overhead": ["Attack", 1.07], "side": ["Axe_Spin_Attack", 0.87]}
const CHARS := {
	"goblin": {"glb": GOBLIN_MODEL, "skin": "goblin", "scale": 0.92, "walk": ["Slow_Orc_Walk", 0.27], "run": ["Running", 3.45], "weapon": "club", "atk": CHAR_ATK},
	"kobold": {"glb": GOBLIN_MODEL, "skin": "kobold", "scale": 1.0, "walk": ["Walk_Fight_Forward", 0.6], "run": ["Running", 3.45], "weapon": "sword", "atk": CHAR_ATK},
	"golem": {"glb": GOBLIN_MODEL, "skin": "golem", "scale": 1.55, "walk": ["Slow_Orc_Walk", 0.27], "run": ["Running", 3.45], "weapon": "", "atk": {"slash": ["Attack", 1.07], "side": ["Charged_Slash", 1.17]}},
	"skeleton": {"glb": SKELETON_MODEL, "skin": "", "scale": 1.0, "stance": "Combat_Stance", "walk": ["Walk_Fight_Forward", 0.6], "run": ["Lean_Forward_Sprint", 3.2], "weapon": "sword", "atk": CHAR_ATK, "hit": "Hit"},
	"skeleton_king": {"glb": SKELETON_MODEL, "skin": "", "scale": 1.1, "stance": "Combat_Stance", "walk": ["Walk_Fight_Forward", 0.6], "run": ["Lean_Forward_Sprint", 3.2], "weapon": "great", "atk": CHAR_ATK, "hit": "Hit"},
	# Звери — присланные модели с движениями (meshy/beasts, tools/beasts_from_user.py)
	"wolf": {"glb": WOLF_MODEL, "spring": ["Bone_017", "Bone_015"], "skin": "", "scale": 0.85, "stance": "Idle", "walk": ["Wolf_Walk", 0.75], "run": ["Wolf_Run", 4.9], "weapon": "", "atk": {"slash": ["Wolf_Bite", 0.35], "side": ["Wolf_Paw_Swipe", 0.35]}, "hit": "Hit", "aim": "Wolf_Tail_Spike_Shot", "tail": "Bone_015", "crown": Vector3(0, 1.55, 1.3)},
	"spider": {"glb": SPIDER_MODEL, "skin": "", "scale": 0.6, "stance": "Idle", "walk": ["Spider_Walk", 1.2], "run": ["Spider_Chase", 3.5], "weapon": "", "atk": {"slash": ["Spider_Double_Claw", 0.4]}, "hit": "Hit", "aim": "Spider_Venom_Spit", "crown": Vector3(0, 1.45, 0.6)},
	"spider_queen": {"glb": SPIDER_MODEL, "skin": "", "scale": 0.8, "stance": "Idle", "walk": ["Spider_Walk", 1.2], "run": ["Spider_Chase", 3.5], "weapon": "", "atk": {"slash": ["Spider_Double_Claw", 0.4]}, "hit": "Hit", "aim": "Spider_Venom_Spit", "crown": Vector3(0, 1.45, 0.6)},
	"rabbit": {"glb": BUNNY_MODEL, "skin": "bunny", "scale": 0.9, "walk": ["Walking", 0.9], "run": ["Running", 3.0], "weapon": "", "atk": {"slash": ["Boxing_Guard_Prep_Straight_Punch", 0.75], "kick": ["Flying_Fist_Kick", 0.9]}},
}
var C: Dictionary = {}        # описание модели моба из CHARS

func _attach_char() -> void:
	C = CHARS[model]
	for c in _model.get_children():
		c.visible = false
	_char = (load(C["glb"]) as PackedScene).instantiate()
	_char.scale = Vector3.ONE * C["scale"]
	_model.add_child(_char)
	_ap = _char.find_children("*", "AnimationPlayer", true, false)[0]
	_add_spring()
	_ap.playback_default_blend_time = 0.15
	for n in [_stance(), C["walk"][0], C["run"][0]]:
		if _ap.has_animation(n):
			_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for k in C["atk"]:
		if _ap.has_animation(C["atk"][k][0]):
			_ap.get_animation(C["atk"][k][0]).loop_mode = Animation.LOOP_NONE
	for n in [C.get("aim", ""), C.get("hit", "")]:
		if _ap.has_animation(n):
			_ap.get_animation(n).loop_mode = Animation.LOOP_NONE
	_ap.play(_stance())
	_ap.seek(randf() * 1.5, true)
	_apply_skin()
	_setup_flash()
	match C["weapon"]:
		"club": _attach_club()
		"sword", "great": _attach_blade(C["weapon"])
	_setup_combat_pack()
	# Кончик хвоста волка — оттуда вылетают шипы
	if C.has("tail"):
		var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
		var b := sk.find_bone(C["tail"])
		if b >= 0:
			var att := BoneAttachment3D.new()
			sk.add_child(att)
			att.bone_name = C["tail"]
			att.bone_idx = b
			_tail_tip = Node3D.new()
			att.add_child(_tail_tip)
			_tail_tip.position = Vector3(0, 0.3, 0)

## Живой хвост: кости хвоста качаются по инерции поверх анимации (SpringBoneSimulator3D)
func _add_spring() -> void:
	if not C.has("spring") or not ClassDB.class_exists("SpringBoneSimulator3D"):
		return
	var sks := _char.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	if sk.find_bone(C["spring"][0]) < 0 or sk.find_bone(C["spring"][1]) < 0:
		return
	var sb := SpringBoneSimulator3D.new()
	sb.name = "TailSpring"
	sk.add_child(sb)
	sb.set_setting_count(1)
	sb.set_root_bone_name(0, C["spring"][0])
	sb.set_end_bone_name(0, C["spring"][1])
	sb.set_extend_end_bone(0, true)
	sb.set_end_bone_length(0, 0.25)
	sb.set_stiffness(0, 1.6)
	sb.set_drag(0, 0.35)
	sb.set_gravity(0, 0.3)
	sb.set_radius(0, 0.02)

func _stance() -> String:
	return C.get("stance", "Combat_Stance")

## Раскраска модели (models/skins/<имя>_base_color.jpg) и оттенок стража этажа
func _apply_skin() -> void:
	var skin: String = C["skin"]
	var base: String = SKIN_DIR + skin + "_base_color.jpg"
	var nrm: String = SKIN_DIR + skin + "_normal.jpg"
	for m in _char.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var src := mi.get_active_material(si)
			if not (src is StandardMaterial3D):
				continue
			var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			if skin != "" and ResourceLoader.exists(base):
				mat.albedo_texture = load(base)
				if ResourceLoader.exists(nrm):
					mat.normal_enabled = true
					mat.normal_texture = load(nrm)
				mat.metallic = 0.0
				mat.roughness = 0.8
			if T.has("tint") and not mat.emission_enabled:
				var tint := WorldGen.hex(T["tint"])
				mat.albedo_color = mat.albedo_color * (tint.lerp(Color.WHITE, 0.35) * 1.25 if (skin != "" or mat.albedo_texture != null) else tint)
			Mats.toon(mat)
			mi.set_surface_override_material(si, mat)

## Белая вспышка при попадании — полупрозрачный слой поверх модели
func _setup_flash() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	for m in _char.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _flash_mat
		m.visibility_range_end = 130.0

func _hand_attachment() -> Array:
	var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
	var hand := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("RightHand"):
			hand = i
	if hand < 0:
		return []
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = sk.get_bone_name(hand)
	att.bone_idx = hand
	var idx := _finger(sk, hand, "RightHandIndex1")
	var pinky := _finger(sk, hand, "RightHandPinky1")
	if sk.find_bone(sk.get_bone_name(hand).replace("RightHand", "RightHandIndex1")) < 0:
		# Модель без пальцев: кисть — до концевой кости, большой палец в T-позе смотрит вперёд (+Z)
		var tip := Vector3(0, 0.1, 0)
		for i in sk.get_bone_count():
			if sk.get_bone_parent(i) == hand:
				tip = sk.get_bone_rest(i).origin
		var thumb := (sk.get_bone_global_rest(hand).basis.inverse() * Vector3(0, 0, 1)).normalized()
		idx = tip + thumb * 0.04
		pinky = tip - thumb * 0.04
	var fingers := ((idx + pinky) / 2.0).normalized()
	var dir := idx - pinky
	dir = (dir - fingers * dir.dot(fingers)).normalized()
	var flat := fingers.cross(dir).normalized()
	var grip := fingers * ((idx + pinky) / 2.0).length() * 0.7 - flat * 0.02
	return [att, fingers, dir, flat, grip]

## Меч (скелеты, кобольды): клинок из sao_gear, рукоять в кулаке, клинок над большим пальцем
func _attach_blade(kind: String) -> void:
	var h := _hand_attachment()
	if h.is_empty():
		return
	var b := SaoGear.blade(kind)
	SaoGear.paint_blade(b, Color("#b8c0c8") if model != "skeleton_king" else Color("#d8d0ff"), Color("#4a4048"), Color("#2a1e16"), Color.BLACK, 0.0)
	h[0].add_child(b)
	b.transform = Transform3D(Basis(h[1], h[2], h[3]), h[4] + h[2] * 0.05)
	b.scale = Vector3.ONE / C["scale"]

## Дубина гоблина: рукоять поперёк ладони, толстый конец выходит над большим пальцем
func _attach_club() -> void:
	var h := _hand_attachment()
	if h.is_empty():
		return
	var club := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.045
	cm.height = 0.85
	cm.radial_segments = 7
	club.mesh = cm
	club.material_override = Mats.lp(0x5a3a1c, 0.95, 0.0, -1, 0.0, 0.45, 3.0)
	h[0].add_child(club)
	club.transform = Transform3D(Basis(h[1], h[2], h[3]), h[4] + h[2] * 0.32)
	for k in 3:   # сучки-шипы на толстом конце
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.03
		sm.height = 0.1
		sm.radial_segments = 4
		spike.mesh = sm
		spike.material_override = Mats.lp(0x3a2412)
		club.add_child(spike)
		var a := k * TAU / 3.0
		spike.position = Vector3(cos(a) * 0.11, 0.3, sin(a) * 0.11)
		spike.rotation = Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2)

func _finger(sk: Skeleton3D, parent: int, suffix: String) -> Vector3:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return sk.get_bone_global_rest(parent).affine_inverse() * sk.get_bone_global_rest(i).origin
	return Vector3.UP * 0.1

# ---------- Боевой модуль (addons/combat_pack): блок оружием у мобов-гуманоидов
## Мобы с оружием на скелете Mixamo (гоблин, кобольд, голем, скелет) иногда принимают удар героя
## спереди на оружие: блок модуля — подъём, удержание, отдача от удара, опускание. Урон в блок −65%.
const BLOCK_CHANCE := 0.25
const BLOCK_REDUCE := 0.35     # доля урона, которая проходит сквозь блок
const BLOCK_HOLD := 0.9
var combat: AdventureCombatController
var _block_t := -1.0
static var _built := {}         # модель → клипы модуля уже собраны (библиотека клипов у модели общая)

func _setup_combat_pack() -> void:
	if not (C.get("glb", "") in [GOBLIN_MODEL, SKELETON_MODEL]) or C.get("weapon", "") == "":
		return
	var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
	if not _built.has(C["glb"]):
		var b := AdventureAnimationBuilder.new()
		b.skeleton = sk
		b.animation_player = _ap
		b.base_clip = "Combat_Stance"
		# Настоящие клипы модели вместо самодельных взмахов
		b.source_clips = {"horizontal": ["Left_Slash", 0.0, 9.0], "whirlwind": ["Axe_Spin_Attack", 0.0, 9.0]}
		add_child(b)
		b.build()
		b.queue_free()
		_built[C["glb"]] = true
	combat = AdventureCombatController.new()
	combat.name = "CombatPack"
	combat.animation_player = _ap
	add_child(combat)

func _try_block(dmg: int, dir: Vector3) -> int:
	if combat == null or T.get("boss", false) or not (st in ["chase", "idle", "return"]) or _dodge_t >= 0.0:
		return dmg
	if _block_t >= 0.0:
		combat.receive_block_hit()
		Fx.text("Блок", global_position + Vector3(0, T["bar"] - 1.6, 0), Color("#a8c8ff"))
		return maxi(1, roundi(dmg * BLOCK_REDUCE))
	var from := Vector3(-dir.x, 0, -dir.z)
	if from.length() < 0.01 or Vector3(sin(facing), 0, cos(facing)).dot(from.normalized()) < 0.4 or randf() > BLOCK_CHANCE:
		return dmg
	_block_t = 0.0
	combat.start_block()
	combat.receive_block_hit()
	Fx.text("Блок", global_position + Vector3(0, T["bar"] - 1.6, 0), Color("#a8c8ff"))
	return maxi(1, roundi(dmg * BLOCK_REDUCE))

func _block_update(dt: float) -> void:
	_block_t += dt
	if _block_t >= 0.2 and _block_t - dt < 0.2:
		combat.hold_block()
	if _block_t >= BLOCK_HOLD and combat.blocking:
		combat.stop_block()
	if _block_t >= BLOCK_HOLD + 0.2:
		_block_t = -1.0

## Монстры вдали «спят» — вместе с ними замирает и анимация
func set_active(on: bool) -> void:
	set_physics_process(on)
	if _ap and on != _anim_on:
		_anim_on = on
		_ap.active = on

## Анимация моба на модели: стойка, шаг/бег по скорости, удар (момент удара клипа совпадает
## с концом замаха), отскок/кувырок, реакция на удар (оглушение), прыжок-удар кролика
func _animate_char() -> void:
	if _block_t >= 0.0 and combat:
		_ap.speed_scale = 1.0
		return   # блок ведёт боевой модуль (combat_pack): начало → удержание → удар в блок → конец
	var want := _stance()
	var speed := 1.0
	if st != "windup" and st != "recover" and st != "leap":
		_swing = false
	if (_hop_t >= 0.0 and _hop_t < 0.5) or _dodge_t >= 0.0:
		var dn := "Roll_Dodge_2" if model == "rabbit" and _dodge_t >= 0.0 else "Stand_Dodge"
		if _ap.current_animation != dn:
			_ap.play(dn, 0.08)
			_ap.seek(0.0, true)
		_ap.speed_scale = 2.0
		return
	var hit_anim: String = C.get("hit", "Hit_Reaction")
	if st == "aim" and _ap.has_animation(C.get("aim", "")):
		if _ap.current_animation != C["aim"]:
			_ap.play(C["aim"], 0.1)
			_ap.seek(0.0, true)
		_ap.speed_scale = _ap.get_animation(C["aim"]).length / maxf(0.2, _special().get("aim", 0.6))
		return
	if st == "stun" and _ap.has_animation(hit_anim):
		if _ap.current_animation != hit_anim:
			_ap.play(hit_anim, 0.08)
			_ap.seek(0.0, true)
		_ap.speed_scale = 1.4
		return
	if st == "leap" and _ap.has_animation("Flying_Fist_Kick"):
		if _ap.current_animation != "Flying_Fist_Kick":
			_ap.play("Flying_Fist_Kick", 0.08)
			_ap.seek(0.3, true)
		_ap.speed_scale = 1.3
		return
	var atk: Array = C["atk"].get(_atk, C["atk"].values()[0])
	if (st == "windup" or (st == "recover" and _t < 0.6)) and _ap.has_animation(atk[0]):
		var hit: float = atk[1]
		var start := maxf(0.0, hit - 0.45)
		if st == "windup" and not _swing:
			_swing = true
			_ap.play(atk[0], 0.1)
			_ap.seek(start, true)
		_ap.speed_scale = (hit - start) / maxf(0.12, _wind_len) if st == "windup" else 1.0
		return
	if _moving:
		# Темп шага по длине шага клипа — ноги не скользят
		if _speed_now > 1.4:
			want = C["run"][0]
			speed = _speed_now / C["run"][1]
		else:
			want = C["walk"][0]
			speed = maxf(0.3, _speed_now / C["walk"][1])
	if _ap.current_animation != want:
		_ap.play(want)
	_ap.speed_scale = speed

# ---------- Модели
func _mat(color: int, rough := 0.8, emit := -1, energy := 0.0) -> ShaderMaterial:
	var m: ShaderMaterial = Mats.lp(color, rough, 0.0, emit, energy).duplicate()
	# Без свечения параметр равен null, а null в meta удаляет запись — храним чёрный цвет и 0
	var em = m.get_shader_parameter("emission")
	var en = m.get_shader_parameter("emission_energy")
	m.set_meta("emit", em if em is Color else Color.BLACK)
	m.set_meta("energy", float(en) if en != null else 0.0)
	_mats.append(m)
	return m

func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _blob(parent: Node3D, r: float, m: Material, pos: Vector3, segs := 8, rings := 4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_humanoid(sc: float, skin_c: int, cloth_c: int, dark_c: int, eye_c: int, glow: float, bw: float, limb: float, ears: bool, ribs: bool, weapon: String) -> void:
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * sc
	_model.add_child(inner)
	var skin := _mat(skin_c)
	var cloth := _mat(cloth_c)
	var dark := _mat(dark_c)
	_box(inner, Vector3(bw, 0.7, 0.3), cloth, Vector3(0, 1.22, 0))
	if ribs:
		for k in 3:
			_box(inner, Vector3(bw + 0.02, 0.05, 0.31), dark, Vector3(0, 1.08 + k * 0.17, 0))
	var head := Node3D.new()
	head.position.y = 1.82
	inner.add_child(head)
	_box(head, Vector3(0.42, 0.4, 0.4), skin, Vector3.ZERO)
	var eye := _mat(eye_c, 0.5, eye_c, glow)
	_box(head, Vector3(0.09, 0.07, 0.02), eye, Vector3(-0.1, 0.03, 0.205))
	_box(head, Vector3(0.09, 0.07, 0.02), eye, Vector3(0.1, 0.03, 0.205))
	if ears:
		for sx in [-1.0, 1.0]:
			var ear := _box(head, Vector3(0.2, 0.1, 0.06), skin, Vector3(sx * 0.28, 0.08, 0))
			ear.rotation.z = sx * 0.5
	if ribs:
		_box(head, Vector3(0.3, 0.06, 0.02), dark, Vector3(0, -0.12, 0.205))
	for sx in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(0.15 * sx, 0.88, 0)
		inner.add_child(lp)
		_box(lp, Vector3(limb, 0.62, limb), dark, Vector3(0, -0.32, 0))
		_legs.append(lp)
		var ap := Node3D.new()
		ap.position = Vector3((bw / 2.0 + 0.1) * sx, 1.52, 0)
		inner.add_child(ap)
		_box(ap, Vector3(limb * 0.9, 0.62, limb * 0.9), skin if ribs else cloth, Vector3(0, -0.28, 0))
		_box(ap, Vector3(limb * 0.9, 0.16, limb * 0.9), skin, Vector3(0, -0.65, 0))
		_arms.append(ap)
	var w := Node3D.new()
	w.position = Vector3(0, -0.66, 0.04)
	w.rotation.x = PI / 2
	_arms[0].add_child(w)
	if weapon == "club":
		var club := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.11; cm.bottom_radius = 0.05; cm.height = 0.9; cm.radial_segments = 6
		club.mesh = cm
		club.material_override = _mat(0x5a3a1c)
		club.position.y = 0.4
		w.add_child(club)
	else:
		_box(w, Vector3(0.07, 0.85, 0.03), _mat(0x8a7a68, 0.5), Vector3(0, 0.5, 0))
		_box(w, Vector3(0.26, 0.06, 0.07), dark, Vector3(0, 0.08, 0))

func _build_spider() -> void:
	_body = Node3D.new()
	_model.add_child(_body)
	var shell := _mat(0x3a2a4a)
	var leg_m := _mat(0x2a1f36)
	var abd := _blob(_body, 0.5, shell, Vector3(0, 0.7, -0.45), 6, 3)
	abd.scale = Vector3(1, 0.75, 1.2)
	_blob(_body, 0.32, shell, Vector3(0, 0.6, 0.15), 6, 3)
	var eye := _mat(0xff3020, 0.5, 0xff2010, 1.5)
	for p in [[-0.1, 0.7], [0.1, 0.7], [-0.17, 0.63], [0.17, 0.63]]:
		_box(_body, Vector3(0.06, 0.06, 0.04), eye, Vector3(p[0], p[1], 0.44))
	for sx in [-1.0, 1.0]:
		for k in 4:
			var pv := Node3D.new()
			pv.position = Vector3(sx * 0.2, 0.62, 0.25 - k * 0.17)
			_body.add_child(pv)
			var holder := Node3D.new()
			holder.rotation.y = sx * (k - 1.5) * 0.4
			pv.add_child(holder)
			var up := _box(holder, Vector3(0.6, 0.07, 0.07), leg_m, Vector3(sx * 0.28, 0.14, 0))
			up.rotation.z = sx * 0.5
			var low := _box(holder, Vector3(0.07, 0.75, 0.07), leg_m, Vector3(sx * 0.62, -0.12, 0))
			low.rotation.z = sx * -0.3
			_legs.append([pv, k * 1.6 + (PI if sx > 0 else 0.0)])

## Кролик переезжает: новый «дом» в 20–60 м, на суше и вне города
func _roam() -> void:
	for i in 8:
		var a := randf() * TAU
		var d := randf_range(20.0, 60.0)
		var p := home + Vector3(cos(a) * d, 0, sin(a) * d)
		var lim := WorldGen.HALF - 40.0
		if absf(p.x) > lim or absf(p.z) > lim or WorldGen.town_dist(p.x, p.z) < 50.0:
			continue
		var g := WorldGen.ground_at(p.x, p.z)
		if g < 1.5 or g > 30.0 or WorldGen.normal_y_at(p.x, p.z) < 0.8:
			continue
		home = Vector3(p.x, g, p.z)
		return

func _build_rabbit() -> void:
	_body = Node3D.new()
	_model.add_child(_body)
	var fur_c: int = [0xd8d0c4, 0x9a7a5a, 0x8a8a8a][randi() % 3]
	var fur := _mat(fur_c)
	var belly := _mat(0xf2ece0)
	var claw := _mat(0xf4f4f0, 0.3)
	var torso := _blob(_body, 0.45, fur, Vector3(0, 0.75, -0.05), 7, 4)
	torso.scale = Vector3(0.9, 1.0, 1.15)
	var bl := _blob(_body, 0.3, belly, Vector3(0, 0.72, 0.33), 6, 3)
	bl.scale = Vector3(0.9, 1.1, 0.6)
	var head := Node3D.new()
	head.position = Vector3(0, 1.28, 0.22)
	_body.add_child(head)
	_blob(head, 0.28, fur, Vector3.ZERO, 7, 4)
	# Длинные уши
	for sx in [-1.0, 1.0]:
		var ear := _box(head, Vector3(0.1, 0.62, 0.05), fur, Vector3(sx * 0.12, 0.48, -0.04))
		ear.rotation = Vector3(-0.15, 0, -sx * 0.18)
		var inner_ear := _box(head, Vector3(0.05, 0.45, 0.02), _mat(0xe8a0a8), Vector3(sx * 0.12, 0.46, 0.006))
		inner_ear.rotation = Vector3(-0.15, 0, -sx * 0.18)
	var eye := _mat(0xd02020, 0.4, 0xff2020, 0.8)
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.06, 0.07, 0.04), eye, Vector3(sx * 0.12, 0.05, 0.285))
	_box(head, Vector3(0.08, 0.06, 0.05), _mat(0xe88aa0), Vector3(0, -0.04, 0.305))
	# Мощные задние лапы
	for sx in [-1.0, 1.0]:
		var hl := Node3D.new()
		hl.position = Vector3(sx * 0.28, 0.55, -0.2)
		_body.add_child(hl)
		var thigh := _blob(hl, 0.24, fur, Vector3(0, -0.12, 0), 6, 3)
		thigh.scale = Vector3(0.8, 1.0, 1.3)
		_box(hl, Vector3(0.16, 0.08, 0.42), fur, Vector3(0, -0.5, 0.12))
		_legs.append(hl)
	# Передние лапы с длинными острыми когтями
	for sx in [-1.0, 1.0]:
		var ap := Node3D.new()
		ap.position = Vector3(sx * 0.3, 0.98, 0.25)
		_body.add_child(ap)
		_box(ap, Vector3(0.12, 0.42, 0.12), fur, Vector3(0, -0.2, 0))
		for k in 3:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0; cm.bottom_radius = 0.035; cm.height = 0.42; cm.radial_segments = 4
			c.mesh = cm
			c.material_override = claw
			c.position = Vector3((k - 1) * 0.045, -0.48, 0.12)
			c.rotation.x = 0.9
			ap.add_child(c)
		_arms.append(ap)

## Шипастый волк-убийца: серая шерсть, тёмные шипы вдоль спины и на хвосте, красные глаза
func _build_wolf() -> void:
	_body = Node3D.new()
	_model.add_child(_body)
	var fur := _mat(0x6c737b)
	var fur_dark := _mat(0x40454c)
	var spike_m := _mat(0x24272d, 0.35)
	var claw := _mat(0x1e1e22, 0.3)
	var eye := _mat(0xff3020, 0.4, 0xff2010, 1.6)
	# Туловище: мощная грудь, поджарый зад
	var torso := _box(_body, Vector3(0.52, 0.5, 1.25), fur, Vector3(0, 0.95, -0.05))
	torso.rotation.x = 0.06
	_box(_body, Vector3(0.6, 0.62, 0.5), fur, Vector3(0, 1.0, 0.38))
	_box(_body, Vector3(0.42, 0.18, 0.9), fur_dark, Vector3(0, 0.72, -0.05))
	# Голова с вытянутой мордой, уши, глаза, клыки
	var head := Node3D.new()
	head.position = Vector3(0, 1.28, 0.78)
	_body.add_child(head)
	_box(head, Vector3(0.4, 0.36, 0.38), fur, Vector3(0, 0, 0))
	_box(head, Vector3(0.24, 0.2, 0.36), fur, Vector3(0, -0.07, 0.32))
	_box(head, Vector3(0.1, 0.08, 0.06), _mat(0x18181c), Vector3(0, -0.02, 0.51))
	for sx in [-1.0, 1.0]:
		var ear := _box(head, Vector3(0.1, 0.24, 0.07), fur_dark, Vector3(sx * 0.13, 0.26, -0.06))
		ear.rotation.z = -sx * 0.2
		_box(head, Vector3(0.07, 0.05, 0.03), eye, Vector3(sx * 0.11, 0.06, 0.19))
		var fang := _box(head, Vector3(0.035, 0.1, 0.035), _mat(0xf4f0e6, 0.3), Vector3(sx * 0.07, -0.2, 0.44))
		fang.rotation.x = 0.2
	# Шипы вдоль спины
	for k in 7:
		var sp := _cone(_body, 0.06, 0.32 - absf(k - 3) * 0.03, spike_m, Vector3(0, 1.22, 0.45 - k * 0.17))
		sp.rotation.x = -0.35
	# Лапы: [опора, фаза шага]; правая передняя ещё и бьёт
	for leg in [[-1.0, 0.42, 0.0], [1.0, 0.42, PI], [-1.0, -0.5, PI], [1.0, -0.5, 0.0]]:
		var pv := Node3D.new()
		pv.position = Vector3(leg[0] * 0.2, 0.9, leg[1])
		_body.add_child(pv)
		_box(pv, Vector3(0.15, 0.5, 0.17), fur, Vector3(0, -0.22, 0))
		_box(pv, Vector3(0.11, 0.42, 0.12), fur_dark, Vector3(0, -0.62, 0.03))
		_box(pv, Vector3(0.15, 0.08, 0.2), fur_dark, Vector3(0, -0.86, 0.07))
		for c in 3:
			var cl := _cone(pv, 0.025, 0.12, claw, Vector3((c - 1) * 0.045, -0.88, 0.2))
			cl.rotation.x = 1.4
		_legs.append([pv, leg[2]])
	_arms = [_legs[1][0]]
	# Хвост: несколько звеньев с шипами; кончик — откуда вылетают шипы
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.05, -0.68)
	_tail.rotation.x = -0.45
	_body.add_child(_tail)
	var seg_parent: Node3D = _tail
	for k in 4:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0, -0.0 if k == 0 else -0.22)
		seg.rotation.x = 0.12
		seg_parent.add_child(seg)
		_box(seg, Vector3(0.16 - k * 0.025, 0.16 - k * 0.025, 0.24), fur, Vector3(0, 0, -0.11))
		for sx in [-1.0, 1.0]:
			var ts := _cone(seg, 0.035, 0.2, spike_m, Vector3(sx * 0.08, 0.05, -0.1))
			ts.rotation = Vector3(-0.4, 0, -sx * 0.9)
		seg_parent = seg
	var tip := _cone(seg_parent, 0.07, 0.36, spike_m, Vector3(0, 0, -0.38))
	tip.rotation.x = -PI / 2.0
	_tail_tip = Node3D.new()
	_tail_tip.position = Vector3(0, 0, -0.55)
	seg_parent.add_child(_tail_tip)

func _cone(parent: Node3D, r: float, h: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 4
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _special() -> Dictionary:
	for k in ["spikes", "slam", "spit"]:
		if T.has(k):
			return T[k]
	return {}

## Удар о землю: всё в радиусе получает урон
func _slam(dist: float) -> void:
	var sl: Dictionary = T["slam"]
	Fx.ring(global_position + Vector3(0, 0.15, 0), Color(0.85, 0.75, 0.6, 0.9), sl["radius"], 0.45)
	if dist < sl["radius"] and absf(hero.global_position.y - global_position.y) < 2.0:
		hero.take_damage(sl["dmg"], global_position, self, "slam")

## Корона босса
func _add_crown(y: float, at := Vector3.ZERO) -> void:
	var gold := _mat(0xe8b830, 0.35, 0xb08010, 0.6)
	var crown := Node3D.new()
	crown.position = Vector3(at.x, y, at.z)
	_model.add_child(crown)
	_box(crown, Vector3(0.36, 0.08, 0.36), gold, Vector3.ZERO)
	for k in 6:
		var a := TAU * k / 6.0
		var tooth := _cone(crown, 0.05, 0.16, gold, Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15))
		tooth.rotation.y = a
	_box(crown, Vector3(0.07, 0.07, 0.07), _mat(0xe02040, 0.3, 0xff2050, 1.0), Vector3(0, 0.02, 0.19))

## Залп шипов из кончика хвоста — в грудь героя, с небольшим разбросом
func _fire_spikes() -> void:
	if not Fx.root:
		return
	var spit := T.has("spit")
	if not spit and not _tail_tip:
		return
	var sp: Dictionary = T["spit"] if spit else T["spikes"]
	var from: Vector3 = _tail_tip.global_position if not spit else global_position + Vector3(sin(facing), 0, cos(facing)) * 1.6 + Vector3(0, 1.3, 0)
	var target: Vector3 = hero.global_position + Vector3(0, 1.0, 0)
	var dir := (target - from).normalized()
	for i in int(sp["count"]):
		var s: Node3D = preload("res://scripts/spike.gd").new()
		var spread: float = (i - (float(sp["count"]) - 1.0) / 2.0) * 0.07
		s.velocity = dir.rotated(Vector3.UP, spread) * sp["speed"]
		s.hero = hero
		s.dmg = T["dmg"]
		if spit:
			s.poison = true
		Fx.root.add_child(s)
		s.global_position = from

## Кобольд-оборотень: собачья голова, шерсть, ноги коленями назад, чешуйчатый нагрудник, меч и щит
func _build_kobold() -> void:
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * 0.95
	_model.add_child(inner)
	var fur_c: int = [0x6a5038, 0x5a5a5e, 0x7a5a3a][randi() % 3]
	var fur := _mat(fur_c)
	var fur_dark := _mat(Color(WorldGen.hex(fur_c)).darkened(0.35).to_rgba32() >> 8)
	var fur_light := _mat(Color(WorldGen.hex(fur_c)).lightened(0.25).to_rgba32() >> 8)
	var steel := _mat(0x9aa2ac, 0.35)
	steel.set_shader_parameter("metallic", 0.6)
	var steel_dark := _mat(0x6e767e, 0.4)
	steel_dark.set_shader_parameter("metallic", 0.6)
	var leather := _mat(0x4a3220)
	# Сутулый торс: широкая грудь, наклон вперёд
	var torso := Node3D.new()
	torso.position.y = 0.95
	torso.rotation.x = 0.22
	inner.add_child(torso)
	_box(torso, Vector3(0.66, 0.8, 0.42), fur, Vector3(0, 0.38, 0))
	_box(torso, Vector3(0.5, 0.3, 0.36), fur_dark, Vector3(0, -0.05, 0))
	# Чешуйчатый нагрудник: ряды накладывающихся пластинок
	for row in 5:
		for col in 5:
			var off := 0.055 if row % 2 == 1 else 0.0
			var x := -0.24 + col * 0.12 + off
			if absf(x) > 0.3:
				continue
			var sc := _box(torso, Vector3(0.12, 0.11, 0.03), steel if (row + col) % 2 == 0 else steel_dark, Vector3(x, 0.66 - row * 0.1, 0.225))
			sc.rotation.x = -0.35
	_box(torso, Vector3(0.62, 0.5, 0.04), steel_dark, Vector3(0, 0.45, -0.22))  # спина
	_box(torso, Vector3(0.68, 0.08, 0.46), leather, Vector3(0, 0.1, 0))       # пояс
	# Грива шерсти на загривке и плечах
	for k in 7:
		var a := -0.9 + k * 0.3
		var tuft := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0; tm.bottom_radius = 0.09; tm.height = 0.3; tm.radial_segments = 4
		tuft.mesh = tm
		tuft.material_override = fur_light if k % 2 == 0 else fur
		tuft.position = Vector3(sin(a) * 0.3, 0.82, -0.06 - cos(a) * 0.12)
		tuft.rotation = Vector3(-0.6, 0, -sin(a) * 0.7)
		torso.add_child(tuft)
	# Собачья голова: череп, вытянутая морда, нос, острые уши, светящиеся глаза
	var head := Node3D.new()
	head.position = Vector3(0, 0.98, 0.12)
	torso.add_child(head)
	_box(head, Vector3(0.36, 0.34, 0.36), fur, Vector3.ZERO)
	_box(head, Vector3(0.22, 0.18, 0.3), fur_light, Vector3(0, -0.06, 0.3))   # морда
	_box(head, Vector3(0.18, 0.06, 0.26), fur_dark, Vector3(0, -0.17, 0.27))  # нижняя челюсть
	_box(head, Vector3(0.09, 0.07, 0.06), _mat(0x141414, 0.3), Vector3(0, -0.01, 0.46))  # нос
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.025, 0.06, 0.025), _mat(0xf2ead8), Vector3(sx * 0.06, -0.15, 0.4))  # клыки
		var ear := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0; em.bottom_radius = 0.09; em.height = 0.3; em.radial_segments = 4
		ear.mesh = em
		ear.material_override = fur_dark
		ear.position = Vector3(sx * 0.12, 0.28, -0.06)
		ear.rotation = Vector3(-0.2, 0, -sx * 0.25)
		head.add_child(ear)
	var eye := _mat(0xffc020, 0.4, 0xffa000, 1.4)
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.07, 0.04, 0.02), eye, Vector3(sx * 0.1, 0.05, 0.185))
	# Хвост
	var tail := _box(inner, Vector3(0.12, 0.12, 0.55), fur_dark, Vector3(0, 0.85, -0.42))
	tail.rotation.x = 0.7
	# Ноги оборотня: бедро вперёд, голень назад, лапа на пальцах
	for sx in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(0.17 * sx, 0.95, 0)
		inner.add_child(lp)
		var thigh := _box(lp, Vector3(0.2, 0.42, 0.24), fur, Vector3(0, -0.17, 0.08))
		thigh.rotation.x = -0.45
		var shin := _box(lp, Vector3(0.14, 0.42, 0.14), fur_dark, Vector3(0, -0.55, 0.1))
		shin.rotation.x = 0.55
		_box(lp, Vector3(0.16, 0.09, 0.26), fur_dark, Vector3(0, -0.88, 0.12))  # лапа
		_legs.append(lp)
		# Руки с когтистыми ладонями, на предплечьях — поручи
		var ap := Node3D.new()
		ap.position = Vector3(0.42 * sx, 1.62, 0.18)
		inner.add_child(ap)
		_box(ap, Vector3(0.17, 0.62, 0.17), fur, Vector3(0, -0.28, 0))
		_box(ap, Vector3(0.2, 0.22, 0.2), steel, Vector3(0, -0.45, 0))
		_box(ap, Vector3(0.16, 0.14, 0.18), fur_dark, Vector3(0, -0.64, 0))
		_arms.append(ap)
	# Меч
	var w := Node3D.new()
	w.position = Vector3(0, -0.66, 0.04)
	w.rotation.x = PI / 2
	_arms[0].add_child(w)
	_box(w, Vector3(0.08, 1.0, 0.03), steel, Vector3(0, 0.58, 0))
	_box(w, Vector3(0.3, 0.07, 0.08), leather, Vector3(0, 0.08, 0))
	# Небольшой щит на левой руке
	var shield := _box(_arms[1], Vector3(0.06, 0.5, 0.42), _mat(0x6a4a2a), Vector3(-0.1, -0.45, 0.1))
	_box(shield, Vector3(0.08, 0.2, 0.2), steel, Vector3(0, 0, 0))

# ---------- Бой
## Оглушение: монстр стоит и не бьёт; если отбит удар — ещё и получает двойной урон
var _stun_len := 0.0
var _vuln_t := 0.0
func stun(t: float, vulnerable := false) -> void:
	if dead:
		return
	st = "stun"
	_t = 0.0
	_stun_len = t
	_extra_hits = []
	if vulnerable:
		_vuln_t = t + 0.4
	if hero and hero.ATTACK_RINGS:
		Fx.ring(global_position + Vector3(0, T["bar"] - 0.4, 0), Color("#ffe060"), 0.6, 0.5)

var _tilt := Vector2.ZERO    # наклон от удара: (вокруг X, вокруг Z) в системе монстра

func hit(dmg: int, dir: Vector3, crit := false) -> void:
	if dead:
		return
	# Отшатнуться от удара: верх уходит по направлению удара; крупных качает меньше
	var ld := Vector3(dir.x, 0, dir.z).rotated(Vector3.UP, -facing)
	if ld.length() > 0.01:
		ld = ld.normalized() * (0.32 if crit else 0.22) / float(T.get("scale", 1.0))
		_tilt += Vector2(ld.z, -ld.x)
	if _vuln_t > 0.0:
		dmg *= 2   # после отбитого удара — уязвим
	dmg = _try_block(dmg, dir)
	hp -= dmg
	_flash = 1.0
	_kb = dir * 9.0
	Fx.text(str(dmg) + ("!" if crit else ""), global_position + Vector3(0, T["bar"] - 2.0, 0), Color("#ff9a3a") if crit else Color("#fff2b0"), crit)
	if hp <= 0.0:
		_die()
		return
	if st == "windup":
		st = "recover"
		_t = _rec_len - 0.45
		_extra_hits = []
	elif st == "idle" or st == "return":
		st = "chase"
	if model == "rabbit" and _char and _dodge_t < 0.0 and randf() < 0.3 and st != "stun":
		_dodge_t = 0.0

## Замах: у кролика — следующая атака по очереди (джеб, прямой, крюк, комбо)
## Вид удара: у гоблина — сверху / сбоку / обычный, у кобольда — мечом / щитом / боковой
var _atk := "slash"
var _hop_plan := false        # после удара отскочить назад
var _hop_t := -1.0
const HOP_TIME := 0.3
const HOP_SPEED := 6.0

func _start_attack() -> void:
	st = "windup"
	_t = 0.0
	_wind_len = T["windup"]
	_rec_len = T["cd"]
	_extra_hits = []
	_atk = "slash"
	_hop_plan = false
	_swing = false   # новый удар — анимация с начала, даже если прошлый ещё не закончился
	if _char:
		var kinds: Array = C["atk"].keys()
		_atk = kinds[randi() % kinds.size()]
	elif model == "kobold":
		_atk = ["slash", "bash", "sweep"][randi() % 3]
	if model in ["goblin", "kobold"] and not T.get("boss", false):
		_hop_plan = randf() < 0.35
	if _atk == "overhead":
		_wind_len *= 1.3   # тяжёлый удар — замах дольше
	if model == "rabbit" and _char:
		_wind_len = maxf(_wind_len, 0.35)   # кролик: удар кулаком с подготовкой из клипа

func knock(mult: float) -> void:
	_kb *= mult

## Гибель как в игре про мечника: монстр вспыхивает белым и рассыпается на светящиеся осколки
const SHATTER_AT := 0.14
const SHATTER_COLOR := Color(0.55, 0.85, 1.0, 1.0)
var _shattered := false

func _die() -> void:
	dead = true
	_dead_t = 0.0
	_shattered = false
	_set_flash(1.0)
	if _ap:
		_ap.speed_scale = 0.0   # замирает в момент удара
	collision_layer = 0
	collision_mask = 1
	Game.kills += 1
	Game.give_xp(roundi(Game.enemy_xp(type) * (1.0 + 0.3 * (level - 1))), global_position)
	get_parent().on_enemy_killed(self)
	if T.get("boss", false):
		get_parent().on_boss_killed(self)

func revive() -> void:
	dead = false
	_shattered = false
	_set_flash(0.0)
	hp = T["hp"]
	st = "idle"
	_kb = Vector3.ZERO
	global_position = home + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	visible = true
	_model.scale = Vector3.ONE
	_model.rotation = Vector3(0, facing, 0)

func reset_home() -> void:
	if dead:
		return
	hp = T["hp"]
	st = "idle"
	_kb = Vector3.ZERO
	global_position = home + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO

# ---------- Поведение
func _physics_process(dt: float) -> void:
	if dead:
		_dead_t += dt
		if not _shattered and _dead_t >= SHATTER_AT:
			_shattered = true
			visible = false
			var sc: float = T.get("scale", 1.0)
			if Fx.root:
				Shatter.spawn(Fx.root, global_position, T["bar"] * 0.85, T["r"] * 2.2 * sqrt(sc), SHATTER_COLOR, 70 if T.get("boss", false) else 44)
		if not in_dungeon and _dead_t > 30.0 and hero.global_position.distance_to(home) > 40.0:
			revive()
		return
	var to_hero: Vector3 = hero.global_position - global_position
	to_hero.y = 0
	var dist := maxf(0.01, to_hero.length())
	var can_see: bool = not hero.dead and not hero.busy and absf(hero.global_position.y - global_position.y) < 4.0
	if guard_room and not guard_room.in_room(hero.global_position):
		can_see = false   # страж этажа не выходит из своей комнаты
	var to_home := home - global_position
	to_home.y = 0
	var home_d := to_home.length()
	var mv := Vector3.ZERO
	var sp := 0.0
	_t += dt
	match st:
		"idle":
			_wander_t -= dt
			if _wander_t <= 0.0:
				_wander_t = randf_range(2.0, 6.0)
				if T.get("roam", false) and randf() < 0.35:
					_roam()
				_wander = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)) if randf() < 0.6 else null
			if _wander != null:
				var w: Vector3 = _wander - global_position
				w.y = 0
				if w.length() > 0.6:
					mv = w.normalized()
					sp = T.get("walk", T["speed"] * 0.35)
				else:
					_wander = null
			if can_see and dist < T["aggro"]:
				st = "chase"
		"chase":
			# Монстр гонится долго: сдаётся, только если герой очень далеко или он сам ушёл далеко от дома
			if not can_see or dist > T["aggro"] * 3.5 or home_d > 90.0:
				st = "return"
			elif dist < T["reach"]:
				_start_attack()
			elif T.has("spikes") and _spike_cd <= 0.0 and dist > T["spikes"]["near"] and dist < T["spikes"]["far"]:
				# Волк поднимает хвост и целится в героя
				st = "aim"
				_t = 0.0
			elif T.has("slam") and _spike_cd <= 0.0 and dist < T["slam"]["radius"] * 0.8:
				# Король-скелет поднимает меч для удара о землю — красное кольцо предупреждает
				st = "aim"
				_t = 0.0
				Fx.ring(global_position + Vector3(0, 0.15, 0), Color(1, 0.25, 0.15, 0.8), T["slam"]["radius"] - 1.0, T["slam"]["aim"])
			elif T.has("spit") and _spike_cd <= 0.0 and dist > T["spit"]["near"] and dist < T["spit"]["far"]:
				# Королева-паучиха встаёт на задние лапы и плюётся ядом
				st = "aim"
				_t = 0.0
			elif model == "rabbit" and _char and _leap_cd <= 0.0 and dist > 2.6 and dist < 6.5:
				# Прыжок к герою: вблизи — удар в прыжке, подальше — просто сократить расстояние
				st = "leap"
				_t = 0.0
				_leap_dir = to_hero / dist
				_leap_hit_done = false
				_leap_cd = randf_range(2.5, 4.5)
				_leap_atk = dist < 4.6
				_leap_dist = clampf(dist - (1.0 if _leap_atk else 2.2), 1.2, 4.5)
			else:
				mv = to_hero / dist
				sp = T["speed"]
		"windup":
			facing += angle_difference(facing, atan2(to_hero.x, to_hero.z)) * minf(1.0, dt * 10.0)
			if _t >= _wind_len:
				st = "recover"
				_t = 0.0
				if T.get("lunge", false):
					_kb += Vector3(sin(facing), 0, cos(facing)) * 7.0
				if can_see and dist < T["reach"] + 0.6 and absf(angle_difference(facing, atan2(to_hero.x, to_hero.z))) < 1.2:
					hero.take_damage(T["dmg"], global_position, self)
		"aim":
			facing += angle_difference(facing, atan2(to_hero.x, to_hero.z)) * minf(1.0, dt * 8.0)
			var spec: Dictionary = _special()
			if _t >= spec["aim"]:
				if T.has("slam"):
					_slam(dist)
				else:
					_fire_spikes()
				st = "recover"
				_t = 0.0
				_rec_len = 0.45 if not T.has("slam") else 0.9
				_extra_hits = []
				_spike_cd = spec["cd"]
		"leap":
			facing += angle_difference(facing, atan2(to_hero.x, to_hero.z)) * minf(1.0, dt * 6.0)
			mv = _leap_dir
			# Прыжок-удар (клип Meshy Flying Fist Kick): в воздухе с 0,28 по 0,78 с, удар на 0,8 с
			sp = _leap_dist / (LEAP_AIR[1] - LEAP_AIR[0]) if _t >= LEAP_AIR[0] and _t < LEAP_AIR[1] else 0.0
			if _leap_atk and not _leap_hit_done and _t >= LEAP_HIT:
				_leap_hit_done = true
				if can_see and dist < T["reach"] + 0.8:
					hero.take_damage(T["dmg"], global_position, self)
			if _t >= LEAP_DUR:
				if _leap_atk:
					st = "recover"
					_t = 0.0
					_rec_len = T["cd"]
					_extra_hits = []
				else:
					st = "chase"
		"stun":
			if _t >= _stun_len:
				st = "chase"
		"recover":
			if _hop_plan and _t >= 0.32:
				_hop_plan = false
				_hop_t = 0.0
			# Следующие удары комбо
			while not _extra_hits.is_empty() and _t >= _extra_hits[0]:
				_extra_hits.pop_front()
				if can_see and dist < T["reach"] + 0.6 and absf(angle_difference(facing, atan2(to_hero.x, to_hero.z))) < 1.2:
					hero.take_damage(int(T["dmg"] * 0.6), global_position, self)
			if _t >= _rec_len:
				st = "chase" if can_see and dist < T["aggro"] * 3.5 else "return"
		"return":
			if home_d < 1.5:
				st = "idle"
			else:
				mv = to_home / home_d
				sp = T["speed"] * 0.7
				hp = minf(T["hp"], hp + 10.0 * dt)
				if can_see and dist < T["aggro"] * 0.9:
					st = "chase"
	if sp > 0.0:
		facing += angle_difference(facing, atan2(mv.x, mv.z)) * minf(1.0, dt * 8.0)
	_moving = sp > 0.1
	_leap_cd -= dt
	_spike_cd -= dt
	_vuln_t -= dt
	_speed_now = lerpf(_speed_now, sp, minf(1.0, dt * 8.0))
	var hv := mv * sp
	# Не заходим в воду
	var ahead := global_position + hv.normalized() * 1.0 if sp > 0.0 else global_position
	if sp > 0.0 and not in_dungeon and not world2 and WorldGen.ground_at(ahead.x, ahead.z) < 0.4:
		hv = Vector3.ZERO
	# Отскок назад после удара
	if _hop_t >= 0.0:
		_hop_t += dt
		if _hop_t < HOP_TIME:
			hv += -Vector3(sin(facing), 0, cos(facing)) * HOP_SPEED
		elif _hop_t > 0.5:
			_hop_t = -1.0
	if _block_t >= 0.0:
		_block_update(dt)
		hv = Vector3.ZERO   # в блоке стоит на месте
	hv += _kb
	_kb *= exp(-dt * 6.0)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	_model.rotation.y = facing
	# Реакция на удар: корпус качнуло от удара, потом пружиной обратно
	_tilt = _tilt.lerp(Vector2.ZERO, minf(1.0, dt * 9.0))
	_model.rotation.x = _tilt.x
	_model.rotation.z = _tilt.y
	_animate(dt)
	# Вспышка при попадании
	if _flash > 0.0:
		_set_flash(maxf(0.0, _flash - dt * 5.0))

func _set_flash(f: float) -> void:
	_flash = f
	if _flash_mat:
		_flash_mat.albedo_color.a = f * 0.6
	for m in _mats:
		m.set_shader_parameter("emission", (m.get_meta("emit", Color.BLACK) as Color).lerp(Color.WHITE, f))
		m.set_shader_parameter("emission_energy", lerpf(float(m.get_meta("energy", 0.0)), 0.8, f))

## Удары кобольда: щитом (рука со щитом выбрасывается вперёд, корпус за ней) и боковой взмах
## мечом (рука поднята и проходит справа налево, корпус закручивается); отскок — присел и назад
func _kobold_moves(_dt: float) -> void:
	var wind := minf(1.0, _t / maxf(0.1, _wind_len))
	var after := smoothstep(0.0, 1.0, _t / 0.14)
	var twist := 0.0
	var lean := 0.0
	if _atk == "bash" and (st == "windup" or (st == "recover" and _t < 0.4)):
		if st == "windup":
			_arms[1].rotation.x = lerpf(0.0, 0.5, wind)       # щит отведён назад
			lean = -0.15 * wind
			twist = 0.35 * wind
		else:
			_arms[1].rotation.x = lerpf(0.5, -1.6, after)     # толчок щитом вперёд
			lean = lerpf(-0.15, 0.3, after)
			twist = lerpf(0.35, -0.3, after)
		_arms[0].rotation.x = -0.4
	elif _atk == "sweep" and (st == "windup" or (st == "recover" and _t < 0.4)):
		_arms[0].rotation.x = -1.5                             # рука с мечом поднята вперёд
		if st == "windup":
			_arms[0].rotation.y = lerpf(0.0, -1.3, wind)      # отведена вправо-назад
			twist = -0.5 * wind
		else:
			_arms[0].rotation.y = lerpf(-1.3, 1.4, after)     # взмах справа налево
			twist = lerpf(-0.5, 0.6, after)
	if _hop_t >= 0.0 and _hop_t < 0.5:
		var k := sin(clampf(_hop_t / 0.45, 0.0, 1.0) * PI)
		lean = 0.25 * k
		_legs[0].rotation.x = -0.6 * k
		_legs[1].rotation.x = -0.4 * k
	_model.rotation.y += twist
	_model.rotation.x += lean

## Где корона стража (до увеличения): над головой его модели
func _crown_at() -> Vector3:
	match model:
		"wolf": return Vector3(0, 1.5, 0.74)
		"spider": return Vector3(0, 0.98, 0.18)
		"kobold": return Vector3(0, 2.0, 0.3)
	return Vector3(0, 1.93, 0)

func _animate(dt: float) -> void:
	if _dodge_t >= 0.0:
		_dodge_t += dt
		if _dodge_t > 0.6:
			_dodge_t = -1.0
	if _char:
		_animate_char()
		return
	match model:
		"rabbit":
			_hop += dt * (9.0 if _moving else 2.0)
			var k := absf(sin(_hop))
			_body.position.y = k * 0.35 if _moving else 0.0
			_body.rotation.x = -0.25 * k if _moving else 0.0
			for l in _legs:
				l.rotation.x = -0.6 * k if _moving else 0.0
			var ax := 0.3 * sin(_hop) if _moving else 0.0
			if st == "windup":
				ax = -2.0 * minf(1.0, _t / T["windup"])
			elif st == "recover" and _t < 0.2:
				ax = lerpf(-2.0, 0.8, smoothstep(0.0, 1.0, _t / 0.12))
			for a in _arms:
				a.rotation.x = ax
		"wolf":
			# Рысь: диагональные пары лап вместе; лапа бьёт сверху вниз; хвост поднимается при прицеливании
			_walk += dt * (2.0 + _speed_now * 1.9)
			var amp := minf(1.0, _speed_now / 3.0) * 0.6 if _moving else 0.0
			for l in _legs:
				l[0].rotation.x = sin(_walk + l[1]) * amp
			_body.position.y = absf(sin(_walk)) * 0.05 * minf(1.0, _speed_now / 3.0)
			if st == "windup":
				_arms[0].rotation.x = -1.7 * minf(1.0, _t / T["windup"])
			elif st == "recover" and _t < 0.22 and _rec_len > 0.5:
				_arms[0].rotation.x = lerpf(-1.7, 0.7, smoothstep(0.0, 1.0, _t / 0.12))
			var tail_up := 0.0
			if st == "aim":
				tail_up = smoothstep(0.0, 1.0, _t / T["spikes"]["aim"])
			elif st == "recover" and _rec_len <= 0.5:
				tail_up = 1.0 - smoothstep(0.0, 1.0, _t / 0.45)
			_tail.rotation.x = lerpf(-0.45 + 0.15 * sin(_walk * 0.5), 2.35, tail_up)
			_body.rotation.x = 0.12 * tail_up
		"spider", "spider_queen":
			_walk += dt * (14.0 if _moving else 2.0)
			var amp := 0.35 if _moving else 0.05
			for l in _legs:
				l[0].rotation.x = sin(_walk + l[1]) * amp
			_body.rotation.x = -0.45 * minf(1.0, _t / T["windup"]) if st == "windup" else 0.0
			if st == "aim":   # королева встаёт на дыбы перед плевком
				_body.rotation.x = -0.6 * smoothstep(0.0, 1.0, _t / _special()["aim"])
		_:
			_walk += dt * _speed_now * 1.8
			var amp := minf(1.0, _speed_now / 4.0) * 0.8 if _moving else 0.0
			var sw := sin(_walk)
			_legs[0].rotation.x = sw * amp
			_legs[1].rotation.x = -sw * amp
			_arms[1].rotation.x = sw * amp * 0.7
			var ax := -sw * amp * 0.7
			if st == "windup":
				ax = -2.6 * minf(1.0, _t / (T["windup"] * 0.8))
			elif st == "recover" and _t < 0.25:
				ax = lerpf(-2.6, 0.4, smoothstep(0.0, 1.0, _t / 0.15))
			if st == "aim":   # замах обеими руками над головой
				ax = -3.0 * smoothstep(0.0, 1.0, _t / _special()["aim"])
				_arms[1].rotation.x = ax
			elif st == "recover" and T.has("slam") and _t < 0.3:
				ax = lerpf(-3.0, 0.6, smoothstep(0.0, 1.0, _t / 0.12))
				_arms[1].rotation.x = ax
			_arms[0].rotation.x = ax
			_arms[0].rotation.y = 0.0
			if model == "kobold":
				_kobold_moves(dt)

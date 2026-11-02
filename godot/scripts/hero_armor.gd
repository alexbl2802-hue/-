## Детали брони героя в духе SAO, по фигуре (scripts/armor_fit.gd):
## лёгкий нагрудник и пояс, наплечники, наручи и перчатки, поножи с наколенниками, сапоги,
## открытый шлем или обруч, плащ за спиной. Каждая деталь — свой MeshInstance3D на скелете героя.
class_name HeroArmor
extends RefCounted

## Возвращает {"parts": {имя детали: MeshInstance3D}, "fit": ArmorFit}; детали скрыты,
## цвет задаётся в paint(), тело под надетыми деталями прячет ArmorFit.masked_body()
static func build(body: MeshInstance3D) -> Dictionary:
	var f := ArmorFit.new(body)
	var out := {}
	var H := f.pos("Hips")
	var N := f.pos("Neck")
	var top := f.pos("HeadTop_End")
	var spine := ["Spine", "Spine1", "Spine2"]
	var not_limbs := ["LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "Head", "headfront",
		"LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToe", "RightToe"]
	# Торс: нагрудник от талии до ключиц, широкий пояс, юбка из пластин спереди и сзади
	out["cuirass"] = f.shell({"fit": 0.35, "a": H, "b": N, "t0": 0.2, "t1": 0.93, "bones": spine, "exclude": not_limbs, "side_max": 0.2, "keep": ["LeftHand", "RightHand", "LeftForeArm", "RightForeArm"], "rings": 16, "sectors": 36,
		"thick": 0.018, "rmax": 0.28, "flare": [0.01, 0.0], "smooth": 3}, _mat())
	out["belt"] = f.shell({"fit": 0.4, "a": H, "b": N, "t0": 0.12, "t1": 0.22, "bones": spine + ["Hips"], "exclude": not_limbs, "rings": 2, "sectors": 36,
		"thick": 0.03, "rmax": 0.3}, _mat())
	out["tassets"] = f.shell({"fit": 0.5, "a": H, "b": N, "t0": -0.32, "t1": 0.13, "bones": ["Hips", "LeftUpLeg", "RightUpLeg", "Spine"],
		"arc": [-70.0, 70.0], "rings": 5, "sectors": 14, "thick": 0.03, "rmax": 0.34, "flare": [0.05, 0.0]}, _mat())
	for side in ["Left", "Right"]:
		var sh := f.pos(side + "Arm")
		var el := f.pos(side + "ForeArm")
		var wr := f.pos(side + "Hand")
		var fing := f.pos(side + "HandMiddle1")
		var kn := f.pos(side + "Leg")
		var hip := f.pos(side + "UpLeg")
		var an := f.pos(side + "Foot")
		var toe := f.pos(side + "Toe_End")
		var up := Vector3.UP
		# Наплечник: верхняя половина плеча, края слегка отогнуты
		out["pauldron_" + side] = f.shell({"fit": 0.6, "a": sh, "b": el, "t0": -0.12, "t1": 0.42, "bones": [side + "Arm", side + "Shoulder"],
			"fwd": up, "arc": [-105.0, 105.0], "rings": 8, "sectors": 16, "thick": 0.026, "rmax": 0.14, "flare": [0.0, 0.025],
			"cap0": false}, _mat())
		# Наруч от середины предплечья до запястья и перчатка на кисти
		out["vambrace_" + side] = f.shell({"fit": 0.7, "a": el, "b": wr, "t0": 0.22, "t1": 0.97, "bones": [side + "ForeArm"],
			"rings": 8, "sectors": 18, "thick": 0.012, "rmax": 0.09, "flare": [0.0, 0.014]}, _mat())
		out["glove_" + side] = f.shell({"fit": 0.8, "a": wr, "b": fing, "t0": -0.05, "t1": 0.95, "bones": [side + "Hand"],
			"fwd": up, "rings": 5, "sectors": 14, "thick": 0.006, "rmax": 0.08}, _mat())
		# Поножи на голени, наколенник, накладка на бедро спереди
		out["greave_" + side] = f.shell({"fit": 0.7, "a": kn, "b": an, "t0": 0.08, "t1": 0.82, "bones": [side + "Leg"],
			"rings": 10, "sectors": 20, "thick": 0.014, "rmax": 0.12, "flare": [0.012, 0.0]}, _mat())
		out["knee_" + side] = f.shell({"fit": 0.7, "a": hip, "b": kn, "t0": 0.86, "t1": 1.12, "bones": [side + "UpLeg", side + "Leg"],
			"arc": [-75.0, 75.0], "rings": 4, "sectors": 10, "thick": 0.022, "rmax": 0.13}, _mat())
		out["cuisse_" + side] = f.shell({"fit": 0.6, "a": hip, "b": kn, "t0": 0.25, "t1": 0.84, "bones": [side + "UpLeg"],
			"arc": [-85.0, 85.0], "rings": 8, "sectors": 12, "thick": 0.016, "rmax": 0.16}, _mat())
		# Сапог: голенище до середины голени и ступня до носка
		out["bootleg_" + side] = f.shell({"fit": 0.75, "a": kn, "b": an, "t0": 0.45, "t1": 1.06, "bones": [side + "Leg", side + "Foot"],
			"rings": 8, "sectors": 20, "thick": 0.011, "rmax": 0.12, "flare": [0.0, 0.0]}, _mat())
		out["boot_" + side] = f.shell({"fit": 0.85, "a": an, "b": toe, "t0": -0.05, "t1": 1.04, "bones": [side + "Foot", side + "ToeBase", side + "Toe_End"],
			"fwd": up, "rings": 10, "sectors": 18, "thick": 0.009, "rmax": 0.12, "cap1": true}, _mat())
	# Шлем: закрытый (как у рыцарей Айнкрада) — купол и личина со смотровой щелью; капюшон модели
	# под ним прячется целиком. Обруч — для лёгких шлемов
	var head_b := ["Head", "HeadTop_End", "headfront"]
	out["helm"] = f.shell({"fit": 0.45, "a": N, "b": top, "t0": 0.26, "t1": 0.8, "bones": head_b, "exclude": ["Left", "Right", "Spine", "Hips"],
		"rings": 8, "sectors": 24, "thick": 0.014, "rmax": 0.2, "skin": "Head"}, _mat())
	out["helm_dome"] = f.shell({"fit": 0.45, "a": N, "b": top, "t0": 0.72, "t1": 1.1, "bones": head_b, "exclude": ["Left", "Right", "Spine", "Hips"], "rings": 6, "sectors": 28,
		"thick": 0.016, "rmax": 0.2, "skin": "Head", "cap1": true}, _mat())
	out["visor"] = f.shell({"fit": 0.45, "a": N, "b": top, "t0": 0.5, "t1": 0.58, "bones": head_b, "exclude": ["Left", "Right", "Spine", "Hips"],
		"arc": [-48.0, 48.0], "rings": 1, "sectors": 10, "thick": 0.02, "rmax": 0.2, "skin": "Head", "hide": false}, _mat())
	out["circlet"] = f.shell({"fit": 0.5, "hide": false, "a": N, "b": top, "t0": 0.66, "t1": 0.73, "bones": head_b, "exclude": ["Left", "Right", "Spine", "Hips"], "rings": 1, "sectors": 28,
		"thick": 0.02, "rmax": 0.2, "skin": "Head"}, _mat())
	# Плащ: от плеч до колен за спиной, книзу расходится
	var cape_bones := spine + ["Hips", "LeftUpLeg", "RightUpLeg", "LeftShoulder", "RightShoulder"]
	var cm := _mat()
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	out["cloak"] = f.shell({"fit": 0.55, "a": N, "b": H, "t0": -0.08, "t1": 1.95, "bones": cape_bones, "arc": [96.0, 264.0],
		"exclude": ["LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "Head"],
		"rings": 16, "sectors": 18, "thick": 0.03, "rmax": 0.4, "flare": [0.0, 0.05], "smooth": 6}, cm)
	out["cloak_collar"] = f.shell({"fit": 0.5, "a": N, "b": top, "t0": -0.15, "t1": 0.12, "bones": ["Neck", "Spine2"],
		"rings": 2, "sectors": 24, "thick": 0.03, "rmax": 0.16, "flare": [0.015, 0.03]}, cm)
	for k in out:
		out[k].visible = false
	return {"parts": out, "fit": f}

static func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.6
	return m

## Цвет и вид детали: металл блестит, кожа и ткань матовые; trim — светлая кромка (у лат)
static func paint(mi: MeshInstance3D, color: Color, metal: bool, kind := "") -> void:
	var m := mi.material_override as StandardMaterial3D
	m.albedo_color = color
	m.metallic = 0.45 if metal else 0.0
	m.roughness = 0.38 if metal else (0.9 if kind == "cloth" else 0.7)
	m.metallic_specular = 0.6 if metal else 0.3
	if kind == "chain":
		m.albedo_texture = Mats.noise_texture("rock")
		m.uv1_scale = Vector3(3, 3, 3)
		m.roughness = 0.45
	else:
		m.albedo_texture = null

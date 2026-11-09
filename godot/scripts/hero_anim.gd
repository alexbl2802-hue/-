## Дерево анимаций героя (AnimationTree): ходьба и бег смешиваются по скорости,
## действия (удар, вихрь, рывок, стойки) плавно накладываются поверх.
## На бегу действие берёт только верх тела — ноги продолжают бежать (удар на ходу).
##
##   loco (стойка · ходьба · бег по скорости) → темп шага ─┐
##   act (удары, приёмы, уклонения, реакции; перекрёстный переход) → перемотка → темп ─┤→ mix → выход
class_name HeroAnim
extends Node

var ACTS: Array = []        # имена действий (по ключам anims в setup)
const XFADE := 0.16         # переход между действиями, с
const BLEND_IN := 11.0      # скорость наложения действия (1/с)
const BLEND_OUT := 5.0      # выход из действия обратно в ходьбу — мягче (≈0,2 с)
const LOCO_SMOOTH := 9.0    # скорость в смеси ходьбы/бега догоняет настоящую плавно (1/с)

var tree: AnimationTree
var _names := {}            # действие → имя анимации
var _mix: AnimationNodeBlend2
var _cur := ""              # текущее действие ("" — только ходьба)
var _w := 0.0               # вес действия
var act_time := 0.0         # позиция в анимации действия (с)
var act_scale := 1.0
var _upper := false
var _loco_pos := 0.0
var _loco_target := 0.0

## player — AnimationPlayer модели; anims — действие → имя анимации;
## loco_points — [[имя анимации, скорость м/с], …] для смешения ходьбы
func setup(player: AnimationPlayer, sk: Skeleton3D, anims: Dictionary, loco_points: Array, max_speed: float) -> void:
	_names = anims.duplicate()
	ACTS = anims.keys()
	var bt := AnimationNodeBlendTree.new()
	# Ходьба: по скорости — стойка → бег → быстрый бег
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = max_speed
	for i in loco_points.size():
		loco.add_blend_point(_anim_node(loco_points[i][0]), loco_points[i][1], -1, StringName("p%d" % i))
	bt.add_node("loco", loco, Vector2(0, 0))
	bt.add_node("loco_ts", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.connect_node("loco_ts", 0, "loco")
	# Действия: перекрёстный переход между ними, перемотка и темп
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = XFADE
	tr.allow_transition_to_self = true
	for i in ACTS.size():
		tr.add_input(ACTS[i])
		var a := ACTS[i] as String
		bt.add_node("a_" + a, _anim_node(_names[a]), Vector2(0, 150 + i * 80))
	bt.add_node("act", tr, Vector2(200, 200))
	for i in ACTS.size():
		bt.connect_node("act", i, "a_" + ACTS[i])
	bt.add_node("act_seek", AnimationNodeTimeSeek.new(), Vector2(400, 200))
	bt.connect_node("act_seek", 0, "act")
	bt.add_node("act_ts", AnimationNodeTimeScale.new(), Vector2(600, 200))
	bt.connect_node("act_ts", 0, "act_seek")
	# Смешение: на бегу — только верх тела (позвоночник, руки, голова)
	_mix = AnimationNodeBlend2.new()
	bt.add_node("mix", _mix, Vector2(800, 100))
	bt.connect_node("mix", 0, "loco_ts")
	bt.connect_node("mix", 1, "act_ts")
	bt.connect_node("output", 0, "mix")
	tree = AnimationTree.new()
	tree.name = "HeroAnimTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = player.root_node
	tree.tree_root = bt
	_set_upper_filter(sk, player)
	tree.active = true
	player.active = false

func _anim_node(n: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = n
	return a

## Фильтр «верх тела»: позвоночник и всё, что от него растёт
func _set_upper_filter(sk: Skeleton3D, player: AnimationPlayer) -> void:
	var root: Node = tree.get_node(tree.root_node)
	var base := String(root.get_path_to(sk))
	var spine := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("Spine"):
			spine = i
			break
	if spine < 0:
		return
	var stack := [spine]
	while not stack.is_empty():
		var b: int = stack.pop_back()
		_mix.set_filter_path(NodePath(base + ":" + sk.get_bone_name(b)), true)
		for c in sk.get_bone_children(b):
			stack.append(c)

## Ходьба: скорость героя (м/с) и темп анимации шага
## Заменить анимацию точки ходьбы (например, бег: спринт ↔ бег с мечом наготове в бою)
func set_loco_anim(point: int, anim_name: String) -> void:
	var loco: AnimationNodeBlendSpace1D = (tree.tree_root as AnimationNodeBlendTree).get_node("loco")
	var node := loco.get_blend_point_node(point) as AnimationNodeAnimation
	if node and node.animation != StringName(anim_name):
		node.animation = anim_name

## Заменить анимацию действия (например, блок: мечом ↔ щитом — по снаряжению)
func set_act_anim(kind: String, anim_name: String) -> void:
	if not _names.has(kind):
		return
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node("a_" + kind) as AnimationNodeAnimation
	if node and node.animation != StringName(anim_name):
		node.animation = anim_name
		_names[kind] = anim_name

func locomotion(speed: float, stride_scale: float) -> void:
	_loco_target = speed
	tree.set("parameters/loco_ts/scale", stride_scale)

## Начать или продолжить действие. pos ≥ 0 — перемотать на эту секунду,
## scale — темп (0 — замереть в позе), upper — только верх тела
func act(kind: String, pos: float, scale: float, upper := false) -> void:
	if kind != _cur:
		_cur = kind
		tree.set("parameters/act/transition_request", kind)
		if pos < 0.0:
			pos = 0.0
	if pos >= 0.0:
		act_time = pos
		tree.set("parameters/act_seek/seek_request", pos)
	act_scale = scale
	# Поза ставится перемоткой каждый кадр (scale 0): темп оставляем 1, иначе темп 0 останавливает
	# и плавный переход от прошлого действия — новая анимация так и не проявлялась (Горизонталь, Вихрь)
	tree.set("parameters/act_ts/scale", scale)
	if upper != _upper:
		_upper = upper
		_mix.filter_enabled = upper

## Действие по ключевым позам: клип ведётся к нужной секунде t не перемоткой каждый кадр
## (так дерево анимаций в игре показывало исходную позу модели), а темпом: перемотка — только
## в начале и при большом расхождении, дальше клип просто играет быстрее или медленнее
func follow(kind: String, t: float, dt: float, upper := false) -> void:
	if kind != _cur or absf(t - act_time) > 0.35:
		act(kind, t, 1.0, upper)
		return
	var sc := clampf((t - act_time) / maxf(dt, 0.001), -4.0, 8.0)
	if absf(sc) < 0.05:
		sc = 0.05 if sc >= 0.0 else -0.05   # не ноль: при нуле замирает и переход между клипами
	act_scale = sc
	tree.set("parameters/act_ts/scale", sc)
	if upper != _upper:
		_upper = upper
		_mix.filter_enabled = upper

## Действие закончилось — плавно вернуться к ходьбе
func stop() -> void:
	_cur = ""

func current() -> String:
	return _cur

func weight() -> float:
	return _w

func update(dt: float) -> void:
	_loco_pos = lerpf(_loco_pos, _loco_target, 1.0 - exp(-LOCO_SMOOTH * dt))
	tree.set("parameters/loco/blend_position", _loco_pos)
	if _cur != "":
		act_time += dt * act_scale
		_w = minf(1.0, _w + dt * BLEND_IN)
	else:
		_w = maxf(0.0, _w - dt * BLEND_OUT)
		if _w <= 0.0 and _upper:
			_upper = false
			_mix.filter_enabled = false
	tree.set("parameters/mix/blend_amount", _w)

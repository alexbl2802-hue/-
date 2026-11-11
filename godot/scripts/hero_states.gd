## Машина состояний героя: одно согласованное состояние и одна таблица «что из какого состояния
## можно начать» вместо разрозненных проверок в каждом действии. Прежние разрешения сохранены
## (удар, приём и уклонение — и в прыжке, уклонение и рывок прерывают удар); убраны несогласованные:
## действия во время оглушения/падения, рывок поверх приёма, приём поверх уклонения или рывка.
## Состояние выводится из полей героя (механика движения и боя не переписана): мёртв → оглушён/сбит
## (stagger) → рывок → уклонение/кувырок → приём (Горизонталь, приём оружия) → удар → блок → в воздухе
## (jump) → приземление → спринт / бег / шаг → бой (стойка рядом с врагом) / покой.
## Выносливости в игре нет — её проверок нет.
class_name HeroStates
extends RefCounted

const STAGGER_MOVES := ["stun", "hit_heavy", "knockdown", "getup"]
const COMBAT_RANGE := 12.0      # враг ближе — стойка «бой»

## Действие → состояния, из которых его можно начать
const CAN := {
	"attack": ["idle", "combat", "walk", "run", "sprint", "jump", "land", "attack"],          # в ударе — очередь комбо
	"dodge": ["idle", "combat", "walk", "run", "sprint", "jump", "land", "attack", "block", "dodge", "roll"],
	"dash": ["idle", "combat", "walk", "run", "sprint", "land", "attack", "block", "jump"],
	"skill": ["idle", "combat", "walk", "run", "sprint", "jump", "land", "attack", "block"],  # Горизонталь, приём оружия
	"block": ["idle", "combat", "walk", "run", "sprint", "land", "block"],
}
## Прыжок не в таблице: его условие физическое (на земле, не в воде, без особого движения — hero.gd)

var current := "idle"
var since := 0.0                # секунд в текущем состоянии
var log: Array = []             # последние переходы [от, к, время]

## Текущее состояние героя по его полям
static func of(h: Node) -> String:
	if h.dead:
		return "dead"
	var mv: String = h._move
	if mv in STAGGER_MOVES:
		return "stagger"
	if h._dash_t >= 0.0:
		return "dash"
	if mv.begins_with("dodge"):
		return "dodge"
	if mv == "roll":
		return "roll"
	if mv == "horizontal" or h._art_t >= 0.0:
		return "skill"
	if h.attack_t >= 0.0:
		return "attack"
	if h.blocking:
		return "block"
	if not h.is_on_floor():
		return "jump"
	if mv == "land" or h._land_t >= 0.0:
		return "land"
	var sp: float = h._speed_now
	if sp >= h.LOCO_RUN_TOP:
		return "sprint"
	if sp >= h.LOCO_WALK_TOP:
		return "run"
	if sp >= h.LOCO_WALK_FROM:
		return "walk"
	if h.enemies and not h.enemies.alive_near(h.global_position, COMBAT_RANGE).is_empty():
		return "combat"
	return "idle"

## Можно ли сейчас начать действие (по текущему состоянию героя)
static func can(h: Node, action: String) -> bool:
	if h.busy:
		return false
	return (CAN.get(action, []) as Array).has(of(h))

## Обновить (раз в кадр физики). Возвращает [было, стало] при смене, иначе []
func update(h: Node, dt: float) -> Array:
	var s := of(h)
	since += dt
	if s == current:
		return []
	var out := [current, s]
	log.append([current, s, Time.get_ticks_msec() / 1000.0])
	if log.size() > 64:
		log.pop_front()
	current = s
	since = 0.0
	return out

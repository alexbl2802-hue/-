## CARDINAL 4.0 — единый источник настроек. Все лимиты и пороги CARDINAL берутся отсюда;
## меняющееся состояние (сложность, текущий лимит бодрствующих монстров, учёт монстров) хранит
## autoload Cardinal (addons/cardinal/scripts/cardinal.gd) — других копий этих значений нет.
class_name CardinalConfig
extends RefCounted

# Монстры: созданы заранее (вдали «спят») и бодрствующие (рядом с героем, считают ИИ и анимацию)
const REGISTERED_MOBS_MAX := 2000     # сколько монстров может быть создано в мире
const ACTIVE_MOBS_DEFAULT := 35       # сколько ближайших к герою бодрствует (обычно рядом 2–10)
const ACTIVE_MOBS_MIN := 10           # ниже — не опускать даже при низкой частоте кадров
const ACTIVE_MOBS_STEP := 5           # шаг изменения лимита монитором производительности
const ACTIVE_RANGE := 110.0           # м: дальше — спит
const BOSSES_MAX := 4                 # одновременно зарегистрированных боссов (лимит спавна)

# Баланс
const DIFFICULTY_MIN := 0.5
const DIFFICULTY_MAX := 3.0
const MONSTER_DAMAGE_MIN := 0.75      # множитель урона монстров при сложности 0,5
const MONSTER_DAMAGE_MAX := 1.25      # … при сложности 3
const LOOT_MULT_MIN := 0.1
const LOOT_MULT_MAX := 3.0
const SETTINGS_PATH := "user://cardinal.cfg"

# Производительность
const LOW_FPS := 25.0                 # ниже — снижать лимит бодрствующих
const RECOVER_FPS := 40.0             # выше три проверки подряд — возвращать лимит
const PERF_CHECK_SECONDS := 5.0

# Автотест
const TEST_LIMIT_SECONDS := 900.0     # жёсткий предел прогона (реальное время, с ожиданиями)
const TEST_FIELD_SECONDS := 60.0      # игровое время боя с монстрами перед сценариями

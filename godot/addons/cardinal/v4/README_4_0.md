# CARDINAL 4.0

CARDINAL управляет игровыми процессами, диагностикой и тестированием. Генерация, проверка и улучшение
анимаций и скелетов — ANIMATE (`scripts/animate_audit.gd`, `animate_3_1/`, `addons/animate/`); CARDINAL её
только запускает после загрузки мира и пишет итог в журнал.

## Единый источник истины
| Что | Где |
|---|---|
| Все лимиты и пороги (монстры, боссы, сложность, добыча, производительность, автотест) | `v4/cardinal_config.gd` (`CardinalConfig`) |
| Состояние: учёт монстров/боссов/сундуков, сложность, текущий лимит бодрствующих | autoload `Cardinal` (`scripts/cardinal.gd`) |
| Множитель добычи и правила сложности | `v4/cardinal_balance.gd` (`CardinalBalance`), сохраняется в `user://cardinal.cfg` |

`CardinalCore.max_monsters` и `CardinalCore.loot_multiplier` — не копии, а ссылки на эти значения (публичный API 2.1 сохранён).

## Компоненты
| Область | Компонент | Файл |
|---|---|---|
| Управление миром, учёт сущностей, лимиты спавна | autoload `Cardinal` | `scripts/cardinal.gd` |
| Появление монстров и боссов, сон/пробуждение | игра: `scripts/enemies.gd` (`_update_active` берёт лимит из `Cardinal.max_active_mobs`) | — |
| Таблицы добычи | `CardinalLootTables`, `CardinalLootManager` | `scripts/loot_tables.gd`, `scripts/loot_manager.gd` |
| Баланс (сложность, урон монстров, добыча) | `CardinalBalance` | `v4/cardinal_balance.gd` |
| Задания | нет в игре (реестр отмечает SKIPPED) | — |
| Экономика (покупка, ковка, золото) | игра: `scripts/game.gd`, окна кузницы и алхимика; реестр — системы `trade`, `forge` | — |
| Диагностика | `CardinalGuardian`, `CardinalHeroGuard`, `CardinalErrorGuardian`, журнал `CardinalCore` | `scripts/cardinal_guardian.gd`, `scripts/cardinal_hero_guard.gd`, `v2/*` |
| Производительность | `CardinalPerformanceManager` — снижает/возвращает лимит бодрствующих монстров по FPS | `v2/performance_manager.gd` |
| Реестр систем для тестов | `CardinalRegistry` | `v4/cardinal_registry.gd` |
| Автотест и сценарии | `CardinalAutotest`, `CardinalScenarios` | `scripts/cardinal_autotest.gd`, `scripts/cardinal_scenarios.gd` (в игре) |
| Подключение к игре | `CardinalDirector` | `scripts/cardinal_director.gd` (в игре) |

## Лимиты монстров (раньше было три разных числа: 35, 40, 2000)
- `REGISTERED_MOBS_MAX = 2000` — сколько монстров может быть создано (вдали они «спят»).
- `ACTIVE_MOBS_DEFAULT = 35` — сколько ближайших к герою бодрствует; монитор FPS опускает до 10 при < 25 к/с и возвращает при > 40 к/с.
- Боссы в радиусе бодрствуют всегда, вне лимита.

## Автотест
- Реестр определяет, какие системы есть: бой, монстры, боссы, инвентарь, навыки, NPC, торговля, кузница, задания, подземелья, добыча, сохранения.
- Каждая проверка: PASS / FAIL / SKIPPED / NOT_TESTED с причиной и данными.
- Общий предел — 900 с **реального** времени (таймер идёт и на паузе, и при ускорении, и во время ожиданий сценариев); раньше завершается, когда пройдены все сценарии; число убийств не влияет.
- После прогона возвращаются сохранение (через временный файл), место героя, режим мира, окна и скорость.

## Интерфейс администратора
Окно CARDINAL (и через него ANIMATE) скрыто от обычных игроков: кнопка появляется только в режиме
администратора — 7 нажатий на номер версии в главном меню за 3 секунды (повтор выключает).

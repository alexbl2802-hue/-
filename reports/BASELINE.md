# BASELINE — «Земли Приключений», этап 0

Дата: 2026-11-09. Ветка `audit-4.0` (локальная), снимок до изменений — тег `pre-audit-4.0` (коммит `a73ca1d`).

## Входные данные
| Файл из задания | Состояние |
|---|---|
| `zemli_godot_project.zip` | Не приложен к заданию. Использован **сам исходный проект** из репозитория (`godot/`), из которого этот архив был собран (коммит `a73ca1d`). |
| `ZemliPriklyucheniy-2.0.63.apk` | Не приложен. Сравнение с APK не выполнялось (**NOT_TESTED**). |
| `packs game.z01…z13`, `packs game.zip` | Не приложены. Пакеты ресурсов локально не проверялись; исходные модели и текстуры есть в `godot/models`, `godot/textures` (1,4 ГБ + 19 МБ). |

## Окружение
- Godot **4.7.stable.official.5b4e0cb0f** (совпадает с целевой 4.7).
- ОС Linux, CPU Intel Xeon 2.10 GHz × 4, ОЗУ 15 ГБ, **без GPU**: отрисовка программная (llvmpipe, Vulkan 1.4 через Mesa).
- Android SDK/JDK в этом окружении не проверялись (этап 7). Сборка APK делается в GitHub Actions (`.github/workflows/godot-android.yml`).

## Структура проекта
- `project.godot`: главная сцена `res://scenes/boot.tscn`; рендер `mobile` (запасной — OpenGL3); физика Jolt, 60 тиков; окно 844×390, растяжение `canvas_items/expand`, альбомная ориентация; сжатие текстур ETC2/ASTC.
- Autoload: `Game` (`scripts/game.gd`), `Cardinal` (`addons/cardinal/scripts/cardinal.gd`).
- Плагин редактора: `addons/animate` (ANIMATE).
- `export_presets.cfg`: preset 0 «Android» (пакет `com.alexbl.zemlipriklyucheniy`, arm64-v8a + armeabi-v7a, без `models/`, `textures/`, `tests/` — они идут пакетами `.pck`), preset 1 «Data» (сборка пакетов).
- Сцены: `scenes/boot.tscn` (загрузка/докачка пакетов), `scenes/main.tscn` (игра); остальное строится кодом. Тестовые сцены — `tests/*.tscn` (в APK не входят).
- Скрипты: 120 своих `.gd` (без Terrain3D), 17 319 строк. Крупнейшие: `scripts/hero.gd` 1922, `scripts/enemy.gd` 1343, `scripts/cardinal_autotest.gd` 1047, `scripts/world.gd` 906, `scripts/dungeon.gd` 884.

## Карта модулей
| Область | Файлы |
|---|---|
| Запуск и пакеты | `scripts/boot.gd`, `scripts/ui/loading_screen.gd`, `tools/data_pack.py` → `data/packs.json` (создаётся при сборке) |
| Состояние игры, сохранение | `scripts/game.gd` (`user://save.json`, поле `"v": 2`), `scripts/settings.gd` (`user://settings.cfg`) |
| Мир | `scripts/main.gd`, `world.gd`, `world_gen.gd`, `world2.gd`, `town.gd`, `dungeon.gd`, `data/dungeon_defs.gd`, `day_night.gd`, `grade.gd` |
| Герой | `scripts/hero.gd`, `hero_anim.gd` (AnimationTree), `foot_ik.gd`, `hand_grip.gd`, `ragdoll.gd`, `sao_gear.gd`, `camera_rig.gd` |
| Монстры | `scripts/enemy.gd`, `enemies.gd`, `spike.gd` |
| Предметы, навыки, добыча | `scripts/data/items.gd`, `data/skill_defs.gd`, `loot.gd`, `addons/cardinal/scripts/loot_*.gd` |
| UI | `scripts/hud.gd`, `touch_ui.gd`, `minimap.gd`, `scripts/ui/*.gd` |
| CARDINAL | autoload `addons/cardinal/scripts/cardinal.gd`; `addons/cardinal/scripts/*` (guardian, spawn director, loot, mob/chest components); `addons/cardinal/v2/*` (core, admin panel, error/animation guardian, skeleton repair, performance, item system); игра: `scripts/cardinal_director.gd`, `cardinal_autotest.gd`, `cardinal_scenarios.gd`, `cardinal_hero_guard.gd`, `ui/cardinal_panel.gd` |
| ANIMATE | `addons/animate/*` (плагин: dock, generator, inspector, autofix, skeleton_builder), `animate_3_1/*` (pose generator, validator), `scripts/animate_audit.gd`, `scripts/ui/animate_panel.gd`, `scripts/anim/pose_lib.gd`, `addons/combat_pack/*` |
| Передвижение (демо-модуль) | `hybrid_movement/*` |

## Базовые проверки
| Проверка | Команда | Результат | Лог |
|---|---|---|---|
| Импорт проекта | `godot --headless --path godot --import` | rc 0, ошибок 0 | `reports/logs/import.log` |
| Разбор всех скриптов | `godot --headless --path godot res://tests/load_all.tscn` | 120 загружено, 0 с ошибками | `reports/logs/parse_all.log` |
| Стартовая сцена | `godot --path godot --quit-after 3000` (xvfb) | без ошибок скриптов; CARDINAL запущен; проверка анимаций: 9 моделей, 0 ошибок; скелеты 5/5 | `reports/logs/boot_scene.log` |
| Пакеты `.pck` | — | **NOT_TESTED**: пакетов нет во входных данных; локально данные берутся напрямую из `res://models` (boot.gd:66) | — |

Единственная ошибка движка в журналах — `ERR_CANT_OPEN` в `drivers/alsa` (нет звуковой карты в контейнере), к игре не относится.

## Метрики (сцена `main.tscn`, тест `tests/baseline.tscn`)
| Метрика | Программный рендер (xvfb, llvmpipe) | Без отрисовки (`--headless`) |
|---|---|---|
| Загрузка `main.tscn` до героя | 45,4 с | 28,1 с |
| FPS (10 с, в городе) | 0,9 | 144,2 |
| Время кадра скриптов (process) | 1077 мс | 5,6 мс |
| Физика за кадр | 3,6 мс | 1,2 мс |
| Вызовов отрисовки в кадре | 878 | — |
| Примитивов в кадре | 7 053 807 | — |
| Объектов в кадре | 907 | — |
| Узлов / объектов | 43 606 / 88 331 | 43 606 / 88 478 |
| Монстров в мире (созданы заранее, вдали «спят») | 445 | 445 |

**Ограничение:** окружение без GPU, поэтому FPS и время кадра отрисовки **не отражают телефон**. Цифры отрисовки (draw calls, примитивы) от устройства не зависят и годятся для сравнения «до/после». Измерений на Android не было.

## Исходно найденные проблемы (подробности в ISSUES.md)
- Три разных лимита монстров CARDINAL: 35 (autoload по умолчанию), 2000 (`cardinal_director.gd:29`), 40 (`CardinalCore.max_monsters`, нигде не используется).
- Целостность пакетов проверяется только по размеру файла (`boot.gd:73`).
- Сохранение пишется прямо поверх `user://save.json`: при сбое во время записи файл можно потерять (`game.gd:449`).
- В кадре 7 млн примитивов: для телефона это очень много (этап 6).

# TEST_RESULTS

Окружение: Linux, Intel Xeon 2.10 GHz × 4, 15 ГБ ОЗУ, без GPU (llvmpipe); Godot 4.7.stable.official.5b4e0cb0f. `G` = путь к Godot.

## Этап 0
| Команда | Результат | Время | Лог |
|---|---|---|---|
| `$G --headless --path godot --import` | rc 0, 0 ошибок | < 15 мин | `reports/logs/import.log` |
| `$G --headless --path godot res://tests/load_all.tscn` | 120 скриптов, 0 ошибок | ~10 с | `reports/logs/parse_all.log` |
| `xvfb-run $G --path godot --quit-after 3000` (стартовая сцена) | без ошибок скриптов | 120 с (тайм-аут обёртки, сцена работала) | `reports/logs/boot_scene.log` |
| `xvfb-run $G --path godot res://tests/baseline.tscn` | метрики — см. BASELINE.md | ~3 мин | `reports/logs/baseline_run.log` |
| `$G --headless --path godot res://tests/baseline.tscn` | метрики без отрисовки | ~1 мин | `reports/logs/baseline_headless.log` |

## Этап 1
| Команда | Результат | Лог |
|---|---|---|
| `$G --headless --path godot res://tests/save_safety.tscn` | 8/8 PASS (запись, копия, порча основного файла → копия, сохранение новее v3 → копия `.v3.bak`, «Новая игра») | `reports/logs/save_safety.log` |
| `$G --headless --path godot res://tests/boot_packs.tscn` | 7/7 PASS: целый пакет монтируется и содержимое читается без сети; повреждённый пакет того же размера найден по sha256 и удалён; нет пакета + нет сети → ошибка с «Повторить» (4 автоповтора); формат данных 99 → «обнови игру»; старый вид списка работает | `reports/logs/boot_packs.log` |
| `python3 -m py_compile tools/data_pack.py` | OK. Сам сборщик (`--export-pack` по всем моделям) локально **не запускался** — выполняется в CI при сборке | — |
| `res://tests/load_all.tscn` | 122 скрипта, 0 ошибок | — |

Ограничение: системный загрузчик Android (DownloadManager) в этом окружении не проверяется — проверен путь HTTPClient.

## Этап 2
| Команда | Результат | Время | Лог |
|---|---|---|---|
| `$G --headless --path godot res://tests/cardinal_autoplay.tscn -- <папка> 100000` (прогон 1, до правки итога) | 21 PASS, 0 FAIL, 1 SKIPPED (задания — нет системы); итог INCOMPLETE из-за I-15 | 100 с | `reports/logs/cardinal_autotest_run1.log` |
| то же (прогон 2) | **PASSED**: 21 PASS, 0 FAIL, 1 SKIPPED, 0 NOT_TESTED; 2 предупреждения «герой застрял» (короткие) | 103 с | `reports/logs/cardinal_autotest_run2.log` |
| `$G --headless --path godot res://tests/cardinal_timeout.tscn` | 6/6 PASS: предел 15 с при ×4 сработал на 15,1 с реального времени; 11 проверок NOT_TESTED «Не успели: общий предел»; скорость и место героя возвращены | ~40 с | `reports/logs/cardinal_timeout.log` |
| `$G --headless --path godot res://tests/cardinal_limits.tscn` | 6/6 PASS: единый лимит 35/2000, нижняя граница 10; в самом людном месте (16 монстров в радиусе) при лимите 10 бодрствуют 10; кнопка CARDINAL скрыта без режима администратора | ~40 с | `reports/logs/cardinal_limits.log` |

Ограничения: прогоны без отрисовки (`--headless`), FPS в отчёте автотеста — этого компьютера, не телефона. Автотест на Android не запускался.

## Этап 3
| Команда | Результат | Лог |
|---|---|---|
| `$G --headless --path godot res://tests/animate4_demo.tscn -- <папка>` (проверки) и `xvfb-run $G --path godot res://tests/animate4_demo.tscn -- <папка>` (проверки + кадры) | **13/13 PASS**: выпад с рывком, горизонтальный, вихрь, блок мечом, блок щитом, рывки с места ×4, с бега ×4. Для каждого: конечные значения, пределы суставов (±3°), скольжение стоп на контактах ≤ 2 см, всё тело (таз/позвоночник, обе руки, обе ноги ≥ 8°), анимирована кисть с оружием, клинок в ключевых позах (косинус ≥ 0,85), щит перед собой (для блока щитом), порядок фаз | `reports/logs/animate4_demo_final.log`; кадры — `reports/previews/animate4/` |
| Промежуточные прогоны 1–7 | ошибки, найденные валидатором и исправленные (см. CHANGELOG): переразгиб колена, выход запястья между ключами, скольжение стоп из-за склейки контактов и старых ключей, щит сбоку, парение стоп на 4–5 см | `reports/logs/animate4_demo_1..7.log` |
| `$G --headless --path godot res://tests/animate4_window.tscn` | 9/9 PASS: разбор 6 описаний (в т.ч. нераспознанное), окно ANIMATE в игре использует 4.0 и показывает проверки, простое движение — генератор ANIMATE 3 | `reports/logs/animate4_window.log` |
| `res://tests/load_all.tscn` | 142 скрипта (с `animate_4`, `addons/animate`), 0 ошибок | — |

Ограничения: проверка «пределы суставов» опирается на пределы `PoseLib.LIMITS` (замер по клипам героя); качество поз оценено глазами по кадрам, не специалистом-аниматором. Сгенерированные клипы в бою героя не подставлены (этап 4 — сохранять существующие механики).

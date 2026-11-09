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

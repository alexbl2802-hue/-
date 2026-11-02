#!/usr/bin/env python3
"""Анимации из Meshy по API (запускается сценарием GitHub Actions «Meshy animations»).

1) Скелет: задача риггинга для модели (ссылка на файл модели) — или готовый rig_task_id.
2) Анимации: для каждого номера движения (action_id) из библиотеки Meshy — задача анимации.
3) Все .glb из ответов скачиваются в meshy/<имя>/, полные ответы Meshy — в meshy/<имя>/log.json.

Ключ — переменная окружения MESHY_API_KEY (секрет репозитория).

python3 tools/meshy_fetch.py --name hero --model-url URL --actions 1,2,3 [--rig-task ID] [--height 1.8]
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.meshy.ai/openapi/v1"
ROOT = Path(__file__).resolve().parent.parent
LOG = []


def call(method, path, body=None):
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        sys.exit("Нет MESHY_API_KEY (добавьте секрет репозитория).")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            out = json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors="replace")
        LOG.append({"request": [method, path, body], "error": e.code, "body": text})
        print(f"Ошибка {e.code} на {method} {path}: {text}")
        raise
    LOG.append({"request": [method, path, body], "response": out})
    return out


def wait(path, what):
    """Ждём задачу: статусы PENDING / IN_PROGRESS → SUCCEEDED / FAILED / CANCELED."""
    for _ in range(240):   # до 40 минут
        t = call("GET", path)
        st = str(t.get("status", "")).upper()
        print(f"  {what}: {st} {t.get('progress', '')}")
        if st == "SUCCEEDED":
            return t
        if st in ("FAILED", "CANCELED", "EXPIRED"):
            raise RuntimeError(f"{what}: {st} — {json.dumps(t.get('task_error', t), ensure_ascii=False)}")
        time.sleep(10)
    raise RuntimeError(f"{what}: не дождались")


def glb_urls(obj, prefix=""):
    """Все ссылки на .glb в ответе (любые поля вида *_glb_url или ссылки, оканчивающиеся на .glb)."""
    out = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            out += glb_urls(v, prefix + k + ".")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            out += glb_urls(v, prefix + str(i) + ".")
    elif isinstance(obj, str) and obj.startswith("http") and (".glb" in obj.split("?")[0] or prefix.rstrip(".").endswith("glb_url")):
        out.append((prefix.rstrip("."), obj))
    return out


def download(url, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=600) as r, open(dst, "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    print(f"  → {dst.relative_to(ROOT)} ({dst.stat().st_size / 1e6:.1f} МБ)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--model-url", default="")
    ap.add_argument("--rig-task", default="")
    ap.add_argument("--actions", default="")
    ap.add_argument("--height", type=float, default=1.8)
    ap.add_argument("--fps", type=int, default=0)   # 0 — без пересчёта частоты кадров
    a = ap.parse_args()
    out_dir = ROOT / "meshy" / a.name
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        rig_id = a.rig_task.strip()
        if not rig_id:
            if not a.model_url:
                sys.exit("Нужна ссылка на модель (--model-url) или готовый rig_task_id (--rig-task).")
            print("Риггинг модели:", a.model_url)
            r = call("POST", "/rigging", {"model_url": a.model_url, "height_meters": a.height})
            rig_id = r.get("result") or r.get("id")
            print("  задача риггинга:", rig_id)
            rig = wait(f"/rigging/{rig_id}", "риггинг")
            for field, url in glb_urls(rig.get("result", rig)):
                download(url, out_dir / ("rig_" + field.replace(".", "_") + ".glb"))
        (out_dir / "rig_task_id.txt").write_text(rig_id + "\n")
        # Движения — пачками до 10 (action_ids): Meshy отдаёт один файл, в нём клип на каждое движение
        acts = [int(x) for x in a.actions.replace(" ", "").split(",") if x.strip()]
        for i in range(0, len(acts), 10):
            part = acts[i:i + 10]
            print("Анимации", part)
            body = {"rig_task_id": rig_id, "action_ids": part}
            if a.fps:
                body["post_process"] = {"operation_type": "change_fps", "fps": a.fps}
            r = call("POST", "/animations", body)
            task_id = r.get("result") or r.get("id")
            t = wait(f"/animations/{task_id}", f"анимации {part}")
            res = t.get("result", t)
            url = res.get("animation_glb_url") if isinstance(res, dict) else None
            tag = "_".join(str(x) for x in part)
            if url:
                download(url, out_dir / f"anim_{tag}.glb")
            else:
                for field, u in glb_urls(res):
                    download(u, out_dir / f"anim_{tag}_{field.replace('.', '_')}.glb")
    finally:
        (out_dir / "log.json").write_text(json.dumps(LOG, ensure_ascii=False, indent=1))
        print("Журнал ответов Meshy:", (out_dir / "log.json").relative_to(ROOT))


if __name__ == "__main__":
    main()

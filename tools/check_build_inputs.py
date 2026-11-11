#!/usr/bin/env python3
"""Fail early instead of publishing an APK that cannot load the game world."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
g = root / 'godot'
required = [g/'project.godot', g/'export_presets.cfg', g/'scripts/hero.gd', g/'scripts/boot.gd', g/'data/world.bin']
missing = [str(p.relative_to(root)) for p in required if not p.is_file()]
models = list((g/'models').rglob('*.glb')) if (g/'models').exists() else []
textures = list((g/'textures').rglob('*')) if (g/'textures').exists() else []
parts = list((root/'meshy/big').glob('*.part00')) if (root/'meshy/big').exists() else []
if not models and not parts:
    missing.append('godot/models/*.glb или meshy/big/*.part00 (в архиве отсутствуют исходные 3D-модели)')
if not any(p.is_file() for p in textures):
    missing.append('godot/textures/ (отсутствуют исходные текстуры)')
if missing:
    print('BLOCKED: cannot produce a complete playable Android release:')
    for m in missing: print(' -', m)
    print('Upload full model/texture source to repository or restore them from the original split archive before building.')
    sys.exit(1)
print(f'OK: {len(models)} models, {sum(p.is_file() for p in textures)} textures, {len(parts)} model split archives')

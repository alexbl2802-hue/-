#!/usr/bin/env python3
"""Fail build if external resource manifest is absent, malformed or missing pack files."""
import json, pathlib, sys, hashlib
manifest=pathlib.Path(sys.argv[1]); pack_dir=pathlib.Path(sys.argv[2]); errors=[]
if not manifest.is_file(): sys.exit(f"ERROR: missing {manifest}; data_pack.py must run before export")
try: data=json.loads(manifest.read_text(encoding="utf-8"))
except (ValueError, OSError) as e: sys.exit(f"ERROR: invalid manifest: {e}")
packs=data.get("packs")
if not isinstance(packs,list) or not packs: errors.append("packs must be a nonempty array")
else:
 for p in packs:
  if not isinstance(p,dict): errors.append("invalid pack entry"); continue
  name=p.get("name","")
  if not isinstance(name,str) or pathlib.PurePath(name).name != name or not name.endswith(".pck"):
   errors.append(f"invalid pack name: {name!r}");continue
  f=pack_dir/name
  if not f.is_file():errors.append(f"missing pack: {f}");continue
  if "size" in p and f.stat().st_size != int(p["size"]):errors.append(f"wrong size: {name}")
  if p.get("sha256"):
   h=hashlib.file_digest(f.open("rb"),"sha256").hexdigest()
   if h.lower()!=str(p["sha256"]).lower():errors.append(f"SHA256 mismatch: {name}")
if errors:sys.exit("ERROR: release validation failed:\n"+"\n".join(errors))
print(f"OK: {len(packs)} packs verified")

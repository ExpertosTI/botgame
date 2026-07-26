#!/usr/bin/env python3
"""Genera .godot/global_script_class_cache.cfg sin abrir el editor.

Los tests headless necesitan que los `class_name` (PlayerBase, GameTheme,
CombatVfx...) resuelvan. Normalmente ese cache lo escribe el editor al escanear
el proyecto, y reconstruirlo con `godot --import` obliga a reimportar ~190 MB de
GLB/PNG.

Godot 4.6 exige los campos `is_abstract` e `is_tool` en cada entrada; sin ellos
el motor ignora el cache y los autoloads no compilan.
"""

from __future__ import annotations

import os
import re
import sys

CLASS_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
EXTENDS_RE = re.compile(r"^\s*extends\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
TOOL_RE = re.compile(r"^\s*@tool\b", re.MULTILINE)
ABSTRACT_RE = re.compile(r"^\s*@abstract\b", re.MULTILINE)
SKIP_DIRS = {".git", ".godot", ".import", "export", "_tmp_kits", "addons"}


def scan(root: str) -> list[dict[str, object]]:
    found: list[dict[str, object]] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for filename in filenames:
            if not filename.endswith(".gd"):
                continue
            path = os.path.join(dirpath, filename)
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    text = handle.read()
            except OSError:
                continue
            name_match = CLASS_RE.search(text)
            if not name_match:
                continue
            extends_match = EXTENDS_RE.search(text)
            res_path = "res://" + os.path.relpath(path, root).replace(os.sep, "/")
            found.append(
                {
                    "class": name_match.group(1),
                    "base": extends_match.group(1) if extends_match else "RefCounted",
                    "path": res_path,
                    "is_tool": bool(TOOL_RE.search(text)),
                    "is_abstract": bool(ABSTRACT_RE.search(text)),
                }
            )
    found.sort(key=lambda entry: str(entry["class"]))
    return found


def render(entries: list[dict[str, object]]) -> str:
    items = []
    for entry in entries:
        items.append(
            '{{\n'
            '"base": &"{base}",\n'
            '"class": &"{cls}",\n'
            '"icon": "",\n'
            '"is_abstract": {abstract},\n'
            '"is_tool": {tool},\n'
            '"language": &"GDScript",\n'
            '"path": "{path}"\n'
            "}}".format(
                base=entry["base"],
                cls=entry["class"],
                path=entry["path"],
                abstract="true" if entry["is_abstract"] else "false",
                tool="true" if entry["is_tool"] else "false",
            )
        )
    return "list=[{}]\n".format(", ".join(items))


def main() -> int:
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    if not os.path.exists(os.path.join(root, "project.godot")):
        print("[class-cache] ERROR: %s no es un proyecto Godot" % root, file=sys.stderr)
        return 1
    entries = scan(root)
    if not entries:
        print("[class-cache] ERROR: no se encontró ningún class_name", file=sys.stderr)
        return 1
    out_dir = os.path.join(root, ".godot")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "global_script_class_cache.cfg")
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(render(entries))
    print("[class-cache] %d clases → %s" % (len(entries), out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# Inyecta ?v=SHA en index.html para forzar descarga fresca del bootstrap Godot.
set -euo pipefail
WEB_DIR="${1:-export/web}"
SHA="${2:-$(git rev-parse --short HEAD 2>/dev/null || date +%s)}"
HTML="${WEB_DIR}/index.html"

if [[ ! -f "$HTML" ]]; then
  echo "[cache-bust] no hay $HTML — skip"
  exit 0
fi

python3 - "$HTML" "$SHA" <<'PY'
import re, sys
path, sha = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8", errors="replace").read()

meta = (
    f"<!-- build {sha} -->\n"
    f'<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />\n'
    f'<meta http-equiv="Pragma" content="no-cache" />\n'
    f'<meta http-equiv="Expires" content="0" />\n'
    f'<meta name="botgame-build" content="{sha}" />\n'
)
if "botgame-build" not in text:
    text = re.sub(r"(<head[^>]*>)", r"\1\n" + meta, text, count=1, flags=re.I)

def add_v(url: str) -> str:
    if f"v={sha}" in url:
        return url
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}v={sha}"

# src="/index.js"  href='index.js'
def repl_attr(m):
    return f"{m.group(1)}{m.group(2)}{add_v(m.group(3))}{m.group(2)}"

text = re.sub(
    r"""((?:src|href)\s*=\s*)(['"])([^'"]*index\.(?:js|wasm|pck|png)[^'"]*)\2""",
    repl_attr,
    text,
    flags=re.I,
)

open(path, "w", encoding="utf-8").write(text)
print(f"[cache-bust] index.html → v={sha}")
PY

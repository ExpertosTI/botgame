#!/usr/bin/env bash
# Obliga al cliente Web a cargar SIEMPRE la build más reciente del servidor.
# - version.json con SHA
# - ?v=SHA en index.html / index.js / .wasm / .pck
# - script force-fresh: limpia SW/caches y recarga si el SHA cambió
set -euo pipefail
WEB_DIR="${1:-export/web}"
SHA="${2:-$(git rev-parse --short HEAD 2>/dev/null || date +%s)}"
HTML="${WEB_DIR}/index.html"
JS="${WEB_DIR}/index.js"
VER="${WEB_DIR}/version.json"

if [[ ! -f "$HTML" ]]; then
  echo "[cache-bust] no hay $HTML — skip"
  exit 0
fi

# version.json público (poll / comparación en el browser)
printf '%s\n' "{\"build\":\"${SHA}\",\"ts\":$(date +%s)}" > "$VER"

python3 - "$HTML" "$JS" "$SHA" <<'PY'
import re, sys, os

html_path, js_path, sha = sys.argv[1], sys.argv[2], sys.argv[3]

def add_v(url: str) -> str:
    if not url or url.startswith("data:") or url.startswith("blob:"):
        return url
    # quitar v= anterior
    url = re.sub(r"([?&])v=[^&#]*", r"\1", url)
    url = url.replace("?&", "?").rstrip("?&")
    sep = "&" if "?" in url else "?"
    if f"v={sha}" in url:
        return url
    return f"{url}{sep}v={sha}"

FORCE_JS = f"""
<script>
/* botgame force-fresh build={sha} */
(function () {{
  var BUILD = "{sha}";
  var KEY = "botgame_build";
  var RELOAD_KEY = "botgame_reloaded_for";

  function bustUrl(u) {{
    try {{
      var url = new URL(u, location.href);
      url.searchParams.set("v", BUILD);
      url.searchParams.set("_", String(Date.now()));
      return url.toString();
    }} catch (e) {{
      return u + (u.indexOf("?") >= 0 ? "&" : "?") + "v=" + BUILD;
    }}
  }}

  // Parchear fetch/XHR para .js/.wasm/.pck sin query de versión
  var _fetch = window.fetch;
  if (_fetch) {{
    window.fetch = function (input, init) {{
      try {{
        var raw = typeof input === "string" ? input : (input && input.url);
        if (raw && /index\\.(js|wasm|pck)(\\?|$)/i.test(raw) && raw.indexOf("v=" + BUILD) < 0) {{
          var next = bustUrl(raw);
          if (typeof input === "string") input = next;
          else if (input && typeof Request !== "undefined") input = new Request(next, input);
        }}
      }} catch (e) {{}}
      return _fetch.call(this, input, init);
    }};
  }}

  async function clearCaches() {{
    try {{
      if ("serviceWorker" in navigator) {{
        var regs = await navigator.serviceWorker.getRegistrations();
        for (var i = 0; i < regs.length; i++) await regs[i].unregister();
      }}
    }} catch (e) {{}}
    try {{
      if (window.caches && caches.keys) {{
        var keys = await caches.keys();
        await Promise.all(keys.map(function (k) {{ return caches.delete(k); }}));
      }}
    }} catch (e) {{}}
  }}

  async function ensureLatest() {{
    await clearCaches();
    var remote = BUILD;
    try {{
      var res = await fetch("/version.json?_=" + Date.now(), {{
        cache: "no-store",
        headers: {{ "Cache-Control": "no-cache" }}
      }});
      if (res.ok) {{
        var data = await res.json();
        if (data && data.build) remote = String(data.build);
      }}
    }} catch (e) {{}}

    var local = null;
    try {{ local = localStorage.getItem(KEY); }} catch (e) {{}}

    if (local && local !== remote) {{
      var already = null;
      try {{ already = sessionStorage.getItem(RELOAD_KEY); }} catch (e) {{}}
      if (already !== remote) {{
        try {{
          sessionStorage.setItem(RELOAD_KEY, remote);
          localStorage.setItem(KEY, remote);
        }} catch (e) {{}}
        var u = new URL(location.href);
        u.searchParams.set("v", remote);
        u.searchParams.set("_r", String(Date.now()));
        location.replace(u.toString());
        return;
      }}
    }}
    try {{ localStorage.setItem(KEY, remote); }} catch (e) {{}}
  }}

  // Arrancar cuanto antes (bloquea lo mínimo: fire and forget + sync clear attempt)
  ensureLatest();
}})();
</script>
"""

text = open(html_path, encoding="utf-8", errors="replace").read()

meta = (
    f"<!-- build {sha} -->\n"
    f'<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />\n'
    f'<meta http-equiv="Pragma" content="no-cache" />\n'
    f'<meta http-equiv="Expires" content="0" />\n'
    f'<meta name="botgame-build" content="{sha}" />\n'
)

# Reemplazar meta/build previos
text = re.sub(r"<!-- build [^>]*-->\s*", "", text)
text = re.sub(r'<meta http-equiv="Cache-Control"[^>]*>\s*', "", text, flags=re.I)
text = re.sub(r'<meta http-equiv="Pragma"[^>]*>\s*', "", text, flags=re.I)
text = re.sub(r'<meta http-equiv="Expires"[^>]*>\s*', "", text, flags=re.I)
text = re.sub(r'<meta name="botgame-build"[^>]*>\s*', "", text, flags=re.I)
text = re.sub(r"(<head[^>]*>)", r"\1\n" + meta, text, count=1, flags=re.I)

# Quitar script force-fresh anterior e inyectar al inicio de <head>
text = re.sub(
    r"<script>\s*/\* botgame force-fresh[\s\S]*?</script>\s*",
    "",
    text,
    flags=re.I,
)
text = re.sub(r"(<head[^>]*>)", r"\1\n" + FORCE_JS, text, count=1, flags=re.I)

def repl_attr(m):
    return f"{m.group(1)}{m.group(2)}{add_v(m.group(3))}{m.group(2)}"

text = re.sub(
    r"""((?:src|href)\s*=\s*)(['"])([^'"]*index\.(?:js|wasm|pck|png)[^'"]*)\2""",
    repl_attr,
    text,
    flags=re.I,
)

# También en strings del HTML embebido (GODOT_CONFIG)
text = re.sub(
    r"""(['"])(index\.(?:js|wasm|pck))\1""",
    lambda m: f"{m.group(1)}{add_v(m.group(2))}{m.group(1)}",
    text,
)

open(html_path, "w", encoding="utf-8").write(text)
print(f"[cache-bust] index.html → v={sha}")

# Parchear index.js: rutas a wasm/pck
if os.path.isfile(js_path):
    js = open(js_path, encoding="utf-8", errors="replace").read()
    # index.wasm / index.pck / "index.wasm" etc.
    def js_repl(m):
        path = m.group(2)
        quote = m.group(1)
        return f"{quote}{add_v(path)}{quote}"

    js2 = re.sub(
        r"""(['"])(index(?:\.audio\.worklet)?\.(?:js|wasm|pck|side\.wasm))\1""",
        js_repl,
        js,
    )
    # Sin comillas en concatenaciones raras: index.pck?
    js2 = re.sub(
        r"""(?<![\w./])(index\.(?:wasm|pck))(?!\?v=)""",
        lambda m: add_v(m.group(1)),
        js2,
    )
    if js2 != js:
        open(js_path, "w", encoding="utf-8").write(js2)
        print(f"[cache-bust] index.js parcheado → v={sha}")
    else:
        print("[cache-bust] index.js sin rutas literales (ok; fetch hook cubre)")
else:
    print("[cache-bust] sin index.js aún")
PY

echo "[cache-bust] version.json → build=${SHA}"

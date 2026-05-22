#!/usr/bin/env python3
"""Spotlight search backend — outputs JSON array of results."""
import ast
import json
import operator
import os
import sys
import glob
import re
import subprocess

# ── Argumentos ─────────────────────────────────────────────────────────
args = sys.argv[1:]
list_apps_mode = "--list-apps" in args
query_args = [a for a in args if not a.startswith("--")]
query = query_args[0].strip() if query_args else ""
query_low = query.lower()
results = []

# ── Resolución de iconos — caché persistente en disco ───────────────────
_ICON_CACHE_PATH = os.path.expanduser("~/.cache/qs-icon-cache.json")
_icon_cache: dict = {}

def _load_icon_cache() -> None:
    global _icon_cache
    try:
        with open(_ICON_CACHE_PATH) as f:
            _icon_cache = json.load(f)
    except Exception:
        _icon_cache = {}

def _save_icon_cache() -> None:
    try:
        os.makedirs(os.path.dirname(_ICON_CACHE_PATH), exist_ok=True)
        tmp = _ICON_CACHE_PATH + ".tmp"
        with open(tmp, "w") as f:
            json.dump(_icon_cache, f, separators=(",", ":"))
        os.replace(tmp, _ICON_CACHE_PATH)
    except Exception:
        pass

_load_icon_cache()
_icon_cache_dirty = False


def find_icon_path(icon_name: str) -> str:
    global _icon_cache_dirty
    if not icon_name:
        return ""
    if icon_name in _icon_cache:
        return _icon_cache[icon_name]
    if icon_name.startswith("/") and os.path.exists(icon_name):
        _icon_cache[icon_name] = icon_name
        _icon_cache_dirty = True
        return icon_name
    sizes = ["256x256", "128x128", "96x96", "64x64", "48x48", "32x32"]
    themes = ["hicolor", "Papirus", "Papirus-Dark", "breeze", "Adwaita"]
    cats = ["apps", "categories", "devices", "mimetypes"]
    for theme in themes:
        for size in sizes:
            for cat in cats:
                for ext in ("png", "svg"):
                    p = f"/usr/share/icons/{theme}/{size}/{cat}/{icon_name}.{ext}"
                    if os.path.exists(p):
                        _icon_cache[icon_name] = p
                        _icon_cache_dirty = True
                        return p
    for ext in ("png", "svg", "xpm"):
        p = f"/usr/share/pixmaps/{icon_name}.{ext}"
        if os.path.exists(p):
            _icon_cache[icon_name] = p
            _icon_cache_dirty = True
            return p
    _icon_cache[icon_name] = ""
    _icon_cache_dirty = True
    return ""


# ── Fuzzy scoring ────────────────────────────────────────────────────────
def _subsequence_score(q: str, t: str, min_consecutive: int = 1) -> int:
    """Devuelve 1-30 si todos los chars de q aparecen en orden en t
    y max_consecutive >= min_consecutive."""
    qi = 0
    consecutive = 0
    max_consecutive = 0
    for ch in t:
        if qi < len(q) and ch == q[qi]:
            qi += 1
            consecutive += 1
            max_consecutive = max(max_consecutive, consecutive)
        else:
            consecutive = 0
    if qi < len(q) or max_consecutive < min_consecutive:
        return 0
    ratio = max_consecutive / len(q)
    return max(1, int(ratio * 30))


def _word_char_score(q: str, t: str) -> int:
    """Tolerancia a typos: compara los chars del query contra cada palabra
    del texto. Si ≥80% de los chars del query están en la palabra, devuelve
    un score proporcional. Permite: 'btrave' → 'brave', etc."""
    sq = sorted(q)
    best = 0
    for word in re.split(r"[\s\-_()/]+", t):
        if len(word) < max(2, len(q) - 2):
            continue
        sw = sorted(word)
        common = 0
        i, j = 0, 0
        while i < len(sq) and j < len(sw):
            if sq[i] == sw[j]:
                common += 1
                i += 1
                j += 1
            elif sq[i] < sw[j]:
                i += 1
            else:
                j += 1
        sim_q = common / len(q)
        if sim_q >= 0.80:
            best = max(best, max(5, int(sim_q * 20)))
    return best


def fuzzy_score(query: str, name: str, extra: str = "") -> int:
    """
    Retorna score 0-100. 0 = sin coincidencia.
    100 = prefijo exacto del nombre
     70 = alguna palabra del nombre comienza con el query
     65 = multi-token: todos los tokens del query matchean palabras
     55 = el query es substring del nombre
     50 = multi-token matchea con campos extra (keywords/genericname)
     45 = el query es substring de los campos extra
     40 = alguna palabra de los campos extra comienza con el query
    1-30 = match por subsecuencia en el nombre (fuzzy letra a letra)
            solo si max_consecutive >= 2 chars (evita falsos positivos)
    """
    q = query.strip().lower()
    t = name.lower()
    k = extra.lower()

    if not q:
        return 0

    # Prefijo exacto completo
    if t.startswith(q):
        return 100

    # Cualquier palabra del nombre empieza con el query completo
    name_words = re.split(r"[\s\-_()/]+", t)
    for w in name_words:
        if w and w.startswith(q):
            return 70

    # Búsqueda multi-token (ej: "virt qemu", "brave btrave")
    tokens = q.split()
    if len(tokens) > 1:
        kw_words = re.split(r"[\s\-_()/;,]+", k) if k else []
        all_words = name_words + kw_words

        def token_match(tok: str, words: list, full_text: str) -> bool:
            return any(w.startswith(tok) for w in words if w) or tok in full_text

        if all(token_match(tok, name_words, t) for tok in tokens):
            return 65
        if k and all(token_match(tok, all_words, t + " " + k) for tok in tokens):
            return 50

    # Substring directo en el nombre
    if q in t:
        return 55

    # Substring en campos extra
    if k and q in k:
        return 45

    # Alguna palabra de los campos extra comienza con el query
    if k:
        for w in re.split(r"[\s\-_()/;,]+", k):
            if w and w.startswith(q):
                return 40

    # Subsecuencia fuzzy SOLO en el nombre (requiere ≥3 consecutivos)
    s = _subsequence_score(q, t, min_consecutive=3)
    if s > 0:
        return s

    # Tolerancia a typos: solapamiento de chars por palabra (btrave → brave)
    s = _word_char_score(q, t)
    if s > 0:
        return s

    return 0


# ── Parseo de .desktop ──────────────────────────────────────────────────
def parse_desktop(filepath: str):
    """Devuelve dict con campos o None si debe ocultarse."""
    try:
        with open(filepath, "r", errors="ignore") as fp:
            content = fp.read()
        if re.search(r"^NoDisplay=true", content, re.M):
            return None
        if re.search(r"^Hidden=true", content, re.M):
            return None
        name_m = re.search(r"^Name=(.+)$", content, re.M)
        exec_m = re.search(r"^Exec=(.+)$", content, re.M)
        if not name_m or not exec_m:
            return None
        icon_m = re.search(r"^Icon=(.+)$", content, re.M)
        generic_m = re.search(r"^GenericName=(.+)$", content, re.M)
        keywords_m = re.search(r"^Keywords=(.+)$", content, re.M)
        return {
            "name": name_m.group(1).strip(),
            "exec": re.sub(r"%[a-zA-Z]", "", exec_m.group(1).strip()).strip(),
            "icon": icon_m.group(1).strip() if icon_m else "",
            "generic": generic_m.group(1).strip() if generic_m else "",
            "keywords": keywords_m.group(1).strip() if keywords_m else "",
        }
    except Exception:
        return None


APP_DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
]


# ── Modo lista de apps (sin query) ──────────────────────────────────────
if list_apps_mode:
    apps = []
    seen: set = set()
    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(f"{d}/*.desktop"):
            info = parse_desktop(f)
            if not info or info["name"] in seen:
                continue
            seen.add(info["name"])
            apps.append({
                "type": "app",
                "name": info["name"],
                "detail": info["exec"],
                "exec": info["exec"],
                "icon": "󰣆",
                "iconPath": find_icon_path(info["icon"]),
            })
    apps.sort(key=lambda x: x["name"].lower())
    if _icon_cache_dirty:
        _save_icon_cache()
    print(json.dumps(apps))
    sys.exit(0)


# ── Calculadora — eval seguro via ast ────────────────────────────────────
calc_re = re.compile(r"^[\d\s+\-*/().^%,]+$")

_SAFE_OPS = {
    ast.Add:      operator.add,
    ast.Sub:      operator.sub,
    ast.Mult:     operator.mul,
    ast.Div:      operator.truediv,
    ast.Mod:      operator.mod,
    ast.Pow:      operator.pow,
    ast.USub:     operator.neg,
    ast.UAdd:     operator.pos,
    ast.FloorDiv: operator.floordiv,
}


def _safe_eval(node):
    """Evalúa un AST numérico sin ejecutar código arbitrario."""
    if isinstance(node, ast.Expression):
        return _safe_eval(node.body)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.BinOp) and type(node.op) in _SAFE_OPS:
        left  = _safe_eval(node.left)
        right = _safe_eval(node.right)
        return _SAFE_OPS[type(node.op)](left, right)
    if isinstance(node, ast.UnaryOp) and type(node.op) in _SAFE_OPS:
        return _SAFE_OPS[type(node.op)](_safe_eval(node.operand))
    raise ValueError(f"Operación no permitida: {type(node).__name__}")


if calc_re.match(query) and query and any(c.isdigit() for c in query):
    try:
        expr = query.replace("^", "**").replace(",", ".")
        tree = ast.parse(expr, mode="eval")
        val  = _safe_eval(tree)
        if isinstance(val, float) and val == int(val):
            val = int(val)
        results.append({
            "type": "calc",
            "name": f"= {val}",
            "detail": "Copiar resultado al portapapeles",
            "exec": f"wl-copy {val}",
            "icon": "󰃬",
            "iconPath": "",
        })
    except Exception:
        pass


# ── Aplicaciones ────────────────────────────────────────────────────────
if query_low:
    apps = []
    seen: set = set()
    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(f"{d}/*.desktop"):
            info = parse_desktop(f)
            if not info or info["name"] in seen:
                continue
            seen.add(info["name"])
            extra = " ".join(filter(None, [info["generic"], info["keywords"]]))
            score = fuzzy_score(query_low, info["name"], extra)
            if score == 0:
                continue
            apps.append({
                "type": "app",
                "name": info["name"],
                "detail": info["exec"],
                "exec": info["exec"],
                "icon": "󰣆",
                "iconPath": find_icon_path(info["icon"]),
                "_score": score,
            })
    apps.sort(key=lambda x: (-x["_score"], x["name"].lower()))
    for a in apps[:10]:
        a.pop("_score")
        results.append(a)


# ── Archivos / carpetas (fd) ─────────────────────────────────────────────
if query_low and len(query_low) >= 2 and len(results) < 12:
    try:
        res = subprocess.run(
            [
                "fd", "--max-results", "6", "--color", "never",
                "--max-depth", "6",
                "--exclude", ".git",
                "--exclude", ".cache",
                "--exclude", ".icons",
                "--exclude", ".local/share/icons",
                "--exclude", "node_modules",
                query, os.path.expanduser("~"),
            ],
            capture_output=True, text=True, timeout=2,
        )
        for line in res.stdout.strip().splitlines():
            path = line.strip()
            if not path:
                continue
            name = os.path.basename(path)
            is_dir = os.path.isdir(path)
            short_path = path.replace(os.path.expanduser("~"), "~")
            results.append({
                "type": "file",
                "name": name,
                "detail": short_path,
                "exec": f"xdg-open {path!r}",
                "icon": "󰉋" if is_dir else "󰈙",
                "iconPath": "",
            })
    except Exception:
        pass


# ── Comando de shell ─────────────────────────────────────────────────────
# execArgs pasa la lista directamente a Quickshell para evitar injection via bash -c
if query and not calc_re.match(query):
    results.append({
        "type": "cmd",
        "name": query,
        "detail": "Ejecutar en terminal",
        "exec": "",   # obsoleto — usar execArgs
        "execArgs": ["kitty", "--hold", "-e", "bash", "-c", query],
        "icon": "󰆍",
        "iconPath": "",
    })

if _icon_cache_dirty:
    _save_icon_cache()

print(json.dumps(results[:15]))

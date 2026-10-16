#!/bin/bash
# Installed into <project_root>/bin/ by the prototype plugin's setup.sh.
# Edit the plugin copy (prototype/skills/prototype/scripts/), not the installed one.
#
# proto-status.sh — single-source-of-truth helper for mutating _prototype/<slug>/status.yaml
#
# Usage:
#   proto-status.sh init <artifact_dir> feature=<name> slug=<slug> scope=<scope> [key=value ...]
#   proto-status.sh set  <artifact_dir> <key=value> [<key=value> ...]
#       Nested keys via dots: completed.spec=true  cycles.build+=1  worktree.path=/x
#       "updated" is stamped automatically unless you pass it.
#   proto-status.sh get  <artifact_dir> <key>
#       Prints the value; exit 1 if the key is missing.
#   proto-status.sh check-cap <artifact_dir> <layer>
#       Exit 0 if cycles.<layer> < caps.<layer> (or cap is 0 = unlimited), else exit 1
#       and print "cap reached: <layer> <cycles>/<cap>".
#   proto-status.sh note <artifact_dir> "<text>"
#       Appends a dated line to the multi-line `notes` block.
#
# Block scalars (`notes: |`) are preserved across set/note. No other YAML features
# (anchors, flow style, lists) are supported — keep status.yaml flat and simple.

set -euo pipefail

PYTHON_CMD=$(command -v python3 || command -v python)
if [ -z "$PYTHON_CMD" ]; then
  echo "proto-status: python3 not found" >&2
  exit 2
fi

run_py() {
  "$PYTHON_CMD" - "$@" <<'PY'
import os, sys, datetime

class Block(str):
    """A literal block scalar (`key: |`). Subclass of str so get() prints it."""

def parse_yaml(text):
    root = {}
    stack = [(0, root)]
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1; continue
        indent = len(line) - len(line.lstrip())
        while len(stack) > 1 and indent < stack[-1][0]:
            stack.pop()
        body = line.strip()
        if ":" not in body:
            i += 1; continue
        k, _, v = body.partition(":")
        k = k.strip(); v = v.strip()
        parent = stack[-1][1]
        if v == "|":
            # literal block: consume following lines indented deeper than this key
            buf = []
            i += 1
            while i < len(lines):
                nxt = lines[i]
                if nxt.strip() == "":
                    buf.append(""); i += 1; continue
                nindent = len(nxt) - len(nxt.lstrip())
                if nindent <= indent:
                    break
                buf.append(nxt[indent + 2:] if nindent >= indent + 2 else nxt.strip())
                i += 1
            while buf and buf[-1] == "":
                buf.pop()
            parent[k] = Block("\n".join(buf))
            continue
        if v == "":
            parent[k] = {}
            stack.append((indent + 2, parent[k]))
        else:
            parent[k] = coerce(v)
        i += 1
    return root

def coerce(v):
    lv = v.lower()
    if lv == "true": return True
    if lv == "false": return False
    if lv == "null" or lv == "~": return None
    try: return int(v)
    except ValueError: pass
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v

def dump_scalar(v):
    if v is None: return "null"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return str(v)
    s = str(v)
    if s == "" or s.strip() != s or ":" in s or s[0] in "#-[]{}&*!|>'\"%@`" or s.lower() in ("true","false","null","~"):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s

def dump_yaml(d, indent=0):
    out = []
    pad = "  " * indent
    for k, v in d.items():
        if isinstance(v, dict):
            out.append(f"{pad}{k}:")
            if v: out.append(dump_yaml(v, indent + 1))
        elif isinstance(v, Block):
            out.append(f"{pad}{k}: |")
            for line in str(v).split("\n"):
                out.append(f"{pad}  {line}" if line else "")
        else:
            out.append(f"{pad}{k}: {dump_scalar(v)}")
    return "\n".join(out)

def get_path(d, dotted):
    cur = d
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur: return None
        cur = cur[part]
    return cur

def set_path(d, dotted, value):
    parts = dotted.split(".")
    cur = d
    for p in parts[:-1]:
        if p not in cur or not isinstance(cur[p], dict): cur[p] = {}
        cur = cur[p]
    cur[parts[-1]] = value

def schema_default():
    return {
        "feature": "", "slug": "", "created": "", "updated": "",
        "scope": "new-widget", "phase": "idea",
        "project_root": "", "time_budget_min": 0,
        "completed": {"brainstorm": False, "spec": False, "spec_review": False,
                      "design": False, "design_review": False, "distill": False,
                      "build": False, "demo": False, "qa": False},
        "cycles": {"spec": 0, "design": 0, "build": 0, "infra": 0, "distill": 0, "qa_runs": 0},
        "caps": {"spec": 1, "design": 2, "build": 3, "infra": 0, "distill": 1, "demo_fix_rounds": 2},
        "worktree": {"path": None, "branch": None, "base": None},
        "blocked_on": None, "last_actor": "prototype-coordinator",
    }

try:
    now = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
except AttributeError:
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

cmd = sys.argv[1]; artifact_dir = sys.argv[2]
status_path = os.path.join(artifact_dir, "status.yaml")

def save(data):
    with open(status_path, "w") as f:
        f.write(dump_yaml(data) + "\n")

if cmd == "init":
    if os.path.exists(status_path):
        sys.stderr.write(f"proto-status: {status_path} already exists\n"); sys.exit(2)
    os.makedirs(artifact_dir, exist_ok=True)
    data = schema_default(); data["created"] = now; data["updated"] = now
    for kv in sys.argv[3:]:
        if "+=" in kv:
            sys.stderr.write("proto-status init: increment not allowed\n"); sys.exit(2)
        k, _, v = kv.partition("="); set_path(data, k, coerce(v))
    save(data); print(status_path); sys.exit(0)

if not os.path.exists(status_path):
    sys.stderr.write(f"proto-status: {status_path} not found (run init first)\n"); sys.exit(2)
with open(status_path) as f:
    data = parse_yaml(f.read())

if cmd == "get":
    val = get_path(data, sys.argv[3])
    if val is None: sys.exit(1)
    print(val); sys.exit(0)

if cmd == "set":
    has_updated = False
    for kv in sys.argv[3:]:
        if "+=" in kv:
            k, _, v = kv.partition("+="); cur = get_path(data, k) or 0
            set_path(data, k, int(cur) + int(v))
        else:
            k, _, v = kv.partition("=")
            if k == "updated": has_updated = True
            set_path(data, k, coerce(v))
    if not has_updated: data["updated"] = now
    save(data); sys.exit(0)

if cmd == "check-cap":
    layer = sys.argv[3]
    cyc = get_path(data, f"cycles.{layer}") or 0
    cap = get_path(data, f"caps.{layer}")
    if cap is None: cap = 0
    if cap == 0 or int(cyc) < int(cap): sys.exit(0)
    print(f"cap reached: {layer} {cyc}/{cap}"); sys.exit(1)

if cmd == "note":
    text = " ".join(sys.argv[3:]).strip()
    prev = data.get("notes")
    body = (str(prev) + "\n") if isinstance(prev, Block) and str(prev) else ""
    data["notes"] = Block(body + f"- {now[:10]} {text}")
    data["updated"] = now
    save(data); sys.exit(0)

sys.stderr.write(f"proto-status: unknown command '{cmd}'\n"); sys.exit(2)
PY
}

if [ $# -lt 2 ]; then
  echo "Usage: proto-status.sh {init|set|get|check-cap|note} <artifact_dir> [args...]" >&2
  exit 2
fi

run_py "$@"

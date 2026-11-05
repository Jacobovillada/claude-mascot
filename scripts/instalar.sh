#!/bin/sh
# Instala la mascota: la compila, la arranca con el Mac y conecta los hooks de Claude Code.
# Se puede correr las veces que quieras: no duplica nada.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$DIR/scripts/construir.sh"
chmod +x "$DIR/scripts/avisar.sh"

# Arranque con el Mac. KeepAlive la levanta si se cae; si sale sola (ya había otra) no insiste.
PLIST="$HOME/Library/LaunchAgents/io.github.mascota-claude.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>io.github.mascota-claude</string>
  <key>ProgramArguments</key><array><string>$HOME/Applications/Mascota Claude.app/Contents/MacOS/Mascota</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
XML
launchctl bootout "gui/$(id -u)/io.github.mascota-claude" 2>/dev/null || true
pkill -f "Mascota Claude.app/Contents/MacOS/Mascota" 2>/dev/null || true
sleep 0.5
launchctl bootstrap "gui/$(id -u)" "$PLIST"

# Hooks en ~/.claude/settings.json (con respaldo). Quita los de una instalación anterior.
python3 - "$DIR/scripts/avisar.sh" <<'PY'
import json, os, shutil, sys, time
avisar = sys.argv[1]
p = os.path.expanduser("~/.claude/settings.json")
s = json.load(open(p)) if os.path.exists(p) else {}
if os.path.exists(p):
    shutil.copy(p, p + ".bak-mascota-" + time.strftime("%Y%m%d-%H%M%S"))
h = s.setdefault("hooks", {})
def es_mascota(x): return "mascota-claude" in x.get("command", "") and "avisar.sh" in x.get("command", "")
for grupos in h.values():
    for g in grupos: g["hooks"] = [x for x in g.get("hooks", []) if not es_mascota(x)]
    grupos[:] = [g for g in grupos if g["hooks"]]
def poner(evento, ev, matcher=None):
    g = {"hooks": [{"type": "command", "command": f'"{avisar}" {ev}', "timeout": 5, "async": True}]}
    if matcher: g["matcher"] = matcher
    h.setdefault(evento, []).append(g)
poner("Stop", "stop")
poner("Notification", "notificacion")
poner("PreToolUse", "pregunta", "AskUserQuestion|ExitPlanMode|mcp__ccd_turn__wrap_up")
poner("PostToolUse", "listo", "AskUserQuestion|ExitPlanMode")
poner("UserPromptSubmit", "listo")
for k in [k for k, v in h.items() if not v]: del h[k]
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(s, open(p, "w"), indent=2, ensure_ascii=False)
print("hooks conectados en", p)
PY
echo "listo. Prueba:  curl -s -X POST -d '{}' http://127.0.0.1:4956/prueba"

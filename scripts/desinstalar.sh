#!/bin/sh
# Quita la mascota: el arranque con el Mac, la app y sus hooks (deja respaldo del settings.json).
launchctl bootout "gui/$(id -u)/io.github.mascota-claude" 2>/dev/null || true
pkill -f "Mascota Claude.app/Contents/MacOS/Mascota" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/io.github.mascota-claude.plist"
rm -rf "$HOME/Applications/Mascota Claude.app"
python3 - <<'PY'
import json, os, shutil, time
p = os.path.expanduser("~/.claude/settings.json")
if os.path.exists(p):
    shutil.copy(p, p + ".bak-mascota-" + time.strftime("%Y%m%d-%H%M%S"))
    s = json.load(open(p)); h = s.get("hooks", {})
    for grupos in h.values():
        for g in grupos: g["hooks"] = [x for x in g.get("hooks", []) if "mascota-claude" not in x.get("command", "")]
        grupos[:] = [g for g in grupos if g["hooks"]]
    for k in [k for k, v in h.items() if not v]: del h[k]
    json.dump(s, open(p, "w"), indent=2, ensure_ascii=False)
PY
echo "mascota quitada"

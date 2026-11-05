#!/bin/sh
# Hook de Claude Code: le pasa el aviso a la mascota.
# Uso: avisar.sh <stop|pregunta|notificacion|listo>   (el JSON del hook llega por stdin)
# Sale siempre en 0 y en silencio: un hook que falla no puede estorbar la sesión.
EVENTO="$1"
CUERPO=$(cat)
REG="$HOME/Library/Logs/mascota-claude.log"
echo "$(date "+%F %T") hook $EVENTO" >> "$REG"
mandar() { printf '%s' "$CUERPO" | curl -s -m 2 -X POST --data-binary @- "http://127.0.0.1:4956/$EVENTO" >/dev/null 2>&1; }
if ! mandar && [ "$EVENTO" != "listo" ]; then
  # La mascota no contestaba: se abre (si ya estaba abierta, no pasa nada) y se repite el aviso.
  echo "$(date "+%F %T") la mascota no contestaba, la abro" >> "$REG"
  open -g "$HOME/Applications/Mascota Claude.app" && sleep 1.5 && mandar
fi
exit 0

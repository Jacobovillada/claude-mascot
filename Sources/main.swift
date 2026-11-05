// Mascota de Claude: un muñeco flotante que aparece encima de cualquier ventana cuando una
// sesión de Claude Code te necesita (te hizo una pregunta, pide permiso o terminó).
//
// Los hooks de Claude Code le avisan por HTTP local (scripts/avisar.sh → 127.0.0.1:4956).
//
//   main.swift            arranque
//   Config.swift          constantes, colores y ~/.config/mascota-claude/config.json
//   Servidor.swift        el puerto local que escucha a los hooks
//   Avisos.swift          qué hacer con cada aviso
//   Conversaciones.swift  lo que se lee de la app de Claude y de las transcripciones
//   Control.swift         la ventana: mostrar, esconder y que se vea donde estás
//   Vista.swift           el muñeco, su computador y el globo
//   Registro.swift        la bitácora en ~/Library/Logs/mascota-claude.log

import AppKit

let app = NSApplication.shared
let control = Control()
app.delegate = control
app.setActivationPolicy(.accessory)
app.run()

// Qué hacer con cada aviso de los hooks: mostrarlo, quitarlo o callarse (y por qué).
//
// Cada aviso pasa por dos pasos. Primero se lee del disco lo que haga falta, en una cola aparte y
// en orden de llegada (así un "respondiste" nunca se adelanta al "terminó" de antes). Después se
// decide en la cola principal, que es la única que toca la ventana.

import AppKit

struct Aviso {
    let sesion: String
    let titulo: String
    let detalle: String
    let proyecto: String
    var simbolo = "!" // "?" si espera una respuesta tuya
    let fecha = Date()
}

/// Un aviso de hook con lo que se leyó del disco para decidir.
struct Evento {
    let ruta: String
    let j: [String: Any]
    let sesion: String
    let alFrente: String
    let proyecto: String
    let conversacionAbierta: String?
    let ultimo: Conversaciones.Ultimo?
}

private let colaDisco = DispatchQueue(label: "mascota.disco") // en serie: respeta el orden

func prepararEvento(_ ruta: String, _ j: [String: Any], listo: @escaping (Evento) -> Void) {
    // La app del frente se mira al llegar, no cuando termine de leer.
    let alFrente = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
    colaDisco.async {
        let sesion = j["session_id"] as? String ?? "?"
        var proyecto = proyectoDe(j["cwd"] as? String)
        var abierta: String?
        var ultimo: Conversaciones.Ultimo?
        if ruta != "/listo" {
            // En el globo va el proyecto y el título de la conversación, para saber cuál es antes del clic.
            if let t = Conversaciones.de(sesion)?.titulo, !t.isEmpty, t.caseInsensitiveCompare(proyecto) != .orderedSame {
                proyecto += " · " + t
            }
            if alFrente == Config.claudeApp && (ruta == "/stop" || ruta == "/notificacion") { abierta = Conversaciones.abierta() }
            if ruta == "/stop" { ultimo = Conversaciones.ultimoMensaje(j["transcript_path"] as? String) }
        }
        let e = Evento(ruta: ruta, j: j, sesion: sesion, alFrente: alFrente, proyecto: proyecto,
                       conversacionAbierta: abierta, ultimo: ultimo)
        DispatchQueue.main.async { listo(e) }
    }
}

extension Control {
    func atender(_ e: Evento) {
        let sesion = e.sesion, proyecto = e.proyecto, j = e.j
        anotar("\(e.ruta) sesion=\(sesion.prefix(8)) al frente=\(e.alFrente)")
        // "Lo estás viendo" = Claude al frente Y esa es la conversación abierta. En otra pestaña sí avisa.
        let laEstasViendo = e.alFrente == Config.claudeApp && (e.conversacionAbierta.map { $0 == sesion } ?? true)

        switch e.ruta {
        case "/pregunta": // PreToolUse: AskUserQuestion, ExitPlanMode o el recuadro de la app
            let entrada = j["tool_input"] as? [String: Any]
            switch j["tool_name"] as? String {
            case "mcp__ccd_turn__wrap_up":
                guard let q = entrada?["ask"] as? String, !q.isEmpty else { return }
                mostrar(Aviso(sesion: sesion, titulo: "Claude te hizo una pregunta", detalle: recortar(q, 110), proyecto: proyecto, simbolo: "?"))
            case "ExitPlanMode":
                mostrar(Aviso(sesion: sesion, titulo: "Claude tiene un plan", detalle: "Está esperando que lo revises para arrancar.", proyecto: proyecto, simbolo: "?"))
            default:
                let q = ((entrada?["questions"] as? [[String: Any]])?.first?["question"] as? String) ?? "Te hizo una pregunta."
                mostrar(Aviso(sesion: sesion, titulo: "Claude te hizo una pregunta", detalle: recortar(q, 110), proyecto: proyecto, simbolo: "?"))
            }

        case "/notificacion":
            let tipo = j["notification_type"] as? String ?? ""
            let msg = j["message"] as? String ?? ""
            if tipo == "permission_prompt" || msg.lowercased().contains("permission") {
                let herramienta = msg.components(separatedBy: " use ").last.map { $0 == msg ? "" : " para usar \($0)" } ?? ""
                mostrar(Aviso(sesion: sesion, titulo: "Claude necesita tu permiso", detalle: "Te está pidiendo permiso\(herramienta).", proyecto: proyecto))
            } else {
                // "Lleva rato esperando": no insistir si ya lo atendiste, si lo estás viendo o si ya hay aviso.
                if descartadas.contains(sesion) || laEstasViendo || vista.avisos.contains(where: { $0.sesion == sesion }) { return }
                mostrar(Aviso(sesion: sesion, titulo: "Claude te está esperando", detalle: "Lleva un rato esperando tu respuesta.", proyecto: proyecto))
            }

        case "/stop":
            descartadas.remove(sesion)
            // Si acaba de hacerte una pregunta, el aviso de la pregunta se queda: dice más.
            if let previo = vista.avisos.first(where: { $0.sesion == sesion }), previo.simbolo == "?", -previo.fecha.timeIntervalSinceNow < 600 {
                anotar("  dejo la pregunta que ya estaba"); return
            }
            if laEstasViendo { anotar("  no lo muestro: estás viendo esa conversación"); return }
            guard case .dijo(let dicho)? = e.ultimo else { anotar("  no lo muestro: tarea programada"); return }
            mostrar(Aviso(sesion: sesion, titulo: "Claude te necesita", detalle: recortar(dicho ?? "Terminó y te toca a ti.", 110), proyecto: proyecto))

        case "/listo": // le respondiste en esa sesión (o tomó un mensaje que tenías en cola)
            quitar(sesion)

        case "/prueba":
            let fija = (j["fija"] as? Bool) == true
            mostrar(Aviso(sesion: fija ? "prueba-fija" : "prueba-\(Int(Date().timeIntervalSince1970))",
                          titulo: fija ? "Prueba de la mascota" : "Claude te necesita",
                          detalle: fija ? "Estoy revisando que salga encima de todo. No la toques." : "Así se ve el aviso. Haz clic y te llevo a Claude.",
                          proyecto: "Prueba"))

        default:
            break
        }
    }
}

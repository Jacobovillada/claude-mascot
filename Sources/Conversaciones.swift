// Todo lo que se lee del disco: qué conversación de la app es cada sesión, cuál tienes abierta y
// qué fue lo último que dijo Claude. Se llama desde la cola de avisos, nunca desde la principal.

import Foundation

struct Conversacion {
    let local: String  // id de la app: local_<uuid>
    let titulo: String
}

enum Conversaciones {
    // Se usa desde la cola de avisos y desde la principal (al hacer clic).
    private static var cache: [String: Conversacion] = [:]
    private static let cerrojo = NSLock()

    private static func archivos() -> [String] {
        guard let recorrido = FileManager.default.enumerator(atPath: Config.dirSesiones) else { return [] }
        return recorrido.compactMap { $0 as? String }
            .filter { $0.hasSuffix(".json") && ($0 as NSString).lastPathComponent.hasPrefix("local_") }
            .map { (Config.dirSesiones as NSString).appendingPathComponent($0) }
    }

    /// Cada local_<id>.json guarda el cliSessionId, que es el session_id que recibe el hook.
    static func de(_ sesion: String) -> Conversacion? {
        cerrojo.lock(); let guardada = cache[sesion]; cerrojo.unlock()
        if let guardada { return guardada }
        let aguja = Data(sesion.utf8)
        for ruta in archivos() {
            guard let datos = FileManager.default.contents(atPath: ruta), datos.range(of: aguja) != nil,
                  let j = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
                  j["cliSessionId"] as? String == sesion, let local = j["sessionId"] as? String else { continue }
            let c = Conversacion(local: local, titulo: j["title"] as? String ?? "")
            cerrojo.lock(); cache[sesion] = c; cerrojo.unlock()
            return c
        }
        return nil
    }

    /// La que tienes abierta: la de lastFocusedAt más reciente, entre las tocadas en el último día.
    static func abierta() -> String? {
        let hace1dia = Date().addingTimeInterval(-86_400)
        var mejor: (foco: Double, sesion: String)?
        for ruta in archivos() {
            guard let mod = (try? FileManager.default.attributesOfItem(atPath: ruta))?[.modificationDate] as? Date, mod > hace1dia,
                  let datos = FileManager.default.contents(atPath: ruta),
                  let j = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
                  let foco = j["lastFocusedAt"] as? Double, let cli = j["cliSessionId"] as? String else { continue }
            if mejor == nil || foco > mejor!.foco { mejor = (foco, cli) }
        }
        return mejor?.sesion
    }

    enum Ultimo {
        case dijo(String?)
        case tareaProgramada
    }

    /// Lo último que dijo Claude. Si la sesión nunca la abrió una persona (una tarea programada),
    /// no se avisa. Un turno que arrancó porque terminó un agente en segundo plano SÍ avisa.
    static func ultimoMensaje(_ ruta: String?) -> Ultimo {
        guard let ruta, let todo = FileManager.default.contents(atPath: ruta) else { return .dijo(nil) }
        let tieneOrigen = todo.range(of: Data("\"origin\":{\"kind\":".utf8)) != nil
        let tieneHumano = todo.range(of: Data("\"origin\":{\"kind\":\"human\"}".utf8)) != nil
        if tieneOrigen && !tieneHumano { return .tareaProgramada }

        let cola = todo.count > 400_000 ? todo.suffix(400_000) : todo[...]
        for linea in String(decoding: cola, as: UTF8.self).split(separator: "\n").reversed() {
            guard let r = try? JSONSerialization.jsonObject(with: Data(linea.utf8)) as? [String: Any],
                  (r["isSidechain"] as? Bool) != true, r["type"] as? String == "assistant",
                  let partes = (r["message"] as? [String: Any])?["content"] as? [[String: Any]] else { continue }
            let txt = partes.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: " ")
            if !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .dijo(txt) }
        }
        return .dijo(nil)
    }
}

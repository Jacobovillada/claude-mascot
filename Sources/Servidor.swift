// Servidor HTTP mínimo en 127.0.0.1:4956. Los hooks le mandan el JSON que reciben de Claude Code.
// El puerto también es el cerrojo: si otra copia ya lo tiene, esta se cierra. Nunca hay dos mascotas.

import Foundation
import Network

final class Servidor {
    private var oyente: NWListener?
    /// Recibe la ruta (/stop, /pregunta...) y el cuerpo. Se llama en la cola principal.
    var alRecibir: ((String, [String: Any]) -> Void)?

    func arrancar() {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: Config.puerto)
        params.allowLocalEndpointReuse = false
        guard let l = try? NWListener(using: params) else { exit(0) }
        l.stateUpdateHandler = { estado in
            if case .failed = estado { exit(0) } // ya hay otra mascota viva
        }
        l.newConnectionHandler = { [weak self] c in
            c.start(queue: .main)
            self?.leer(c, Data())
        }
        l.start(queue: .main)
        oyente = l
    }

    private func leer(_ c: NWConnection, _ acumulado: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] datos, _, fin, error in
            guard let self else { return }
            var buf = acumulado
            if let datos { buf.append(datos) }
            if let sep = buf.range(of: Data("\r\n\r\n".utf8)) {
                let cabecera = String(decoding: buf[..<sep.lowerBound], as: UTF8.self)
                let largo = cabecera.components(separatedBy: "\r\n")
                    .first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                let cuerpo = buf[sep.upperBound...]
                if cuerpo.count >= largo || fin {
                    // Se contesta primero: el hook nunca espera a que la mascota piense.
                    c.send(content: Data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".utf8),
                           completion: .contentProcessed { _ in c.cancel() })
                    let ruta = cabecera.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
                    let json = (try? JSONSerialization.jsonObject(with: Data(cuerpo))) as? [String: Any] ?? [:]
                    self.alRecibir?(ruta, json)
                    return
                }
            }
            if fin || error != nil { c.cancel(); return }
            self.leer(c, buf)
        }
    }
}

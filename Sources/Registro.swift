// Bitácora de lo que llega y lo que se decide, para saber por qué un aviso no salió.

import Foundation

private let colaRegistro = DispatchQueue(label: "mascota.registro")
private let formato: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

func anotar(_ s: String) {
    let linea = "\(formato.string(from: Date())) app \(s)\n"
    colaRegistro.async {
        if let h = FileHandle(forWritingAtPath: Config.registro) {
            h.seekToEndOfFile()
            h.write(Data(linea.utf8))
            try? h.close()
        } else {
            try? linea.write(toFile: Config.registro, atomically: true, encoding: .utf8)
        }
    }
}

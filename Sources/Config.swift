// Constantes, colores y la configuración opcional del usuario.

import AppKit
import Network

enum Config {
    static let puerto: NWEndpoint.Port = 4956
    static let claudeApp = "com.anthropic.claudefordesktop"

    static let home = NSHomeDirectory()
    /// Aquí queda lo que llega y lo que se decide. Se ve también en Consola.app.
    static let registro = home + "/Library/Logs/mascota-claude.log"
    /// La app de Claude guarda un archivo por conversación de Code en esta carpeta.
    static let dirSesiones = home + "/Library/Application Support/Claude/claude-code-sessions"
    /// Configuración propia, fuera del repo: ~/.config/mascota-claude/config.json
    static let archivoConfig = home + "/.config/mascota-claude/config.json"

    /// Nombres bonitos para los proyectos, por nombre de carpeta. Ejemplo en config.ejemplo.json.
    static let alias: [String: String] = {
        guard let datos = FileManager.default.contents(atPath: archivoConfig),
              let j = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else { return [:] }
        return j["alias"] as? [String: String] ?? [:]
    }()

    /// Sonido del sistema al darse cuenta; "" para silencio.
    static let sonido: String = {
        guard let datos = FileManager.default.contents(atPath: archivoConfig),
              let j = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else { return "Glass" }
        return j["sonido"] as? String ?? "Glass"
    }()
}

enum Color {
    static let coral = NSColor(srgbRed: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0, alpha: 1)
    static let ojo = NSColor(srgbRed: 0.10, green: 0.09, blue: 0.09, alpha: 1)
    static let globo = NSColor(srgbRed: 0.12, green: 0.115, blue: 0.11, alpha: 0.97)
    static let borde = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    static let dorado = NSColor(srgbRed: 0.91, green: 0.72, blue: 0.40, alpha: 1)
    static let carcasa = NSColor(srgbRed: 0.80, green: 0.78, blue: 0.75, alpha: 1)
    static let teclado = NSColor(srgbRed: 0.66, green: 0.64, blue: 0.61, alpha: 1)
    static let verde = NSColor(srgbRed: 0.48, green: 0.75, blue: 0.42, alpha: 1)
}

func proyectoDe(_ cwd: String?) -> String {
    let base = ((cwd ?? "") as NSString).lastPathComponent.trimmingCharacters(in: .whitespaces)
    return Config.alias[base] ?? (base.isEmpty ? "Claude Code" : base)
}

/// Texto de una línea, sin marcas de Markdown, cortado a n caracteres.
func recortar(_ s: String, _ n: Int) -> String {
    let limpio = s.replacingOccurrences(of: "[`*#>_]", with: "", options: .regularExpression)
        .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    return limpio.count > n ? String(limpio.prefix(n - 1)) + "…" : limpio
}

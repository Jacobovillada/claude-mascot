// El muñeco, su computador y el globo. Todo se dibuja a mano en pixeles, sin imágenes.
//
// La escena: el muñeco teclea en su computador; al segundo y medio se da cuenta de que te
// necesita, le sale un "!", la pantalla se pone naranja con el símbolo y salta saludando.
// Un clic te lleva a la conversación; la X la cierra; arrastrándola se queda donde la dejes.

import AppKit

final class Vista: NSView {
    // El muñeco en pixeles: C cuerpo, O ojo, B brazo. Brazos aparte para poder saludar.
    static let cuerpo = [
        "...CCCCCCCCCC...",
        "...CCCCCCCCCC...",
        "...CCOCCCCOCC...",
        "...CCOCCCCOCC...",
        "BBBCCCCCCCCCCBBB",
        "BBBCCCCCCCCCCBBB",
        "...CCCCCCCCCC...",
        "...CCCCCCCCCC...",
        "...C.C....C.C...",
        "...C.C....C.C...",
    ]
    static let px: CGFloat = 6
    static let alto: CGFloat = 124
    static let ancho: CGFloat = 470

    var avisos: [Aviso] = []
    var t: CGFloat = 0
    var alClic: (() -> Void)?
    var alCerrar: (() -> Void)?
    private var inicioArrastre: NSPoint?
    private var arrastrado = false

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var rectGlobo: NSRect { NSRect(x: 206, y: 14, width: Vista.ancho - 214, height: Vista.alto - 24) }
    var rectCerrar: NSRect { NSRect(x: rectGlobo.maxX - 24, y: rectGlobo.minY + 8, width: 16, height: 16) }

    override func draw(_ dirty: NSRect) {
        NSColor.clear.set()
        dirty.fill()
        dibujarMuneco()
        dibujarGlobo()
    }

    // La escena: el muñeco tecleando en su computador; al segundo y medio se da cuenta de que
    // te necesita, le sale un "!", la pantalla se pone naranja con el símbolo y salta saludando.
    static let alerta: CGFloat = 1.4
    static let signoPregunta = [".XXX.", "X...X", "....X", "...X.", "..X..", ".....", "..X.."]
    static let signoAlerta = ["..X..", "..X..", "..X..", "..X..", "..X..", ".....", "..X.."]
    static let lineasCodigo: [(CGFloat, Int)] = [(0.55, 0), (0.35, 1), (0.75, 2), (0.25, 1), (0.6, 0), (0.45, 2), (0.7, 1), (0.3, 0)]

    private func glifo(_ g: [String], x: CGFloat, y: CGFloat, px: CGFloat, color: NSColor) {
        color.setFill()
        for (f, linea) in g.enumerated() {
            for (c, ch) in linea.enumerated() where ch == "X" {
                NSRect(x: x + CGFloat(c) * px, y: y + CGFloat(f) * px, width: px, height: px).fill()
            }
        }
    }

    private func dibujarMuneco() {
        let simbolo = avisos.last?.simbolo ?? "?"
        let trabajando = t < Vista.alerta
        let ta = t - Vista.alerta // tiempo desde que se dio cuenta
        let saltando = !trabajando && ta < 4 * .pi / 3.2
        let salto = saltando ? abs(sin(ta * 3.2)) * 9 : 0
        let px: CGFloat = 5
        let x0: CGFloat = 12
        let suelo: CGFloat = 104
        // Redondeado a pixel entero y sin suavizado: si no, el cuerpo sale con rayas entre cuadritos.
        let y0 = (suelo - 10 * px - salto - (trabajando ? abs(sin(t * 14)) * 1.5 : 0)).rounded()
        NSGraphicsContext.current?.shouldAntialias = false
        defer { NSGraphicsContext.current?.shouldAntialias = true }

        // Sombra que se encoge cuando salta.
        let s = 1 - salto / 20
        NSColor(white: 0, alpha: 0.28 * s).setFill()
        NSBezierPath(ovalIn: NSRect(x: x0 + 40 - 34 * s, y: suelo + 2, width: 68 * s, height: 6)).fill()

        // El computador: brillo, tapa, pantalla y teclado.
        let tapa = NSRect(x: 104, y: 42, width: 76, height: 54)
        let pulso = trabajando ? 0.10 : 0.22 + 0.12 * sin(ta * 5)
        Color.coral.withAlphaComponent(pulso).setFill()
        NSBezierPath(roundedRect: tapa.insetBy(dx: -7, dy: -7), xRadius: 12, yRadius: 12).fill()
        Color.carcasa.setFill()
        NSBezierPath(roundedRect: tapa, xRadius: 5, yRadius: 5).fill()
        let pantalla = tapa.insetBy(dx: 5, dy: 5)
        let flash = trabajando ? 0 : max(0, 1 - ta / 0.35)
        NSColor(srgbRed: 0.08 + 0.77 * flash, green: 0.075 + 0.39 * flash, blue: 0.07 + 0.27 * flash, alpha: 1).setFill()
        NSRect(x: pantalla.minX, y: pantalla.minY, width: pantalla.width, height: pantalla.height).fill()
        let teclado = NSBezierPath()
        teclado.move(to: NSPoint(x: tapa.minX - 6, y: suelo + 4))
        teclado.line(to: NSPoint(x: tapa.maxX + 6, y: suelo + 4))
        teclado.line(to: NSPoint(x: tapa.maxX, y: tapa.maxY))
        teclado.line(to: NSPoint(x: tapa.minX, y: tapa.maxY))
        teclado.close()
        Color.teclado.setFill()
        teclado.fill()

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: pantalla).addClip()
        if trabajando {
            // Código que se va escribiendo, con el cursor al final.
            let colores = [Color.coral, NSColor(white: 0.85, alpha: 1), Color.verde]
            let escritas = Int(t / 0.16)
            let visibles = min(escritas, 7)
            let corrida = max(0, escritas - 7)
            for i in 0..<visibles {
                let (ancho, color) = Vista.lineasCodigo[(i + corrida) % Vista.lineasCodigo.count]
                colores[color].setFill()
                let sangria: CGFloat = (i + corrida) % 3 == 1 ? 8 : 0
                NSRect(x: pantalla.minX + 4 + sangria, y: pantalla.minY + 4 + CGFloat(i) * 6, width: (pantalla.width - 12) * ancho, height: 3).fill()
            }
            if fmod(t, 0.4) < 0.22 {
                NSColor.white.setFill()
                NSRect(x: pantalla.minX + 4, y: pantalla.minY + 4 + CGFloat(visibles) * 6, width: 4, height: 4).fill()
            }
        } else {
            // El símbolo grande, que rebota y late.
            let g = simbolo == "!" ? Vista.signoAlerta : Vista.signoPregunta
            let gp: CGFloat = 5
            let rebote = ta < 0.3 ? -sin(ta / 0.3 * .pi) * 5 : sin(ta * 4) * 1.5
            glifo(g, x: pantalla.midX - 2.5 * gp, y: pantalla.midY - 3.5 * gp + rebote, px: gp, color: flash > 0.5 ? .white : Color.coral)
        }
        NSGraphicsContext.restoreGraphicsState()

        // El muñeco. Tecleando mira a la pantalla; después te mira a ti.
        let mirada = trabajando ? 1 : 0
        for (fila, linea) in Vista.cuerpo.enumerated() {
            for (col, c) in linea.enumerated() {
                var y = y0 + CGFloat(fila) * px
                var x = x0 + CGFloat(col) * px
                switch c {
                case "C", "O": Color.coral.setFill()
                case "B":
                    Color.coral.setFill()
                    if trabajando {
                        // El brazo de afuera queda tras el cuerpo; el otro estirado al teclado, tecleando.
                        if col < 3 { continue }
                        x += px * 2
                        if sin(t * 22) > 0 { y += px }
                    } else if col > 12 && saltando && sin(ta * 9) > 0 {
                        y -= px * 2 // saluda
                    }
                default: continue
                }
                NSRect(x: x, y: y, width: px, height: px).fill()
            }
        }
        let parpadea = !trabajando && fmod(ta, 3.4) > 3.26
        if !parpadea {
            Color.ojo.setFill()
            for col in [5, 10] {
                NSRect(x: x0 + CGFloat(col + mirada) * px, y: y0 + 2 * px, width: px, height: 2 * px).fill()
            }
        }

        // El "!" que le sale en la cabeza, con chispas al aparecer.
        if !trabajando {
            let esc = min(1, ta / 0.12) * (ta < 0.25 ? 1.25 : 1)
            let ip = 4 * esc
            let cx = x0 + 40
            let arriba = y0 - 8 - 7 * ip + sin(ta * 5) * 1.5
            glifo(Vista.signoAlerta, x: cx - 2.5 * ip, y: arriba, px: ip, color: Color.dorado)
            if ta < 0.5 {
                let d = 10 + ta * 60
                Color.dorado.withAlphaComponent(1 - ta / 0.5).setFill()
                for k in 0..<6 {
                    let ang = CGFloat(k) * .pi / 3 + 0.5
                    NSRect(x: cx + cos(ang) * d - 2, y: arriba + 14 + sin(ang) * d - 2, width: 4, height: 4).fill()
                }
            }
        }
    }

    private func dibujarGlobo() {
        guard let a = avisos.last else { return }
        let g = rectGlobo
        let forma = NSBezierPath(roundedRect: g, xRadius: 14, yRadius: 14)
        // Colita hacia el muñeco.
        forma.move(to: NSPoint(x: g.minX + 1, y: g.midY - 9))
        forma.line(to: NSPoint(x: g.minX - 9, y: g.midY))
        forma.line(to: NSPoint(x: g.minX + 1, y: g.midY + 9))
        Color.globo.setFill()
        forma.fill()
        Color.borde.setStroke()
        NSBezierPath(roundedRect: g.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14).stroke()

        let x = g.minX + 14
        let w = g.width - 46
        a.titulo.draw(with: NSRect(x: x, y: g.minY + 10, width: w, height: 20), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                      attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: Color.coral])

        var linea = a.proyecto + " · " + hace(a.fecha)
        if avisos.count > 1 { linea += " · +\(avisos.count - 1) más" }
        linea.draw(with: NSRect(x: x, y: g.minY + 30, width: g.width - 28, height: 16), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                   attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor(white: 1, alpha: 0.5)])

        a.detalle.draw(with: NSRect(x: x, y: g.minY + 49, width: g.width - 28, height: 34), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                       attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(white: 1, alpha: 0.88)])

        // La X para cerrar sin ir a Claude.
        let c = rectCerrar.insetBy(dx: 4, dy: 4)
        let xx = NSBezierPath()
        xx.move(to: c.origin); xx.line(to: NSPoint(x: c.maxX, y: c.maxY))
        xx.move(to: NSPoint(x: c.maxX, y: c.minY)); xx.line(to: NSPoint(x: c.minX, y: c.maxY))
        xx.lineWidth = 1.6
        NSColor(white: 1, alpha: 0.45).setStroke()
        xx.stroke()
    }

    private func hace(_ f: Date) -> String {
        let s = Int(-f.timeIntervalSinceNow)
        if s < 60 { return "ahora" }
        if s < 3600 { return "hace \(s / 60) min" }
        return "hace \(s / 3600) h"
    }

    // Se arrastra a donde quieras; un clic sin arrastrar te lleva a Claude.
    override func mouseDown(with e: NSEvent) {
        inicioArrastre = e.locationInWindow
        arrastrado = false
    }

    override func mouseDragged(with e: NSEvent) {
        guard let w = window, let ini = inicioArrastre else { return }
        let p = NSEvent.mouseLocation
        w.setFrameOrigin(NSPoint(x: p.x - ini.x, y: p.y - ini.y))
        arrastrado = true
    }

    var aparecio = Date()

    override func mouseUp(with e: NSEvent) {
        // Solo cuenta un clic que empezó aquí y no en el primer medio segundo: si estabas
        // haciendo clic justo donde aparece, no se la lleva sin que la veas.
        guard inicioArrastre != nil, -aparecio.timeIntervalSinceNow > 0.5 else { inicioArrastre = nil; return }
        defer { inicioArrastre = nil }
        if arrastrado {
            if let o = window?.frame.origin {
                UserDefaults.standard.set([o.x, o.y], forKey: "posicion")
            }
            return
        }
        let p = convert(e.locationInWindow, from: nil)
        if rectCerrar.insetBy(dx: -6, dy: -6).contains(p) { alCerrar?() } else { alClic?() }
    }
}

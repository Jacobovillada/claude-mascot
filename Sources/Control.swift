// La ventana flotante: mostrarla, esconderla y asegurarse de que se vea donde estás.

import AppKit

final class Control: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var vista: Vista!
    var reloj: Timer?
    var vigilante: Timer?
    let servidor = Servidor()
    var descartadas = Set<String>() // sesiones que ya atendiste: no te repite el "te está esperando"
    /// Cada vez que se muestra o se esconde sube, para que un desvanecimiento viejo no apague uno nuevo.
    private var turno = 0
    private var mostradaEn = Date.distantPast

    func applicationDidFinishLaunching(_ n: Notification) {
        vista = Vista(frame: NSRect(x: 0, y: 0, width: Vista.ancho, height: Vista.alto))
        vista.alClic = { [weak self] in self?.irAClaude() }
        vista.alCerrar = { [weak self] in self?.descartarActual("cerrado por ti") }

        panel = NSPanel(contentRect: vista.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = vista
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.alphaValue = 0

        servidor.alRecibir = { [weak self] ruta, j in
            prepararEvento(ruta, j) { self?.atender($0) }
        }
        servidor.arrancar()

        // macOS no lleva sola una ventana ya visible al escritorio de una app en pantalla completa,
        // ni la acomoda al despertar o al cambiar de pantalla. En cada uno de esos casos se reafirma.
        let ws = NSWorkspace.shared.notificationCenter
        for nombre in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification,
                       NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            ws.addObserver(forName: nombre, object: nil, queue: .main) { [weak self] _ in self?.reafirmar() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.vista.avisos.isEmpty else { return }
            self.panel.setFrameOrigin(self.posicion())
            self.reafirmar()
        }
        anotar("arranqué")
    }

    // MARK: mostrar / esconder

    func mostrar(_ a: Aviso) {
        anotar("  muestro: \(a.titulo)")
        vista.avisos.removeAll { $0.sesion == a.sesion }
        vista.avisos.append(a)
        turno += 1
        if !panel.isVisible || panel.alphaValue < 0.99 {
            if !panel.isVisible { panel.setFrameOrigin(posicion()) }
            vista.aparecio = Date()
        }
        panel.orderFrontRegardless()
        // Siempre se enciende, aunque viniera desvaneciéndose: ese era el aviso que quedaba invisible.
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; panel.animator().alphaValue = 1 }
        mostradaEn = Date()
        vista.t = 0
        if !Config.sonido.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(Vista.alerta)) { NSSound(named: Config.sonido)?.play() }
        }
        if reloj == nil {
            reloj = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.vista.t += 1.0 / 30
                self.vista.needsDisplay = true
            }
        }
        if vigilante == nil {
            vigilante = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.vigilar() }
        }
        vista.needsDisplay = true
    }

    func quitar(_ sesion: String) {
        guard vista.avisos.contains(where: { $0.sesion == sesion }) else { return }
        anotar("  escondo el aviso de \(sesion.prefix(8))")
        vista.avisos.removeAll { $0.sesion == sesion }
        if vista.avisos.isEmpty { esconder() } else { vista.needsDisplay = true }
    }

    func descartarActual(_ motivo: String) {
        guard let a = vista.avisos.last else { return }
        anotar("  \(motivo)")
        descartadas.insert(a.sesion)
        quitar(a.sesion)
    }

    func esconder() {
        reloj?.invalidate(); reloj = nil
        vigilante?.invalidate(); vigilante = nil
        turno += 1
        let miTurno = turno
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; panel.animator().alphaValue = 0 }) { [weak self] in
            // Si mientras tanto llegó otro aviso, este desvanecimiento ya no manda.
            guard let self, self.turno == miTurno, self.vista.avisos.isEmpty else { return }
            self.panel.orderOut(nil)
        }
    }

    /// Clic en la mascota: directo a la conversación que pregunta. Si la sesión no es de la app
    /// (una de terminal), solo se abre Claude.
    func irAClaude() {
        guard let sesion = vista.avisos.last?.sesion else { return }
        if let c = Conversaciones.de(sesion), let url = URL(string: "claude://code/continue?session=\(c.local)") {
            NSWorkspace.shared.open(url)
            descartarActual("clic: abro la conversación \(c.local) (\(c.titulo))")
            return
        }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: Config.claudeApp).first {
            app.activate()
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Claude.app"))
        }
        descartarActual("clic: te llevo a Claude")
    }

    // MARK: que se vea donde estás

    func reafirmar() {
        guard !vista.avisos.isEmpty else { return }
        // El cambio de escritorio tiene animación; se repite al terminar para no quedar en el de antes.
        for espera in [0.0, 0.35, 0.9] {
            DispatchQueue.main.asyncAfter(deadline: .now() + espera) { [weak self] in
                guard let self, !self.vista.avisos.isEmpty else { return }
                self.panel.alphaValue = 1
                self.panel.orderFrontRegardless()
            }
        }
    }

    /// Cada segundo, mientras haya avisos: si no se ve, se corrige y queda anotado por qué.
    func vigilar() {
        guard !vista.avisos.isEmpty, -mostradaEn.timeIntervalSinceNow > 0.6 else { return }
        var fallas: [String] = []
        if !panel.isVisible { fallas.append("estaba cerrada") }
        if panel.alphaValue < 0.99 { fallas.append("estaba transparente") }
        if !panel.isOnActiveSpace { fallas.append("estaba en otro escritorio") }
        if !NSScreen.screens.contains(where: { $0.frame.intersects(panel.frame) }) {
            fallas.append("estaba fuera de la pantalla")
            panel.setFrameOrigin(posicion())
        }
        guard !fallas.isEmpty else { return }
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        anotar("  corrijo en \(app): \(fallas.joined(separator: ", "))")
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    /// Donde la dejaste la última vez; si esa pantalla ya no está, abajo a la derecha.
    func posicion() -> NSPoint {
        if let p = UserDefaults.standard.array(forKey: "posicion") as? [CGFloat], p.count == 2 {
            let o = NSPoint(x: p[0], y: p[1])
            if NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: -20, dy: -20).contains(NSRect(origin: o, size: panel.frame.size)) }) { return o }
        }
        let v = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: v.maxX - Vista.ancho - 16, y: v.minY + 16)
    }
}

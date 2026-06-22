import AppKit

enum IconRenderer {
    static func image(for status: CodexStatus, style: IconStyle, frame: Int = 0) -> NSImage? {
        if style == .dots {
            return dots(status: status, frame: frame)
        }

        let symbol: String
        switch status {
        case .idle: symbol = "terminal"
        case .thinking: symbol = frame.isMultiple(of: 2) ? "sparkles" : "ellipsis.circle"
        case .runningCommand: symbol = "terminal.fill"
        case .editing: symbol = "pencil"
        case .reading: symbol = "doc.text.magnifyingglass"
        case .usingTool: symbol = "wrench.and.screwdriver"
        case .waitingPermission: symbol = "pause.circle.fill"
        case .complete: symbol = "checkmark.circle.fill"
        case .error: symbol = "exclamationmark.triangle.fill"
        }
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: status.defaultLabel) else { return nil }
        let configured = image.withSymbolConfiguration(.init(pointSize: 14, weight: .medium)) ?? image
        configured.isTemplate = style == .system
        if status == .waitingPermission { return tinted(configured, color: .systemYellow) }
        if status == .error { return tinted(configured, color: .systemRed) }
        if style == .green { return tinted(configured, color: .systemGreen) }
        return configured
    }

    private static func tinted(_ image: NSImage, color: NSColor) -> NSImage {
        let copy = image.copy() as! NSImage
        copy.isTemplate = false
        copy.lockFocus()
        color.set()
        NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
        copy.unlockFocus()
        return copy
    }

    private static func dots(status: CodexStatus, frame: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        let color: NSColor = status == .waitingPermission ? .systemYellow : status == .error ? .systemRed : .labelColor
        color.setFill()
        for index in 0..<3 {
            let active = !status.isActive || index == frame % 3
            let radius: CGFloat = active ? 2.3 : 1.4
            NSBezierPath(ovalIn: NSRect(x: CGFloat(index) * 5.5 + 1.5, y: 9 - radius, width: radius * 2, height: radius * 2)).fill()
        }
        image.unlockFocus()
        image.isTemplate = status != .waitingPermission && status != .error
        return image
    }
}

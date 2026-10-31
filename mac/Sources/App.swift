import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) {
        let r = NSRect(x: 200, y: 200, width: 120, height: 120)
        window = NSWindow(contentRect: r, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.contentView = TestView(frame: NSRect(origin: .zero, size: r.size))
        window.makeKeyAndOrderFront(nil)
    }
}

final class TestView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirty: NSRect) {
        NSColor(calibratedRed: 0.97, green: 0.80, blue: 0.31, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 30, y: 30, width: 60, height: 60)).fill()
    }
}

import Cocoa

class OverlayWindow: NSWindow {
    // We don't override init to avoid designated initializer issues.
    // Configuration should be done by the caller or in a setup method.
    
    override var canBecomeKey: Bool {
        return false // Overlay shouldn't take focus
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

import Cocoa

class SniperView: NSView {
    var startPoint: NSPoint?
    var shapeLayer: CAShapeLayer?
    var selectionRect: NSRect = .zero
    var onCapture: ((NSRect?) -> Void)? // Optional rect for cancellation
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    deinit {
        print("SniperView deinit")
    }
    
    private func setupLayer() {
        self.wantsLayer = true
        
        // Add Selection Layer (Border only)
        shapeLayer = CAShapeLayer()
        shapeLayer?.lineWidth = 2.0
        shapeLayer?.strokeColor = NSColor.red.cgColor
        shapeLayer?.fillColor = NSColor.clear.cgColor
        shapeLayer?.lineDashPattern = [6, 3] // Dashed line for better visibility
        
        self.layer?.addSublayer(shapeLayer!)
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        self.addCursorRect(self.bounds, cursor: .crosshair)
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow.convertToScreen()
        
        // Hide layer initially until dragged
        shapeLayer?.path = nil
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = event.locationInWindow.convertToScreen()
        
        // Calculate Rect
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        
        let screenFrame = NSRect(x: x, y: y, width: width, height: height)
        let windowRect = self.window?.convertFromScreen(screenFrame) ?? .zero
        let viewRect = self.convert(windowRect, from: nil)
        
        // Update Border Path
        let path = CGMutablePath()
        path.addRect(viewRect)
        
        shapeLayer?.path = path
        
        selectionRect = screenFrame
    }
    
    override func mouseUp(with event: NSEvent) {
        // Close window immediately
        self.window?.orderOut(nil)
        
        // Ensure valid rect
        if selectionRect.width > 10 && selectionRect.height > 10 {
            // Delay slightly to ensure window is gone from screen buffer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.onCapture?(self?.selectionRect)
            }
        } else {
            print("Selection too small/cancelled.")
            self.onCapture?(nil)
        }
        
        startPoint = nil
    }
}

class SniperWindow: NSWindow {
    
    // We proxy the verification callback to the view
    var onCapture: ((NSRect?) -> Void)? {
        get { (contentView as? SniperView)?.onCapture }
        set { (contentView as? SniperView)?.onCapture = newValue }
    }
    
    init() {
        // Create a window that covers the entire screen
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        super.init(contentRect: screenRect, styleMask: .borderless, backing: .buffered, defer: false)
        
        self.level = .screenSaver // Maximum visibility
        self.backgroundColor = .clear // Clear background
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Use our custom view
        let view = SniperView(frame: screenRect)
        self.contentView = view
        
        // Ensure we accept mouse events
        self.acceptsMouseMovedEvents = true
    }
    
    // Allow window to become key
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

extension NSPoint {
    func convertToScreen() -> NSPoint {
        let window = NSApp.keyWindow ?? NSApp.windows.first!
        return window.convertToScreen(NSRect(origin: self, size: .zero)).origin
    }
}

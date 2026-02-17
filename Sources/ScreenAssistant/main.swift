import Cocoa
import Carbon

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow?
    var sniperWindow: SniperWindow? // Keep strong reference
    var statusItem: NSStatusItem!
    let apiClient: APIClient
    
    // customizable API Key
    // In a real app, we'd store this securely. For this prototype, we'll read from env or hardcode/prompt.
    // user said "run commands to take a pic", maybe we accept a command line arg for the key?
    // or just env var.
    
    override init() {
        // Try to get API key from environment variable "GEMINI_API_KEY"
        let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "YOUR_GEMINI_API_KEY"
        self.apiClient = APIClient(apiKey: apiKey)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Status Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Screen Assistant")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Screen", action: #selector(captureAndAnalyze), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Setup Global Hotkey (Cmd+Option+S)
        setupGlobalHotkey()
        
        // Check permissions early
        if !ScreenCapture.checkPermissions() {
            print("WARNING: Screen recording permission missing.")
        }
    }
    
    // ... hotkeys ...
    func setupGlobalHotkey() {
        // Register Capture Hotkey (Cmd+Option+S)
        // cmdKey = 256, optionKey = 2048
        let modifiers = cmdKey | optionKey
        
        let captureKeyID = UInt32(kVK_ANSI_S)
        var captureHotKeyRef: EventHotKeyRef?
        let captureEventID = EventHotKeyID(signature: OSType(0x53574154), id: 1) // SWAT, 1
        RegisterEventHotKey(captureKeyID, UInt32(modifiers), captureEventID, GetApplicationEventTarget(), 0, &captureHotKeyRef)
        
        // Register Quit Hotkey (Cmd+Option+Q)
        let quitKeyID = UInt32(kVK_ANSI_Q)
        var quitHotKeyRef: EventHotKeyRef?
        let quitEventID = EventHotKeyID(signature: OSType(0x53574154), id: 2) // SWAT, 2
        RegisterEventHotKey(quitKeyID, UInt32(modifiers), quitEventID, GetApplicationEventTarget(), 0, &quitHotKeyRef)
        
        // Register Toggle Visibility Hotkey (Cmd+Option+H)
        let hideKeyID = UInt32(kVK_ANSI_H)
        var hideHotKeyRef: EventHotKeyRef?
        let hideEventID = EventHotKeyID(signature: OSType(0x53574154), id: 3) // SWAT, 3
        RegisterEventHotKey(hideKeyID, UInt32(modifiers), hideEventID, GetApplicationEventTarget(), 0, &hideHotKeyRef)
        
        // Install handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if hotKeyID.id == 1 {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.captureAndAnalyze()
                }
            } else if hotKeyID.id == 2 {
                NSApplication.shared.terminate(nil)
            } else if hotKeyID.id == 3 {
                 if let delegate = NSApp.delegate as? AppDelegate {
                     delegate.toggleOverlay()
                 }
            }
            return noErr
        }, 1, &eventType, nil, nil)
        
        print("Registered hotkeys: Cmd+Option+S (Capture), Cmd+Option+Q (Quit), Cmd+Option+H (Toggle Visibility)")
    }
    
    func toggleOverlay() {
        guard let window = overlayWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func captureAndAnalyze() {
        print("Stealth Capture Initiated...")
        
        // Check permissions first
        if !ScreenCapture.checkPermissions() {
            print("Screen recording permission missing.")
            showOverlay(with: "Permission Missing.\nPlease enable Screen Recording for Terminal/App in System Settings.", image: NSImage())
            return
        }
        
        // Hide existing overlay to allow clean capture
        overlayWindow?.orderOut(nil)
        
        // Stealth Mode: Capture immediately without activating the app
        // We do NOT activate the app, so focus remains on the browser/exam.
        
        // Slight delay to allow overlay to hide (if it was visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.processCapture(rect: .zero) // .zero or nil implies full screen in our updated logic? 
            // Wait, ScreenCapture.captureScreen(rect: nil) defaults to full screen.
            // Let's check processCapture signature. It takes NSRect.
            // I need to update processCapture to handle 'nil' or make ScreenCapture handle it.
            // Actually, currently processCapture takes (rect: NSRect).
            // Let's adjust processCapture to take optional rect or handle .zero as full screen.
        }
    }
    
    func processCapture(rect: NSRect) {
        // If rect is .zero, ScreenCapture.captureScreen uses full screen
        // We should explicitly pass nil if we want full screen, OR update ScreenCapture to treat .zero as full screen?
        // ScreenCapture.captureScreen takes CGRect? = nil. 
        // rect passed here is NSRect. If it's .zero, we probably mean full screen in this context.
        
        let captureRect: CGRect? = (rect == .zero) ? nil : rect
        
        guard let screenImage = ScreenCapture.captureScreen(rect: captureRect) else {
            print("Failed to capture screen")
            return
        }
        
        showOverlay(with: "Analyzing...", image: screenImage)
        
        guard let base64Results = ScreenCapture.toBase64(image: screenImage) else {
             updateOverlay(with: "Failed to process image.")
             return
        }
        
        apiClient.analyzeImage(base64Image: base64Results) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let result = result {
                    self.updateOverlay(with: result)
                } else {
                    self.updateOverlay(with: "Failed to get analysis.")
                }
            }
        }
    }
    
    func showOverlay(with text: String, image: NSImage) {
        if overlayWindow == nil {
             let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
             // Create window in top right corner or center
             let width: CGFloat = 500
             let height: CGFloat = 400
             let frame = NSRect(x: screenRect.maxX - width - 20, y: screenRect.maxY - height - 40, width: width, height: height)
             
            let window = OverlayWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false // Must be false to allow scrolling
            window.sharingType = .none // Key feature
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            self.overlayWindow = window
        }
        
        guard let window = overlayWindow else { return }
        
        // Create a view to display text
        let view = NSView(frame: window.contentView!.bounds)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor // Darker background for contrast
        view.layer?.cornerRadius = 12
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        
        // Scroll View
        let scrollView = NSScrollView(frame: view.bounds.insetBy(dx: 10, dy: 10))
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let textView = NSTextView(frame: scrollView.bounds)
        textView.minSize = NSSize(width: 0.0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        
        scrollView.documentView = textView
        view.addSubview(scrollView)
        
        // Markdown Rendering
        do {
            let attributedString = try NSAttributedString(markdown: text)
            let mutableString = NSMutableAttributedString(attributedString: attributedString)
            
            let range = NSRange(location: 0, length: mutableString.length)
            
            mutableString.addAttribute(.foregroundColor, value: NSColor.white, range: range)
            mutableString.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: range)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            
            textView.textStorage?.setAttributedString(mutableString)
        } catch {
            textView.string = text
            textView.textColor = .white
            textView.font = NSFont.systemFont(ofSize: 14)
        }
        

        window.contentView = view
        
        window.makeKeyAndOrderFront(nil)
    }
    
    func updateOverlay(with text: String) {
        guard let window = overlayWindow, 
              let view = window.contentView, 
              let scrollView = view.subviews.first as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView else { return }
        
        // Markdown Rendering
        // Ensure newlines behave as expected by replacing single newlines with double newlines if needed, 
        // OR rely on standard markdown rules. Gemini usually outputs valid markdown.
        // We remove the .inlineOnlyPreservingWhitespace option to allow blocks (lists, paragraphs).
        
        do {
            let attributedString = try NSAttributedString(markdown: text)
            let mutableString = NSMutableAttributedString(attributedString: attributedString)
            
            // Define global attributes
            let range = NSRange(location: 0, length: mutableString.length)
            
            // 1. Text Color
            mutableString.addAttribute(.foregroundColor, value: NSColor.white, range: range)
            
            // 2. Font
            mutableString.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: range)
            
            // 3. Paragraph Style (Line Spacing)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4 // Add some breathing room
            mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            
            textView.textStorage?.setAttributedString(mutableString)
        } catch {
            textView.string = text
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Hide from dock
app.run()

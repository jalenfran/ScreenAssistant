import Cocoa
import CoreGraphics

struct ScreenCapture {
    static func captureScreen() -> NSImage? {
        let tempPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screen_assistant_capture.png")
        
        // Remove existing file if any
        try? FileManager.default.removeItem(at: tempPath)
        
        // Interactve capture (crosshair selection)
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", tempPath.path] // -i for interactive
        task.launch()
        task.waitUntilExit()
        
        guard FileManager.default.fileExists(atPath: tempPath.path) else {
            return nil // User cancelled or failed
        }
        
        guard let image = NSImage(contentsOf: tempPath) else {
            return nil
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempPath)
        
        return image
    }
    
    static func checkPermissions() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        } else {
            // Request access (this might prompt the user)
            CGRequestScreenCaptureAccess()
            return false
        }
    }
    
    static func toBase64(image: NSImage) -> String? {
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
}

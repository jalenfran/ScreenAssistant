import Cocoa
import CoreGraphics

struct ScreenCapture {
    static func captureScreen(rect: CGRect? = nil) -> NSImage? {
        // If rect is provided, use it. Otherwise, capture main screen.
        let captureRect = rect ?? CGRect.infinite
        
        // Create an image from the screen
        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return nil
        }
        
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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

import SwiftUI
import AppKit

struct FlowUIConstants {
    // MARK: - Close Button
    static let closeButtonDiameter: CGFloat = 14.0
    static let closeButtonIconSize: CGFloat = 8.0
    
    static let closeButtonNormalOpacity: Double = 0.6
    static let closeButtonNormalBackgroundOpacity: Double = 0.08
    
    static let closeButtonHoverOpacity: Double = 1.0
    static let closeButtonHoverBackgroundOpacity: Double = 0.15
    
    static let closeButtonAnimationDuration: TimeInterval = 0.1
    
    // MARK: - AppKit Specific Colors
    static var closeButtonNormalTintColor: NSColor {
        NSColor(white: 1.0, alpha: closeButtonNormalOpacity)
    }
    
    static var closeButtonNormalBackgroundColor: CGColor {
        NSColor(white: 1.0, alpha: closeButtonNormalBackgroundOpacity).cgColor
    }
    
    static var closeButtonHoverTintColor: NSColor {
        NSColor.systemRed
    }
    
    static var closeButtonHoverBackgroundColor: CGColor {
        NSColor.systemRed.withAlphaComponent(closeButtonHoverBackgroundOpacity).cgColor
    }
}

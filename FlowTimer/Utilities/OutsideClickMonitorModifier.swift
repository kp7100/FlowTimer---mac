import SwiftUI
import AppKit

struct OutsideClickMonitorModifier: ViewModifier {
    var isActive: Bool
    var onOutsideClick: () -> Void
    
    @State private var monitor: Any?
    @State private var frame: CGRect = .zero
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            self.frame = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            self.frame = newFrame
                        }
                }
            )
            .onChange(of: isActive) { _, active in
                if active {
                    startMonitoring()
                } else {
                    stopMonitoring()
                }
            }
            .onAppear {
                if isActive {
                    startMonitoring()
                }
            }
            .onDisappear {
                stopMonitoring()
            }
    }
    
    private func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            guard let window = event.window else { return event }
            
            // In macOS, GeometryReader's .global coordinate space is relative to the window content view (top-left origin)
            // event.locationInWindow has bottom-left origin. We must convert it.
            let locationInWindow = event.locationInWindow
            
            guard let contentView = window.contentView else { return event }
            // Convert window coordinates (bottom-left) to contentView coordinates (top-left)
            let locationInView = contentView.convert(locationInWindow, from: nil)
            
            if !frame.contains(locationInView) {
                // Click is outside the view's bounds
                DispatchQueue.main.async {
                    onOutsideClick()
                }
            }
            return event
        }
    }
    
    private func stopMonitoring() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

extension View {
    /// Monitors clicks outside this view's global bounds when `isActive` is true.
    func onOutsideClick(isActive: Bool, perform action: @escaping () -> Void) -> some View {
        self.modifier(OutsideClickMonitorModifier(isActive: isActive, onOutsideClick: action))
    }
}

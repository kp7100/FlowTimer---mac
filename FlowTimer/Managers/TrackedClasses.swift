import SwiftUI
import AppKit

class TrackedWindow: NSWindow {
    deinit {}
}

class TrackedHostingController<Content: View>: NSHostingController<Content> {
    deinit {}
}

@Observable
class ViewTracker {
    let name: String
    init(name: String) {
        self.name = name
    }
    
    deinit {}
}

struct TrackedView<Content: View>: View {
    let name: String
    @State private var tracker: ViewTracker
    let content: Content
    
    init(name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self._tracker = State(wrappedValue: ViewTracker(name: name))
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

import Cocoa

class FlowCloseButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.isBordered = false
        self.title = ""
        self.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: FlowUIConstants.closeButtonIconSize, weight: .bold))
        self.wantsLayer = true
        updateAppearance()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isHovering {
            self.contentTintColor = FlowUIConstants.closeButtonHoverTintColor
            self.layer?.backgroundColor = FlowUIConstants.closeButtonHoverBackgroundColor
        } else {
            self.contentTintColor = FlowUIConstants.closeButtonNormalTintColor
            self.layer?.backgroundColor = FlowUIConstants.closeButtonNormalBackgroundColor
        }
    }
    
    override func layout() {
        super.layout()
        self.layer?.cornerRadius = bounds.width / 2
    }
}

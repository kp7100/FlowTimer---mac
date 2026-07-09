import Foundation
import Observation
import SwiftUI

class ShuffleBag<T: Equatable> {
    private let originalItems: [T]
    private var currentBag: [T] = []
    private var lastDrawn: T?
    
    init(items: [T]) {
        self.originalItems = items
        fillBag()
    }
    
    func draw() -> T {
        if currentBag.isEmpty {
            fillBag()
        }
        let item = currentBag.removeFirst()
        lastDrawn = item
        return item
    }
    
    private func fillBag() {
        var newBag = originalItems.shuffled()
        if let last = lastDrawn, let first = newBag.first, first == last, newBag.count > 1 {
            newBag.swapAt(0, 1)
        }
        currentBag = newBag
    }
}

@Observable
final class WellnessPromptProvider {
    static let shared = WellnessPromptProvider()
    
    // ... bag definitions remain unchanged
    private let wellnessBag = ShuffleBag(items: [
        "Drink some water",
        "Stretch your shoulders",
        "Blink slowly",
        "Relax your jaw",
        "Roll your shoulders",
        "Stand up for a minute",
        "Walk around a little",
        "Take five slow breaths",
        "Look 20 feet away"
    ])
    
    private let progressBag = ShuffleBag(items: [
        "One more to go.",
        "One last session.",
        "Final stretch.",
        "Almost there.",
        "Nearly done."
    ])
    
    // Memoization state
    private var currentBreakSession: Int = -1
    private var lastDrawTime: Date = .distantPast
    var currentMessage: WellnessMessage?
    
    // Shared display state
    var isPromptActive: Bool = false
    private var hideTask: Task<Void, Never>?
    
    private init() {}
    
    @MainActor
    func prompt(for context: WellnessContext) -> WellnessMessage? {
        // Long breaks have no special coaching
        guard context.phase == .shortBreak else {
            isPromptActive = false
            hideTask?.cancel()
            return nil
        }
        
        let now = Date()
        
        // If the session index is exactly the same, and it hasn't been hours, 
        // this is guaranteed to be the same break occurrence.
        // This makes us immune to unstable Date() instances from paused timers.
        let isSameBreak = (context.currentSession == currentBreakSession) && (now.timeIntervalSince(lastDrawTime) < 3600)
        
        if isSameBreak, let cached = currentMessage {
            return cached
        }
        
        // Progress moment: the short break immediately preceding the final session
        let isProgress = (context.currentSession == context.sessionsPerCycle - 1)
        
        let wellnessText = isProgress ? progressBag.draw() : wellnessBag.draw()
        let wellnessMessage = WellnessMessage(text: wellnessText, type: isProgress ? .progress : .wellness)
        
        var initialMessage = wellnessMessage
        var hasAdaptive = false
        
        if let adaptive = context.adaptivePayload {
            // Using a concise dot-separated format for optimal resizing
            let text = "\(adaptive.totalWorkMinutes)m focus • +\(adaptive.extraBreakMinutes)m break"
            initialMessage = WellnessMessage(text: text, type: .adaptiveBreak)
            hasAdaptive = true
        }
        
        // Update memoization state
        currentBreakSession = context.currentSession
        lastDrawTime = now
        currentMessage = initialMessage
        
        // Define timings
        let totalDisplayDuration: UInt64 = 35_000_000_000 // 35 seconds
        let adaptiveDisplayDuration: UInt64 = 7_000_000_000 // 7 seconds
        
        // Start the shared display sequence
        isPromptActive = true
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            if hasAdaptive {
                try? await Task.sleep(nanoseconds: adaptiveDisplayDuration)
                guard !Task.isCancelled else { return }
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.currentMessage = wellnessMessage
                }
                
                let remainingDuration = totalDisplayDuration - adaptiveDisplayDuration
                try? await Task.sleep(nanoseconds: remainingDuration)
            } else {
                try? await Task.sleep(nanoseconds: totalDisplayDuration)
            }
            
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                self?.isPromptActive = false
            }
        }
        
        return initialMessage
    }
}

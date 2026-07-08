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
    private var currentMessage: WellnessMessage?
    
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
        
        let messageText = isProgress ? progressBag.draw() : wellnessBag.draw()
        let message = WellnessMessage(text: messageText, type: isProgress ? .progress : .wellness)
        
        // Update memoization state
        currentBreakSession = context.currentSession
        lastDrawTime = now
        currentMessage = message
        
        // Start the shared 25-second display timer
        isPromptActive = true
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.isPromptActive = false
                }
            }
        }
        
        return message
    }
}

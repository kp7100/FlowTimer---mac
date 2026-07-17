import Foundation

/// An actor responsible for handling file persistence off the main thread.
/// It implements write coalescing: if multiple saves are requested rapidly,
/// it will overwrite the pending snapshot and only perform a single disk write
/// for the latest snapshot, ensuring no overlapping writes and minimal I/O.
actor HistoryPersister {
    private let fileURL: URL
    private var pendingSnapshot: [SessionRecord]?
    private var isWriting = false
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// Requests a save of the provided sessions array.
    /// - Parameter sessions: A value-copy snapshot of the history.
    func save(sessions: [SessionRecord]) {
        // Overwrite any pending snapshot with the latest one
        pendingSnapshot = sessions
        
        // If we aren't already processing writes, start the loop
        if !isWriting {
            isWriting = true
            Task {
                await processWrites()
            }
        }
    }
    
    private func processWrites() async {
        // Continue looping as long as there is a pending snapshot
        while let snapshot = pendingSnapshot {
            // Clear the pending snapshot so we know we are processing it
            pendingSnapshot = nil
            
            // Capture fileURL locally to avoid capturing `self` (the actor) in the detached task
            let url = fileURL
            
            // Perform the blocking I/O in a detached task.
            // This frees up the actor's executor so it can continue to receive
            // new `save()` calls while the disk write is occurring.
            await Task.detached(priority: .background) {
                do {
                    let data = try JSONEncoder().encode(snapshot)
                    try data.write(to: url, options: .atomic)
                } catch {
                    print("Failed to save history: \(error)")
                }
            }.value
        }
        
        // No more pending writes
        isWriting = false
    }
}

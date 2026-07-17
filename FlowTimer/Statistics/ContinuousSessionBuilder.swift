import Foundation

actor ContinuousSessionBuilder {
    private var processedCount = 0
    private var continuousSessions: [ContinuousSession] = []
    
    /// Synchronizes the builder with the latest raw records and returns the updated continuous sessions
    func sync(with records: [SessionRecord]) -> (sessions: [ContinuousSession], affectedDates: Set<Date>) {
        if records.count < processedCount {
            // History was cleared or heavily modified; full rebuild
            processedCount = 0
            continuousSessions = []
        }
        
        guard records.count > processedCount else {
            return (continuousSessions, [])
        }
        
        let newRecords = Array(records[processedCount...])
        let sortedNew = newRecords.sorted(by: { $0.startDate < $1.startDate })
        
        var affectedDates = Set<Date>()
        let calendar = Calendar.current
        
        for record in sortedNew {
            guard record.phase == .work || record.phase == .flowExtension else { continue }
            
            let recordDate = calendar.startOfDay(for: record.startDate)
            affectedDates.insert(recordDate)
            
            if let contId = record.continuationOf,
               let lastIndex = continuousSessions.lastIndex(where: { $0.constituentRecords.contains(where: { $0.id == contId }) }) {
                
                let lastSession = continuousSessions[lastIndex]
                let updatedDuration = lastSession.duration + record.duration
                let updatedPauses = lastSession.pauseCount + record.pauses
                let updatedEnd = max(lastSession.endDate, record.endDate)
                
                var updatedRecords = lastSession.constituentRecords
                updatedRecords.append(record)
                
                let isCompleted: Bool
                if let term = updatedRecords.last?.termination {
                    isCompleted = (term == .natural)
                } else {
                    isCompleted = true
                }
                
                continuousSessions[lastIndex] = ContinuousSession(
                    id: lastSession.id,
                    startDate: lastSession.startDate,
                    endDate: updatedEnd,
                    duration: updatedDuration,
                    pauseCount: updatedPauses,
                    tag: lastSession.tag,
                    isCompleted: isCompleted,
                    constituentRecords: updatedRecords
                )
            } else {
                let isCompleted: Bool
                if let term = record.termination {
                    isCompleted = (term == .natural)
                } else {
                    isCompleted = true
                }
                
                let newSession = ContinuousSession(
                    id: UUID(), // Or use record.id as the canonical ID for this session chain
                    startDate: record.startDate,
                    endDate: record.endDate,
                    duration: record.duration,
                    pauseCount: record.pauses,
                    tag: record.tag,
                    isCompleted: isCompleted,
                    constituentRecords: [record]
                )
                continuousSessions.append(newSession)
            }
        }
        
        processedCount = records.count
        return (continuousSessions, affectedDates)
    }
    
    func reset() {
        processedCount = 0
        continuousSessions = []
    }
}

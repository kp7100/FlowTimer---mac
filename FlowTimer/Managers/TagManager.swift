import Foundation
import Observation

@MainActor
@Observable
final class TagManager {
    static let shared = TagManager()
    
    private(set) var tags: [Tag] = []
    
    private let fileManager = FileManager.default
    private let fileName = "Tags.json"
    
    private var fileURL: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.flowtimer.app"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDirectory.appendingPathComponent(fileName)
    }
    
    private init() {
        loadTags()
    }
    
    func addTag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(id: UUID(), name: trimmed)
        tags.append(tag)
        saveTags()
    }
    
    func renameTag(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[index].name = trimmed
        saveTags()
    }
    
    func deleteTag(id: UUID) {
        tags.removeAll { $0.id == id }
        saveTags()
    }
    
    private func loadTags() {
        guard let url = fileURL, fileManager.fileExists(atPath: url.path) else {
            addTag(name: "Focus")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.tags = try JSONDecoder().decode([Tag].self, from: data)
            if self.tags.isEmpty {
                addTag(name: "Focus")
            }
        } catch {
            print("Failed to load tags gracefully: \(error)")
            addTag(name: "Focus")
        }
    }
    
    private func saveTags() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(tags)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save tags: \(error)")
        }
    }
}

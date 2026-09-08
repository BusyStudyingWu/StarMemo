import CoreGraphics
import Foundation

public enum NoteAppearance: String, Codable, CaseIterable, Sendable {
    case clear
    case mistBlue
    case lavender
    case warmYellow
    case graphite
}

public struct NoteWindowPreferences: Codable, Equatable, Sendable {
    public var frame: CGRect
    public var appearance: NoteAppearance
    public var opacity: Double
    public var isPinned: Bool

    public init(
        frame: CGRect,
        appearance: NoteAppearance,
        opacity: Double,
        isPinned: Bool
    ) {
        self.frame = frame
        self.appearance = appearance
        self.opacity = min(max(opacity, 0.65), 1.0)
        self.isPinned = isPinned
    }
}

public final class NotePreferencesStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "noteWindowPreferences"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public static func key(documentID: UUID, fileURL: URL?) -> String {
        if let fileURL {
            return "file:\(fileURL.standardizedFileURL.path)"
        }
        return "document:\(documentID.uuidString)"
    }

    public func save(_ preferences: NoteWindowPreferences, for key: String) {
        var values = loadValues()
        values[key] = preferences
        guard let data = try? JSONEncoder().encode(values) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    public func load(for key: String) -> NoteWindowPreferences? {
        loadValues()[key]
    }

    public func remove(for key: String) {
        var values = loadValues()
        values.removeValue(forKey: key)
        guard let data = try? JSONEncoder().encode(values) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private func loadValues() -> [String: NoteWindowPreferences] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: NoteWindowPreferences].self, from: data)) ?? [:]
    }
}

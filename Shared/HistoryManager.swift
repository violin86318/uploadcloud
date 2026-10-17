import Foundation

/// Manages upload history stored at ~/.uploadcloud/history.json
final class HistoryManager {

    static let shared = HistoryManager()

    private let historyFile: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        historyFile = home
            .appendingPathComponent(".uploadcloud")
            .appendingPathComponent("history.json")
    }

    // MARK: - Public API

    func loadAll() -> [HistoryRecord] {
        guard let data = try? Data(contentsOf: historyFile) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryRecord].self, from: data)) ?? []
    }

    func add(_ record: HistoryRecord) {
        var records = loadAll()
        records.insert(record, at: 0)          // newest first
        save(records)
    }

    func remove(id: String) {
        var records = loadAll()
        records.removeAll { $0.id == id }
        save(records)
    }

    func removeAll(ids: Set<String>) {
        var records = loadAll()
        records.removeAll { ids.contains($0.id) }
        save(records)
    }

    // MARK: - Helpers

    /// Create a new HistoryRecord from upload context.
    static func makeRecord(
        fileName: String,
        fileSize: Int64,
        objectKey: String,
        url: String,
        mode: UploadMode
    ) -> HistoryRecord {
        HistoryRecord(
            id: String(UUID().uuidString.prefix(8)).lowercased(),
            fileName: fileName,
            fileSize: fileSize,
            objectKey: objectKey,
            url: url,
            mode: mode.rawValue,
            uploadedAt: Date()
        )
    }

    // MARK: - Private

    private func save(_ records: [HistoryRecord]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }
}

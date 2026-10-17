import Foundation

/// Manages the UploadCloud configuration stored at ~/.uploadcloud/config.json
final class ConfigManager {

    static let shared = ConfigManager()

    private let configDirectory: URL
    private let configFile: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = home.appendingPathComponent(".uploadcloud")
        configFile = configDirectory.appendingPathComponent("config.json")
    }

    var configFileURL: URL { configFile }

    func configExists() -> Bool {
        FileManager.default.fileExists(atPath: configFile.path)
    }

    func load() throws -> UploadCloudConfig {
        let data = try Data(contentsOf: configFile)
        return try JSONDecoder().decode(UploadCloudConfig.self, from: data)
    }

    func save(_ config: UploadCloudConfig) throws {
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFile, options: .atomic)
    }
}

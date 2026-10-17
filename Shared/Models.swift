import Foundation

// MARK: - Configuration

struct UploadCloudConfig: Codable {
    var r2: R2Config
    var upload: UploadConfig

    static let defaultConfig = UploadCloudConfig(
        r2: R2Config(
            accountId: "",
            accessKeyId: "",
            secretAccessKey: "",
            bucketName: "uploadcloud",
            customDomain: ""
        ),
        upload: UploadConfig(presignedUrlTTL: 86400)
    )
}

struct R2Config: Codable {
    var accountId: String
    var accessKeyId: String
    var secretAccessKey: String
    var bucketName: String
    var customDomain: String

    /// S3-compatible endpoint for this R2 account
    var endpoint: String {
        "https://\(accountId).r2.cloudflarestorage.com"
    }
}

struct UploadConfig: Codable {
    /// Presigned URL time-to-live in seconds (default: 86400 = 24h)
    var presignedUrlTTL: Int
}

// MARK: - Upload

enum UploadMode: String {
    case publicAccess = "public"
    case presignedURL = "presigned"
}

struct UploadResult {
    let fileName: String
    let url: String
    let mode: UploadMode
}

// MARK: - History

struct HistoryRecord: Codable, Identifiable {
    let id: String
    let fileName: String
    let fileSize: Int64
    let objectKey: String
    let url: String
    let mode: String            // "public" or "presigned"
    let uploadedAt: Date
}


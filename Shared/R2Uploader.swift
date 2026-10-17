import Foundation
import UniformTypeIdentifiers

/// Uploads files to Cloudflare R2 via the S3-compatible API.
final class R2Uploader {

    let config: R2Config
    private let signer: AWSV4Signer
    private let session: URLSession

    init(config: R2Config) {
        self.config = config
        self.signer = AWSV4Signer(
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey
        )
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Public API

    /// Generate a date-prefixed object key with timestamp to prevent collisions:
    /// `2024/10/17/report_095612.pdf`
    static func generateObjectKey(for fileName: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        let datePath = df.string(from: Date())

        let tf = DateFormatter()
        tf.dateFormat = "HHmmss"
        tf.locale = Locale(identifier: "en_US_POSIX")
        let ts = tf.string(from: Date())

        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return ext.isEmpty
            ? "\(datePath)/\(name)_\(ts)"
            : "\(datePath)/\(name)_\(ts).\(ext)"
    }

    /// Upload a file and return its **public** URL (via custom domain).
    func upload(fileURL: URL, objectKey: String) async throws -> String {
        try await performUpload(fileURL: fileURL, objectKey: objectKey)

        let domain = config.customDomain.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let scheme = domain.hasPrefix("http") ? "" : "https://"
        let encodedKey = objectKey.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? objectKey
        return "\(scheme)\(domain)/\(encodedKey)"
    }

    /// Upload a file and return a **presigned** (temporary) GET URL.
    func uploadAndPresign(
        fileURL: URL,
        objectKey: String,
        ttl: Int
    ) async throws -> String {
        try await performUpload(fileURL: fileURL, objectKey: objectKey)

        let encodedKey = objectKey.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? objectKey
        let rawURL = "\(config.endpoint)/\(config.bucketName)/\(encodedKey)"
        guard let getURL = URL(string: rawURL) else {
            throw UploadError.invalidURL
        }
        guard let presigned = signer.presignedURL(
            for: getURL, method: "GET", expiration: ttl
        ) else {
            throw UploadError.presignFailed
        }
        return presigned.absoluteString
    }

    /// Delete an object from Cloudflare R2 via S3 DELETE API.
    func delete(objectKey: String) async throws {
        let encodedKey = objectKey.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? objectKey
        let urlString = "\(config.endpoint)/\(config.bucketName)/\(encodedKey)"
        guard let url = URL(string: urlString) else {
            throw UploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // Empty body hash for DELETE
        signer.sign(&request, payloadHash: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw UploadError.httpError(statusCode: http.statusCode)
        }
    }

    // MARK: - Internal

    private func performUpload(fileURL: URL, objectKey: String) async throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0
        let contentType = Self.mimeType(for: fileURL)

        let encodedKey = objectKey.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? objectKey
        let urlString = "\(config.endpoint)/\(config.bucketName)/\(encodedKey)"
        guard let url = URL(string: urlString) else {
            throw UploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")

        // Sign with UNSIGNED-PAYLOAD — body is streamed from disk.
        signer.sign(&request, payloadHash: "UNSIGNED-PAYLOAD")

        let (_, response) = try await session.upload(for: request, fromFile: fileURL)

        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw UploadError.httpError(statusCode: http.statusCode)
        }
    }

    /// Detect MIME type from file extension.
    static func mimeType(for url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case presignFailed
    case configNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "无效的上传 URL"
        case .invalidResponse:   return "服务器响应无效"
        case .httpError(let c):  return "上传失败 (HTTP \(c))"
        case .presignFailed:     return "生成临时链接失败"
        case .configNotFound:    return "未找到配置文件，请先打开 UploadCloud 应用进行配置"
        }
    }
}

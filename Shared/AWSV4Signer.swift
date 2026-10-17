import CryptoKit
import Foundation

/// AWS Signature Version 4 signer for S3-compatible APIs (Cloudflare R2).
struct AWSV4Signer {

    let accessKeyId: String
    let secretAccessKey: String
    let region: String
    let service: String

    init(
        accessKeyId: String,
        secretAccessKey: String,
        region: String = "auto",
        service: String = "s3"
    ) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.region = region
        self.service = service
    }

    // MARK: - Sign a URLRequest (PUT / DELETE / etc.)

    func sign(
        _ request: inout URLRequest,
        payloadHash: String = "UNSIGNED-PAYLOAD"
    ) {
        let now = Date()
        let amzDate = Self.amzDateString(from: now)
        let shortDate = String(amzDate.prefix(8))
        let credentialScope = "\(shortDate)/\(region)/\(service)/aws4_request"

        guard let url = request.url, let host = url.host else { return }

        // ── Required headers ──────────────────────────────────────────
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        // ── Canonical headers ─────────────────────────────────────────
        var headers: [(String, String)] = []
        if let all = request.allHTTPHeaderFields {
            for (k, v) in all {
                headers.append((k.lowercased(), v.trimmingCharacters(in: .whitespaces)))
            }
        }
        headers.sort { $0.0 < $1.0 }

        let signedHeaderNames = headers.map(\.0)
        let signedHeadersStr = signedHeaderNames.joined(separator: ";")
        let canonicalHeaders = headers.map { "\($0.0):\($0.1)" }.joined(separator: "\n")

        // ── Canonical request ─────────────────────────────────────────
        let method = request.httpMethod ?? "GET"
        let path = Self.uriEncodePath(url.path.isEmpty ? "/" : url.path)
        let query = Self.canonicalQueryString(from: url)

        let canonicalRequest = [
            method,
            path,
            query,
            canonicalHeaders, "",          // trailing newline after headers
            signedHeadersStr,
            payloadHash,
        ].joined(separator: "\n")

        // ── String to sign ────────────────────────────────────────────
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            Self.sha256Hex(canonicalRequest),
        ].joined(separator: "\n")

        // ── Signature ─────────────────────────────────────────────────
        let signingKey = Self.deriveSigningKey(
            secretKey: secretAccessKey,
            date: shortDate,
            region: region,
            service: service
        )
        let signature = Self.hmacSHA256Hex(key: signingKey, data: stringToSign)

        let auth = "AWS4-HMAC-SHA256 "
            + "Credential=\(accessKeyId)/\(credentialScope), "
            + "SignedHeaders=\(signedHeadersStr), "
            + "Signature=\(signature)"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
    }

    // MARK: - Presigned URL (GET)

    func presignedURL(
        for baseURL: URL,
        method: String = "GET",
        expiration: Int = 86400
    ) -> URL? {
        let now = Date()
        let amzDate = Self.amzDateString(from: now)
        let shortDate = String(amzDate.prefix(8))
        let credentialScope = "\(shortDate)/\(region)/\(service)/aws4_request"
        let credential = "\(accessKeyId)/\(credentialScope)"

        guard let host = baseURL.host else { return nil }

        // ── Query parameters (sorted) ─────────────────────────────────
        var queryItems: [(String, String)] = [
            ("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
            ("X-Amz-Credential", credential),
            ("X-Amz-Date", amzDate),
            ("X-Amz-Expires", String(expiration)),
            ("X-Amz-SignedHeaders", "host"),
        ]
        queryItems.sort { $0.0 < $1.0 }

        let canonicalQS = queryItems
            .map { "\(Self.uriEncode($0.0))=\(Self.uriEncode($0.1))" }
            .joined(separator: "&")

        // ── Canonical request ─────────────────────────────────────────
        let path = Self.uriEncodePath(baseURL.path.isEmpty ? "/" : baseURL.path)
        let canonicalRequest = [
            method,
            path,
            canonicalQS,
            "host:\(host)", "",            // canonical headers + trailing newline
            "host",
            "UNSIGNED-PAYLOAD",
        ].joined(separator: "\n")

        // ── String to sign ────────────────────────────────────────────
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            Self.sha256Hex(canonicalRequest),
        ].joined(separator: "\n")

        // ── Signature ─────────────────────────────────────────────────
        let signingKey = Self.deriveSigningKey(
            secretKey: secretAccessKey,
            date: shortDate,
            region: region,
            service: service
        )
        let signature = Self.hmacSHA256Hex(key: signingKey, data: stringToSign)

        // ── Assemble final URL ────────────────────────────────────────
        let finalQuery = canonicalQS + "&X-Amz-Signature=\(signature)"
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = finalQuery
        return components.url
    }

    // MARK: - Crypto helpers

    static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func deriveSigningKey(
        secretKey: String,
        date: String,
        region: String,
        service: String
    ) -> SymmetricKey {
        let kDate    = hmacSHA256(key: SymmetricKey(data: Data("AWS4\(secretKey)".utf8)),
                                  data: Data(date.utf8))
        let kRegion  = hmacSHA256(key: kDate,    data: Data(region.utf8))
        let kService = hmacSHA256(key: kRegion,  data: Data(service.utf8))
        let kSigning = hmacSHA256(key: kService, data: Data("aws4_request".utf8))
        return kSigning
    }

    static func hmacSHA256(key: SymmetricKey, data: Data) -> SymmetricKey {
        SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: data, using: key)))
    }

    static func hmacSHA256Hex(key: SymmetricKey, data: String) -> String {
        Data(HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - URI encoding helpers

    /// RFC 3986 percent-encoding (unreserved chars: A-Z a-z 0-9 - . _ ~)
    static func uriEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    /// Encode each path segment individually, preserving `/` separators.
    static func uriEncodePath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map { uriEncode(String($0)) }
            .joined(separator: "/")
    }

    /// Build a canonical (sorted, encoded) query string from a URL.
    static func canonicalQueryString(from url: URL) -> String {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = c.queryItems, !items.isEmpty else { return "" }
        let encoded: [(String, String)] = items.map { item in
            (uriEncode(item.name), uriEncode(item.value ?? ""))
        }
        let sorted = encoded.sorted { a, b in
            a.0 == b.0 ? a.1 < b.1 : a.0 < b.0
        }
        return sorted.map { key, val in "\(key)=\(val)" }.joined(separator: "&")
    }

    static func amzDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}

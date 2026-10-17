import AppKit
import UserNotifications

/// Provides system notifications and clipboard operations for upload feedback.
final class NotificationManager {

    /// Request notification permission (call once at extension load).
    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Notify the user about successful uploads and copy all URLs to clipboard.
    static func notifySuccess(results: [UploadResult]) {
        let urlText = results.map(\.url).joined(separator: "\n")
        copyToClipboard(urlText)

        let title: String
        let body: String
        if results.count == 1 {
            title = "☁️ 上传成功"
            body = "\(results[0].fileName)\nURL 已复制到剪贴板"
        } else {
            title = "☁️ \(results.count) 个文件上传成功"
            body = "所有 URL 已复制到剪贴板"
        }
        post(title: title, body: body, id: "upload-success")
    }

    /// Notify the user about an upload error.
    static func notifyError(message: String) {
        post(title: "❌ 上传失败", body: message, id: "upload-error")
    }

    /// Show upload progress for multi-file uploads.
    static func notifyProgress(fileName: String, current: Int, total: Int) {
        post(
            title: "☁️ 正在上传…",
            body: "\(fileName) (\(current)/\(total))",
            id: "upload-progress"
        )
    }

    /// Copy text to the system clipboard (thread-safe, synchronous).
    static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Double insurance via system pbcopy
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        if (try? process.run()) != nil {
            try? pipe.fileHandleForWriting.write(contentsOf: Data(text.utf8))
            try? pipe.fileHandleForWriting.close()
            process.waitUntilExit()
        }
    }

    // MARK: - Private

    private static func post(title: String, body: String, id: String) {
        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req) { error in
                if let error { NSLog("UploadCloud notification error: \(error)") }
            }
        } else {
            // Standalone CLI binary: post notification via AppleScript
            let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
            let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\" sound name \"default\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }
}

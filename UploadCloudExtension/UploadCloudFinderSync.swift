import Cocoa
import FinderSync

/// Finder Sync extension that adds "Upload to Cloud" items to the
/// right-click context menu in Finder.
class UploadCloudFinderSync: FIFinderSync {

    // MARK: - Lifecycle

    override init() {
        super.init()
        // Monitor the entire filesystem so the menu appears everywhere.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        NotificationManager.requestPermission()
        NSLog("UploadCloud: FinderSync extension loaded")
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "UploadCloud")

        let publicItem = NSMenuItem(
            title: "☁️ 上传到云盘（公开）",
            action: #selector(uploadPublic(_:)),
            keyEquivalent: ""
        )
        publicItem.image = NSImage(
            systemSymbolName: "icloud.and.arrow.up",
            accessibilityDescription: "Upload"
        )
        menu.addItem(publicItem)

        let presignedItem = NSMenuItem(
            title: "🔗 上传到云盘（临时链接）",
            action: #selector(uploadPresigned(_:)),
            keyEquivalent: ""
        )
        presignedItem.image = NSImage(
            systemSymbolName: "link",
            accessibilityDescription: "Temporary Link"
        )
        menu.addItem(presignedItem)

        return menu
    }

    // MARK: - Actions

    @objc func uploadPublic(_ sender: AnyObject?) {
        performUpload(mode: .publicAccess)
    }

    @objc func uploadPresigned(_ sender: AnyObject?) {
        performUpload(mode: .presignedURL)
    }

    // MARK: - Upload orchestration

    private func performUpload(mode: UploadMode) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(),
              !items.isEmpty else {
            NotificationManager.notifyError(message: "没有选中文件")
            return
        }

        // Filter out directories — only upload regular files.
        let files = items.filter { url in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                && !isDir.boolValue
        }
        guard !files.isEmpty else {
            NotificationManager.notifyError(message: "选中的项目中没有可上传的文件")
            return
        }

        Task.detached { [files, mode] in
            do {
                let config = try ConfigManager.shared.load()
                let uploader = R2Uploader(config: config.r2)
                var results: [UploadResult] = []

                for (i, fileURL) in files.enumerated() {
                    let fileName = fileURL.lastPathComponent
                    let objectKey = R2Uploader.generateObjectKey(for: fileName)

                    if files.count > 1 {
                        NotificationManager.notifyProgress(
                            fileName: fileName,
                            current: i + 1,
                            total: files.count
                        )
                    }

                    let url: String
                    switch mode {
                    case .publicAccess:
                        url = try await uploader.upload(
                            fileURL: fileURL,
                            objectKey: objectKey
                        )
                    case .presignedURL:
                        url = try await uploader.uploadAndPresign(
                            fileURL: fileURL,
                            objectKey: objectKey,
                            ttl: config.upload.presignedUrlTTL
                        )
                    }

                    results.append(UploadResult(
                        fileName: fileName,
                        url: url,
                        mode: mode
                    ))

                    // Record in history
                    let attrs = try FileManager.default.attributesOfItem(
                        atPath: fileURL.path
                    )
                    let fileSize = (attrs[.size] as? Int64) ?? 0
                    let record = HistoryManager.makeRecord(
                        fileName: fileName, fileSize: fileSize,
                        objectKey: objectKey, url: url, mode: mode
                    )
                    HistoryManager.shared.add(record)
                }

                NotificationManager.notifySuccess(results: results)

            } catch {
                NSLog("UploadCloud upload error: \(error)")
                NotificationManager.notifyError(
                    message: error.localizedDescription
                )
            }
        }
    }
}

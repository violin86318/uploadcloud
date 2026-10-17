import Foundation

@main
struct CLI {
    static func main() async {
        let args = CommandLine.arguments

        guard args.count >= 2 else { printUsage(); exit(1) }

        switch args[1] {
        case "--public":
            guard args.count >= 3 else { printUsage(); exit(1) }
            await uploadFiles(paths: Array(args.dropFirst(2)), mode: .publicAccess)
        case "--presigned":
            guard args.count >= 3 else { printUsage(); exit(1) }
            await uploadFiles(paths: Array(args.dropFirst(2)), mode: .presignedURL)
        case "--list":
            listHistory()
        case "--delete":
            guard args.count >= 3 else {
                print("Usage: uploadcloud --delete <id>")
                exit(1)
            }
            await deleteRecord(id: args[2])
        default:
            printUsage()
            exit(1)
        }
    }

    // MARK: - Upload

    private static func uploadFiles(paths: [String], mode: UploadMode) async {
        var fileURLs: [URL] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
               !isDir.boolValue {
                fileURLs.append(url)
            }
        }

        guard !fileURLs.isEmpty else {
            NotificationManager.notifyError(message: "未检测到有效的文件")
            print("Error: No valid files found.")
            exit(1)
        }

        do {
            let config = try ConfigManager.shared.load()
            let uploader = R2Uploader(config: config.r2)
            var results: [UploadResult] = []

            for (i, fileURL) in fileURLs.enumerated() {
                let fileName = fileURL.lastPathComponent
                let objectKey = R2Uploader.generateObjectKey(for: fileName)

                if fileURLs.count > 1 {
                    NotificationManager.notifyProgress(
                        fileName: fileName, current: i + 1, total: fileURLs.count
                    )
                }

                let url: String
                switch mode {
                case .publicAccess:
                    url = try await uploader.upload(fileURL: fileURL, objectKey: objectKey)
                case .presignedURL:
                    url = try await uploader.uploadAndPresign(
                        fileURL: fileURL, objectKey: objectKey,
                        ttl: config.upload.presignedUrlTTL
                    )
                }

                // Record in history
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = (attrs[.size] as? Int64) ?? 0
                let record = HistoryManager.makeRecord(
                    fileName: fileName, fileSize: fileSize,
                    objectKey: objectKey, url: url, mode: mode
                )
                HistoryManager.shared.add(record)

                results.append(UploadResult(fileName: fileName, url: url, mode: mode))
                print("Uploaded: \(url)")
            }

            NotificationManager.notifySuccess(results: results)
            print("Success! URLs copied to clipboard.")
            exit(0)
        } catch {
            NotificationManager.notifyError(message: error.localizedDescription)
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // MARK: - List

    private static func listHistory() {
        let records = HistoryManager.shared.loadAll()
        if records.isEmpty {
            print("暂无上传记录。")
            exit(0)
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        print("共 \(records.count) 条记录:\n")
        for r in records {
            let size = ByteCountFormatter.string(fromByteCount: r.fileSize, countStyle: .file)
            let mode = r.mode == "public" ? "☁️ 公开" : "🔗 临时"
            let date = df.string(from: r.uploadedAt)
            print("[\(r.id)] \(r.fileName) (\(size)) \(mode) \(date)")
            print("  → \(r.url)\n")
        }
        exit(0)
    }

    // MARK: - Delete

    private static func deleteRecord(id: String) async {
        let records = HistoryManager.shared.loadAll()
        guard let record = records.first(where: { $0.id == id }) else {
            print("❌ 未找到 ID 为 \"\(id)\" 的记录。")
            print("使用 uploadcloud --list 查看所有记录。")
            exit(1)
        }

        print("正在删除: \(record.fileName) ...")
        do {
            let config = try ConfigManager.shared.load()
            let uploader = R2Uploader(config: config.r2)
            try await uploader.delete(objectKey: record.objectKey)
            HistoryManager.shared.remove(id: id)
            print("✅ 已从云端删除: \(record.fileName)")
            print("   所有已分享的链接已立即失效。")
            exit(0)
        } catch {
            print("❌ 删除失败: \(error.localizedDescription)")
            exit(1)
        }
    }

    // MARK: - Usage

    private static func printUsage() {
        print("""
        Usage:
          uploadcloud --public <file1> [file2...]     上传文件（公开链接）
          uploadcloud --presigned <file1> [file2...]  上传文件（临时链接）
          uploadcloud --list                           查看上传历史
          uploadcloud --delete <id>                    删除云端文件
        """)
    }
}

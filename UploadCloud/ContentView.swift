import SwiftUI

struct ContentView: View {

    // MARK: - State

    @State private var accountId = ""
    @State private var accessKeyId = ""
    @State private var secretAccessKey = ""
    @State private var bucketName = "uploadcloud"
    @State private var customDomain = ""
    @State private var presignedTTL = 24
    @State private var ttlUnit: TTLUnit = .hours

    @State private var statusMessage = ""
    @State private var isError = false
    @State private var isSaving = false
    @State private var isTesting = false

    enum TTLUnit: String, CaseIterable, Identifiable {
        case hours = "小时"
        case days  = "天"
        var id: String { rawValue }
        var seconds: Int {
            switch self {
            case .hours: return 3600
            case .days:  return 86400
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            // ── Header ──────────────────────────────────────────
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UploadCloud").font(.title).fontWeight(.bold)
                        Text("Finder 右键一键上传到 Cloudflare R2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
            }

            // ── R2 Config ───────────────────────────────────────
            Section("Cloudflare R2 配置") {
                TextField("Account ID", text: $accountId)
                    .textFieldStyle(.roundedBorder)
                TextField("Access Key ID", text: $accessKeyId)
                    .textFieldStyle(.roundedBorder)
                SecureField("Secret Access Key", text: $secretAccessKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Bucket 名称", text: $bucketName)
                    .textFieldStyle(.roundedBorder)
                TextField("自定义域名（如 files.example.com）", text: $customDomain)
                    .textFieldStyle(.roundedBorder)
            }

            // ── Presigned TTL ───────────────────────────────────
            Section("临时链接设置") {
                HStack {
                    Text("过期时间")
                    TextField("", value: $presignedTTL, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Picker("", selection: $ttlUnit) {
                        ForEach(TTLUnit.allCases) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }

            // ── Actions ─────────────────────────────────────────
            Section {
                HStack(spacing: 12) {
                    Button(action: save) {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("保存配置", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(isSaving || !isFormValid)

                    Button(action: testConnection) {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("测试连接", systemImage: "network")
                        }
                    }
                    .disabled(isTesting || !isFormValid)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundStyle(isError ? .red : .green)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            // ── Instructions ────────────────────────────────────
            Section("使用说明") {
                VStack(alignment: .leading, spacing: 10) {
                    step("1", "保存上方的 R2 配置信息")
                    step("2", "前往 系统设置 → 隐私与安全性 → 扩展 → 已添加的扩展，启用 UploadCloud")
                    step("3", "在 Finder 中选中文件，右键菜单选择上传方式")
                    step("4", "上传完成后 URL 自动复制到剪贴板，直接粘贴给 AI 即可")
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 450, maxHeight: .infinity)
        .onAppear(perform: loadConfig)
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !accountId.isEmpty && !accessKeyId.isEmpty && !secretAccessKey.isEmpty
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(n)
                .font(.caption2).bold()
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func buildConfig() -> UploadCloudConfig {
        UploadCloudConfig(
            r2: R2Config(
                accountId: accountId,
                accessKeyId: accessKeyId,
                secretAccessKey: secretAccessKey,
                bucketName: bucketName,
                customDomain: customDomain
            ),
            upload: UploadConfig(
                presignedUrlTTL: presignedTTL * ttlUnit.seconds
            )
        )
    }

    private func loadConfig() {
        guard let cfg = try? ConfigManager.shared.load() else { return }
        accountId = cfg.r2.accountId
        accessKeyId = cfg.r2.accessKeyId
        secretAccessKey = cfg.r2.secretAccessKey
        bucketName = cfg.r2.bucketName
        customDomain = cfg.r2.customDomain

        let s = cfg.upload.presignedUrlTTL
        if s >= 86400, s % 86400 == 0 {
            presignedTTL = s / 86400; ttlUnit = .days
        } else {
            presignedTTL = max(1, s / 3600); ttlUnit = .hours
        }
    }

    private func save() {
        isSaving = true
        do {
            try ConfigManager.shared.save(buildConfig())
            statusMessage = "✅ 配置已保存到 ~/.uploadcloud/config.json"
            isError = false
        } catch {
            statusMessage = "❌ 保存失败: \(error.localizedDescription)"
            isError = true
        }
        isSaving = false
    }

    private func testConnection() {
        isTesting = true
        statusMessage = "正在测试连接…"
        isError = false

        let cfg = buildConfig()

        Task {
            do {
                let uploader = R2Uploader(config: cfg.r2)

                // Upload a tiny test file
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(".uploadcloud-test.txt")
                try "UploadCloud connection test — \(Date())".write(
                    to: tmp, atomically: true, encoding: .utf8
                )
                defer { try? FileManager.default.removeItem(at: tmp) }

                let url = try await uploader.upload(
                    fileURL: tmp,
                    objectKey: ".uploadcloud-test/connection-test.txt"
                )

                await MainActor.run {
                    statusMessage = "✅ 连接成功！测试文件: \(url)"
                    isError = false
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ 连接失败: \(error.localizedDescription)"
                    isError = true
                    isTesting = false
                }
            }
        }
    }
}

#Preview { ContentView() }

import SwiftUI

struct HistoryView: View {

    @State private var records: [HistoryRecord] = []
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\HistoryRecord.uploadedAt, order: .reverse)]
    @State private var selection = Set<String>()
    @State private var recordToDelete: HistoryRecord?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var statusMessage = ""

    // MARK: - Filtered + sorted records

    private var filtered: [HistoryRecord] {
        let base = searchText.isEmpty
            ? records
            : records.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortOrder)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Search bar ────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索文件名…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            // ── Content ───────────────────────────────────────
            if records.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                fileTable
            }

            // ── Status bar ────────────────────────────────────
            HStack {
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                Spacer()
                if !records.isEmpty {
                    let total = records.reduce(Int64(0)) { $0 + $1.fileSize }
                    Text("共 \(records.count) 条记录 · \(Self.fmtSize(total))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .toolbar {
            ToolbarItem {
                Button { loadRecords() } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新上传记录")
            }
        }
        .onAppear { loadRecords() }
        .alert("确认删除", isPresented: $showDeleteConfirm, presenting: recordToDelete) { rec in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { performDelete(rec) }
        } message: { rec in
            Text("确定要从云端删除「\(rec.fileName)」吗？\n\n⚠️ 删除后，所有已分享的链接将立即失效且无法恢复。")
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("暂无上传记录")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("在 Finder 中右键文件上传后\n记录会自动出现在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var fileTable: some View {
        Table(filtered, selection: $selection, sortOrder: $sortOrder) {

            TableColumn("文件名", value: \.fileName) { rec in
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.fileName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(rec.url)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .help(rec.url)
                }
            }
            .width(min: 200)

            TableColumn("大小", value: \.fileSize) { rec in
                Text(Self.fmtSize(rec.fileSize))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(70)

            TableColumn("模式") { (rec: HistoryRecord) in
                Text(rec.mode == "public" ? "公开" : "临时")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        rec.mode == "public"
                            ? Color.blue.opacity(0.15)
                            : Color.orange.opacity(0.15),
                        in: Capsule()
                    )
            }
            .width(60)

            TableColumn("上传时间", value: \.uploadedAt) { rec in
                Text(Self.fmtDate(rec.uploadedAt))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 100)
        }
        .contextMenu(forSelectionType: HistoryRecord.ID.self) { ids in
            if let id = ids.first,
               let rec = records.first(where: { $0.id == id }) {
                Button {
                    NotificationManager.copyToClipboard(rec.url)
                    flash("✅ 已复制链接")
                } label: { Label("复制链接", systemImage: "doc.on.doc") }

                if let link = URL(string: rec.url) {
                    Button {
                        NSWorkspace.shared.open(link)
                    } label: { Label("在浏览器中打开", systemImage: "safari") }
                }

                Divider()

                Button(role: .destructive) {
                    recordToDelete = rec
                    showDeleteConfirm = true
                } label: { Label("从云端删除", systemImage: "trash") }
            }
        } primaryAction: { ids in
            // Double-click → copy URL
            if let id = ids.first,
               let rec = records.first(where: { $0.id == id }) {
                NotificationManager.copyToClipboard(rec.url)
                flash("✅ 已复制链接")
            }
        }
    }

    // MARK: - Actions

    private func loadRecords() {
        records = HistoryManager.shared.loadAll()
    }

    private func performDelete(_ record: HistoryRecord) {
        isDeleting = true
        Task {
            do {
                let config = try ConfigManager.shared.load()
                let uploader = R2Uploader(config: config.r2)
                try await uploader.delete(objectKey: record.objectKey)
                HistoryManager.shared.remove(id: record.id)
                await MainActor.run {
                    withAnimation { records.removeAll { $0.id == record.id } }
                    isDeleting = false
                    flash("✅ 已删除: \(record.fileName)")
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    flash("❌ 删除失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func flash(_ msg: String) {
        withAnimation { statusMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { if statusMessage == msg { statusMessage = "" } }
        }
    }

    // MARK: - Formatting

    static func fmtSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func fmtDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}

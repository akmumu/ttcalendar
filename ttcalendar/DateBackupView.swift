import SwiftUI
import UniformTypeIdentifiers

struct DateBackupView: View {
    @ObservedObject var service: DateBackupService
    var didRestore: () -> Void
    @State private var preview: DateBackupService.Preview?
    @State private var message: String?
    @State private var isReading = false
    @State private var safetyCopy: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("自定义日期备份", systemImage: "externaldrive").font(.headline)
            Text("选好文件夹后，日期有改动就会自动备份。")
                .font(.callout).foregroundStyle(.secondary)
            if let folder = service.folderPath {
                Text(folder).font(.caption).textSelection(.enabled)
                if let last = service.lastBackup {
                    Text("上次写入备份：\(last.formatted(date: .abbreviated, time: .standard))").font(.caption)
                }
            }
            HStack {
                Button(service.folderPath == nil ? "选择备份文件夹…" : "更改备份文件夹…", action: chooseFolder)
                if service.folderPath != nil {
                    Button("立即备份") { service.enqueue(force: true) }
                    Button("关闭自动备份") { service.disable() }
                }
                Button("从备份恢复…", action: chooseBackup)
            }
            .disabled(isReading || service.isWriting)
            if isReading || service.isWriting {
                ProgressView(isReading ? "正在读取备份…" : "正在写入备份…").controlSize(.small)
            }
            if let error = service.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
            if let message { Text(message).font(.caption).textSelection(.enabled) }
            if let safetyCopy {
                Button("查看恢复前的副本") { NSWorkspace.shared.activateFileViewerSelecting([safetyCopy]) }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .alert("恢复自定义日期？", isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } }),
               presenting: preview) { item in
            Button("取消", role: .cancel) {}
            Button("替换当前库日期", role: .destructive) {
                do {
                    safetyCopy = try service.restore(item)
                    didRestore()
                    message = "已恢复 \(item.dates.count) 条日期。"
                } catch { message = error.localizedDescription }
            }
        } message: { item in
            let local = item.previousCount.map { "本机的 \($0) 条日期" } ?? "当前库中损坏的日期文件"
            Text("将用「\(item.name)」中的 \(item.dates.count) 条日期替换\(local)。恢复前会为被替换的日期保留本机副本。")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "用作备份文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try service.chooseFolder(url); message = nil }
        catch { message = error.localizedDescription }
    }

    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList]
        if let folder = service.folderPath { panel.directoryURL = URL(fileURLWithPath: folder, isDirectory: true) }
        panel.prompt = "预览备份"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isReading = true
        message = nil
        Task {
            defer { isReading = false }
            do { preview = try await service.preview(url) }
            catch { message = "无法预览备份：\(error.localizedDescription)" }
        }
    }
}

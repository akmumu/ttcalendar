import SwiftUI

struct DateLibraryView: View {
    @ObservedObject var library: DateLibrary
    var initialSetup = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("日期库", systemImage: "folder").font(.headline)
            if initialSetup {
                Text("选择日期的保存位置，或打开已有的日期库。")
            } else {
                Text((library.path as NSString).abbreviatingWithTildeInPath)
                    .font(.callout).textSelection(.enabled)
            }
            HStack {
                if initialSetup { Button("使用默认位置") { library.finishSetup() } }
                Button(initialSetup ? "新建日期库…" : "日期库另存为…") { choose(create: true) }
                Button("打开已有库…") { choose(create: false) }
                if !initialSetup {
                    Button("在访达中显示") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: library.path) }
                }
            }
            if let issue = library.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
            if let issue = library.cacheIssue {
                Text(issue).font(.caption).foregroundStyle(.orange)
                Button("授权小组件文件夹…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.directoryURL = WidgetPreferences.storageDirectory
                    guard panel.runModal() == .OK, let folder = panel.url else { return }
                    do {
                        message = try WidgetFolderAccess.authorize(folder, requireDates: false)
                        library.refresh()
                        AppInstallRefreshCoordinator.reloadWidgetsRepeatedly()
                    } catch { message = error.localizedDescription }
                }
            }
            if let message { Text(message).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func choose(create: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = create
        panel.prompt = create ? "保存到此文件夹" : "打开日期库"
        panel.message = create ? "选一个文件夹保存当前日期库，之后的改动也会保存在这里。" : "选择包含 customSpecialDates.plist 的文件夹。"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            try library.select(folder, create: create)
            library.finishSetup()
            message = nil
        } catch { message = error.localizedDescription }
    }
}

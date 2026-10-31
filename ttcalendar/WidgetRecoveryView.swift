import SwiftUI

struct WidgetRecoveryView: View {
    @ObservedObject var recovery: WidgetRecoveryService
    @State private var confirmsSystemRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("小组件卡住时", systemImage: "arrow.clockwise.circle")
                .font(.headline)
            Text("先重启抬头日历小组件；如果仍无法切换月份，再重启系统小组件服务。日期和提醒设置都会保留。")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("重启抬头日历小组件") { recovery.restart() }
                    .buttonStyle(.borderedProminent)
                Button("重启系统小组件服务…") { confirmsSystemRestart = true }
                    .buttonStyle(.bordered)
                if recovery.isRestarting { ProgressView().controlSize(.small) }
            }
            .disabled(recovery.isRestarting)
            if let message = recovery.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(recovery.hasError ? Color.orange : Color.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .confirmationDialog("重启系统小组件服务？", isPresented: $confirmsSystemRestart) {
            Button("重启系统小组件服务") { recovery.restart(.systemWidgets) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有桌面小组件和通知中心会短暂消失并重新加载。不会删除小组件配置、自定义日期或提醒。")
        }
    }
}

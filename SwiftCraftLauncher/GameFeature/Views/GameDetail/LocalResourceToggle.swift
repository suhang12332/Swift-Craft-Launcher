import SwiftUI

/// 本地资源启用/禁用开关视图
/// 仅负责展示 UI 和触发状态切换事件，具体文件重命名等逻辑由外部处理
struct LocalResourceToggle: View {
    /// 是否显示开关（仅本地资源）
    let isVisible: Bool
    /// 当前是否被禁用（外部状态）
    @Binding var isDisabled: Bool
    /// 当用户点击开关时触发，由外部执行实际的状态切换逻辑
    let onToggle: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { !isDisabled },
                        set: { _ in onToggle() }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }
        }
    }
}

import SwiftUI

/// 本地资源启用/禁用开关视图
struct LocalResourceToggle: View {
    /// 是否显示开关（仅本地资源）
    let isVisible: Bool
    /// 当前是否被禁用（外部状态）
    @Binding var isDisabled: Bool
    /// 点击回调
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

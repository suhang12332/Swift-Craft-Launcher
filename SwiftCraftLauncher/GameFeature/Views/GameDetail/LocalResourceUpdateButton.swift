import SwiftUI

/// 本地资源“更新”按钮视图
struct LocalResourceUpdateButton: View {
    /// 是否显示更新按钮（例如仅在本地模式且有更新时显示）
    let isVisible: Bool
    /// 更新按钮自身的 loading 状态
    @Binding var isUpdateButtonLoading: Bool
    /// 主安装按钮的状态（用于决定是否禁用更新按钮）
    let addButtonState: ModrinthDetailCardView.AddButtonState
    /// 点击回调
    let onTap: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: onTap) {
                    if isUpdateButtonLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(1.3)
                    } else {
                        Text("resource.update".localized())
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .font(.caption2)
                .controlSize(.small)
                .disabled(addButtonState == .loading || isUpdateButtonLoading)
            }
        }
    }
}

import SwiftUI

/// 主安装/删除按钮视图
/// 只负责展示 UI 和将点击事件向外转发
struct ResourcePrimaryActionButton: View {
    let addButtonState: ModrinthDetailCardView.AddButtonState
    /// true = server, false = local
    let type: Bool
    /// 是否禁用按钮
    let isDisabled: Bool
    /// 点击回调
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            label
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .font(.caption2)
        .controlSize(.small)
        .disabled(isDisabled)
    }

    @ViewBuilder private var label: some View {
        switch addButtonState {
        case .idle:
            Text("resource.add".localized())
        case .loading:
            ProgressView()
                .controlSize(.mini)
                .font(.body)
        case .installed:
            Text(
                (!type
                    ? "common.delete".localized()
                    : "resource.installed".localized())
            )
        case .update:
            // 当有更新时，主按钮显示删除（更新按钮已单独显示在左边）
            Text("common.delete".localized())
        }
    }
}

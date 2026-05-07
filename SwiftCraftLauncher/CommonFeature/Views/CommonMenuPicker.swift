import SwiftUI

// 通过在文本末尾追加空格，将其补齐到 100 个字符，从而撑开 macOS 26 下的选择框宽度。
func paddedPickerLabel(_ text: String) -> String {
    guard #available(macOS 26, *) else { return text }
    let targetLength = 100
    let paddingCount = max(0, targetLength - text.count)
    return text + String(repeating: " ", count: paddingCount)
}

/// 通用的菜单样式 Picker，统一 `.pickerStyle(.menu)`，并可选择隐藏标签。
struct CommonMenuPicker<Label: View, SelectionValue: Hashable, Content: View>: View {
    private let selection: Binding<SelectionValue>
    private let hidesLabel: Bool
    private let label: () -> Label
    private let content: () -> Content

    init(
        selection: Binding<SelectionValue>,
        hidesLabel: Bool = false,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.selection = selection
        self.hidesLabel = hidesLabel
        self.label = label
        self.content = content
    }

    var body: some View {
        Picker(selection: selection, label: label()) {
            content()
        }
        .pickerStyle(.menu)
        .modifier(ConditionalLabelsHidden(isHidden: hidesLabel))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ConditionalLabelsHidden: ViewModifier {
    let isHidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isHidden {
            content.labelsHidden()
        } else {
            content
        }
    }
}

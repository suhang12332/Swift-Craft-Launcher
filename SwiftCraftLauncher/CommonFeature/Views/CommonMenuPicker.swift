import SwiftUI

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

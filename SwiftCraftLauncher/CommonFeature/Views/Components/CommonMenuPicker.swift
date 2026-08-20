//
//  CommonMenuPicker.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A menu-style picker with consistent styling and optional label hiding.
struct CommonMenuPicker<Label: View, SelectionValue: Hashable, Content: View>: View {
    private let selection: Binding<SelectionValue>
    private let hidesLabel: Bool
    private let label: () -> Label
    private let content: () -> Content

    init(
        selection: Binding<SelectionValue>,
        hidesLabel: Bool = false,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: @escaping () -> Content,
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
        .modifier(FlexibleButtonSizingModifier())
    }
}

extension CommonMenuPicker where Label == EmptyView {
    init(
        selection: Binding<SelectionValue>,
        hidesLabel: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.init(
            selection: selection,
            hidesLabel: hidesLabel,
            label: { EmptyView() },
            content: content,
        )
    }
}

private struct ConditionalLabelsHidden: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        if isHidden {
            content.labelsHidden()
        } else {
            content
        }
    }
}

private struct FlexibleButtonSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
            if #available(macOS 26, *) {
                content.buttonSizing(.flexible)
            } else {
                content
            }
        #else
            content
        #endif
    }
}

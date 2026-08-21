//
//  AlertItemModifier.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Generic alert driven by an optional `Identifiable` item, presenting an `Alert` from the item.
struct AlertItemModifier<T: Identifiable>: ViewModifier {
    @Binding var item: T?
    var alert: (T) -> Alert

    func body(content: Content) -> some View {
        content
            .alert(item: $item) { item in
                alert(item)
            }
    }
}

extension View {
    func alertItem<T: Identifiable>(
        item: Binding<T?>,
        alert: @escaping (T) -> Alert,
    ) -> some View {
        modifier(
            AlertItemModifier(
                item: item,
                alert: alert,
            ),
        )
    }
}

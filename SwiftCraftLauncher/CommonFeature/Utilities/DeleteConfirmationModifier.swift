//
//  DeleteConfirmationModifier.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Generic confirmation dialog for deleting an item, shared across all features.
struct DeleteConfirmationModifier<T>: ViewModifier {
    @Binding var pendingDeletion: T?
    var title: String
    var message: (T) -> String
    var delete: (T) -> Void
    var deleteButtonTitle: String
    var cancelButtonTitle: String

    init(
        pendingDeletion: Binding<T?>,
        title: String,
        message: @escaping (T) -> String,
        delete: @escaping (T) -> Void,
        deleteButtonTitle: String = "common.delete".localized(),
        cancelButtonTitle: String = "common.cancel".localized(),
    ) {
        _pendingDeletion = pendingDeletion
        self.title = title
        self.message = message
        self.delete = delete
        self.deleteButtonTitle = deleteButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
    }

    private var isDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: {
                if !$0 {
                    pendingDeletion = nil
                }
            },
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: isDialogPresented,
                titleVisibility: .visible,
            ) {
                Button(deleteButtonTitle, role: .destructive) {
                    if let item = pendingDeletion {
                        delete(item)
                        pendingDeletion = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
                Button(cancelButtonTitle, role: .cancel) { }
            } message: {
                if let item = pendingDeletion {
                    Text(message(item))
                }
            }
    }
}

extension View {
    func deleteConfirmationDialog<T>(
        pendingDeletion: Binding<T?>,
        title: String,
        message: @escaping (T) -> String,
        delete: @escaping (T) -> Void,
        deleteButtonTitle: String = "common.delete".localized(),
        cancelButtonTitle: String = "common.cancel".localized(),
    ) -> some View {
        modifier(
            DeleteConfirmationModifier(
                pendingDeletion: pendingDeletion,
                title: title,
                message: message,
                delete: delete,
                deleteButtonTitle: deleteButtonTitle,
                cancelButtonTitle: cancelButtonTitle,
            ),
        )
    }
}

//
//  ModPackFailedResourcesView.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Payload used to open the failed modpack resources auxiliary window.
struct ModPackFailedResourcesWindowPayload {
    let failedResources: [FailedModPackResource]
    let onResourceHandled: (FailedModPackResource) -> Void
    let onAllHandled: () -> Void
    let onAbort: () -> Void
}

/// A view that walks through failed modpack resources one at a time, showing the install UI for each.
struct ModPackFailedResourcesView: View {
    let failedResources: [FailedModPackResource]
    @Binding var isPresented: Bool
    let onResourceHandled: (FailedModPackResource) -> Void
    let onAllHandled: () -> Void
    let onAbort: () -> Void

    @State private var remainingResources: [FailedModPackResource]

    init(
        failedResources: [FailedModPackResource],
        isPresented: Binding<Bool>,
        onResourceHandled: @escaping (FailedModPackResource) -> Void,
        onAllHandled: @escaping () -> Void,
        onAbort: @escaping () -> Void,
    ) {
        self.failedResources = failedResources
        _isPresented = isPresented
        self.onResourceHandled = onResourceHandled
        self.onAllHandled = onAllHandled
        self.onAbort = onAbort
        _remainingResources = State(initialValue: failedResources)
    }

    var body: some View {
        Group {
            if let current = remainingResources.first {
                FailedResourceInstallSection(
                    resource: current,
                    onSkip: {
                        handleHandled(current)
                    },
                    onDownloadSuccess: { _, _ in
                        handleHandled(current)
                    },
                )
                .id(current.id)
            }
        }
        .onDisappear {
            if !remainingResources.isEmpty {
                onAbort()
            }
        }
    }

    private func handleHandled(_ resource: FailedModPackResource) {
        remainingResources.removeFirst()
        onResourceHandled(resource)
        if remainingResources.isEmpty {
            onAllHandled()
            isPresented = false
        }
    }
}

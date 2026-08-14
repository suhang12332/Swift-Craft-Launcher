//
//  ModPackFailedResourcesWindowContent.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Root content of the failed modpack resources auxiliary window.
struct ModPackFailedResourcesWindowContent: View {
    @Environment(DIContainer.self)
    private var container

    var body: some View {
        Group {
            if let payload = container.ui.windowManager.readPayload(
                for: .failedResources,
                as: ModPackFailedResourcesWindowPayload.self,
            ) {
                ModPackFailedResourcesView(
                    failedResources: payload.failedResources,
                    isPresented: Binding(
                        get: { true },
                        set: { isPresented in
                            if !isPresented {
                                container.ui.windowManager.closeWindow(id: .failedResources)
                            }
                        },
                    ),
                    onResourceHandled: payload.onResourceHandled,
                    onAllHandled: {
                        payload.onAllHandled()
                        container.ui.windowManager.closeWindow(id: .failedResources)
                    },
                    onAbort: payload.onAbort,
                )
            }
        }
        .frame(
            width: AuxiliaryWindowID.failedResources.defaultSize.width,
            height: AuxiliaryWindowID.failedResources.defaultSize.height,
        )
    }
}

//
//  FailedResourcesPresenting.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Shared presentation of failed modpack resources for view models that run
/// `ModPackInstallCoordinator`, reporting retry/skip results back to it.
@MainActor
protocol FailedResourcesPresenting: AnyObject {
    var failedResources: [FailedModPackResource] { get set }
    var failedResourcesContinuation: ((Bool) -> Void)? { get set }
    var modPackInstallState: ModPackInstallState { get }
}

extension FailedResourcesPresenting {
    func handleFailedResources(
        _ resources: [FailedModPackResource],
        continuation: @escaping (Bool) -> Void,
    ) {
        failedResources = resources
        failedResourcesContinuation = continuation
        openFailedResourcesWindow()
    }

    func openFailedResourcesWindow() {
        let payload = ModPackFailedResourcesWindowPayload(
            failedResources: failedResources,
            onResourceHandled: { [weak self] resource in
                self?.modPackInstallState.markHandledResource(
                    name: resource.projectDetail.title,
                )
            },
            onAllHandled: { [weak self] in
                self?.finishFailedResources(allHandled: true)
            },
            onAbort: { [weak self] in
                self?.finishFailedResources(allHandled: false)
            },
        )
        DIContainer.shared.ui.windowManager.preparePayload(payload, for: .failedResources)
        DIContainer.shared.ui.windowManager.openWindow(id: .failedResources)
    }

    private func finishFailedResources(allHandled: Bool) {
        failedResources = []
        failedResourcesContinuation?(allHandled)
        failedResourcesContinuation = nil
    }
}

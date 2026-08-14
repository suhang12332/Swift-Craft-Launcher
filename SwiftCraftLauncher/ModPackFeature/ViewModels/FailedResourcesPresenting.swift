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
    var failedResourcesContinuation: (([String: Bool]) -> Void)? { get set }
    var modPackInstallState: ModPackInstallState { get }
}

extension FailedResourcesPresenting {
    func handleFailedResources(
        _ resources: [FailedModPackResource],
        continuation: @escaping ([String: Bool]) -> Void,
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
                self?.onFailedResourcesHandled()
            },
            onAbort: { [weak self] in
                self?.onFailedResourcesAborted()
            },
        )
        DIContainer.shared.ui.windowManager.preparePayload(payload, for: .failedResources)
        DIContainer.shared.ui.windowManager.openWindow(id: .failedResources)
    }

    func onFailedResourcesHandled() {
        finishFailedResources(allHandled: true)
    }

    func onFailedResourcesAborted() {
        finishFailedResources(allHandled: false)
    }

    private func finishFailedResources(allHandled: Bool) {
        let results = failedResources.reduce(into: [String: Bool]()) {
            $0[$1.projectDetail.id] = allHandled
        }
        failedResources = []
        failedResourcesContinuation?(results)
        failedResourcesContinuation = nil
    }
}

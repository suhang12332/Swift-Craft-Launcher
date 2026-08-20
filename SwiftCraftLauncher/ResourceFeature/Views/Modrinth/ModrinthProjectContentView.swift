//
//  ModrinthProjectContentView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Loads and displays the project detail content including compatibility, links, and details.
struct ModrinthProjectContentView: View {
    @Environment(DIContainer.self)
    private var container
    @State private var isLoading = false
    @State private var error: GlobalError?
    @Binding var projectDetail: ModrinthProjectDetail?
    let projectId: String
    let resourceType: String

    init(
        projectDetail: Binding<ModrinthProjectDetail?>,
        projectId: String,
        resourceType: String,
    ) {
        _projectDetail = projectDetail
        self.projectId = projectId
        self.resourceType = resourceType
    }

    var body: some View {
        VStack {
            if let error {
                errorView(error)
            } else {
                ModrinthCompatibilitySection(
                    project: projectDetail,
                    isLoading: isLoading,
                    resourceType: resourceType,
                )
                ModrinthLinksSection(project: projectDetail, isLoading: isLoading)
                ModrinthDetailsSection(project: projectDetail, isLoading: isLoading)
            }
        }
        .task(id: projectId) { await loadProjectDetails() }
        .onDisappear {
            projectDetail = nil
            error = nil
        }
    }

    private func loadProjectDetails() async {
        isLoading = true
        error = nil

        do {
            try await loadProjectDetailsThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.resource.error("Failed to load project details: \(globalError.localizedDescription)")
            container.core.errorHandler.handle(globalError)
            await MainActor.run {
                self.error = globalError
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func loadProjectDetailsThrowing() async throws {
        guard !projectId.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.validation.project_id_empty",
                level: .notification,
                message: "projectId is empty",
            )
        }
        #if DEBUG
            if projectId == HTMLTestMod.projectId {
                await MainActor.run {
                    projectDetail = HTMLTestMod.detail
                }
                return
            }
        #endif
        let result = await ModrinthService.fetchProjectDetails(id: projectId, type: resourceType == ProjectType.minecraftJavaServer ? resourceType : "")
        await MainActor.run {
            projectDetail = result
        }
    }
}

//
//  ModrinthProjectContentView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import SwiftUI

struct ModrinthProjectContentView: View {
    @State private var isLoading = false
    @State private var error: GlobalError?
    @Binding var projectDetail: ModrinthProjectDetail?
    let projectId: String
    let resourceType: String
    private let errorHandler: GlobalErrorHandler

    init(
        projectDetail: Binding<ModrinthProjectDetail?>,
        projectId: String,
        resourceType: String,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        _projectDetail = projectDetail
        self.projectId = projectId
        self.resourceType = resourceType
        self.errorHandler = errorHandler
    }

    var body: some View {
        VStack {
            if let error = error {
                errorView(error)
            } else {
                ModrinthCompatibilitySection(
                    project: projectDetail,
                    isLoading: isLoading,
                    resourceType: resourceType
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
            Logger.shared.error("加载项目详情失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
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
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }
        let result = await ModrinthService.fetchProjectDetails(id: projectId, type: resourceType == ProjectType.minecraftJavaServer ? resourceType : "")
        await MainActor.run {
            projectDetail = result
        }
    }
}

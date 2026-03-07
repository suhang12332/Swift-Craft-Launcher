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

    var body: some View {
        VStack {
            if let error = error {
                newErrorView(error)
            } else {
                ModrinthCompatibilitySection(project: projectDetail, isLoading: isLoading)
                ModrinthLinksSection(project: projectDetail, isLoading: isLoading)
                ModrinthDetailsSection(project: projectDetail, isLoading: isLoading)
            }
        }
        .task(id: projectId) { await loadProjectDetails() }
    }

    private func loadProjectDetails() async {
        isLoading = true
        error = nil

        do {
            try await loadProjectDetailsThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("加载项目详情失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
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

        guard
            let fetchedProject = await ModrinthService.fetchProjectDetails(
                id: projectId
            )
        else {
            throw GlobalError.resource(
                chineseMessage: "无法获取项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            )
        }

        await MainActor.run {
            projectDetail = fetchedProject
        }
    }
}

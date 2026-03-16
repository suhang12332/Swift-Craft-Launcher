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

    var body: some View {
        VStack {
            if let error = error {
                newErrorView(error)
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

        // Minecraft 服务器：使用 v3 接口并转换为通用的 ModrinthProjectDetail
        let result: ModrinthProjectDetail?
        if resourceType == ProjectType.minecraftJavaServer {
            let detailV3 = try await ModrinthService.fetchProjectDetailsV3Throwing(id: projectId)
            result = ModrinthProjectDetail.fromV3(detailV3)
        } else {
            result = await ModrinthService.fetchProjectDetails(id: projectId)
        }
        await MainActor.run {
            projectDetail = result
        }
    }
}

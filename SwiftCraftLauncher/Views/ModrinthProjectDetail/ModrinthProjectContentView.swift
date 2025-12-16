//
//  ModrinthProjectContentView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let maxVisibleVersions = 15
    static let popoverWidth: CGFloat = 300
    static let popoverHeight: CGFloat = 400
    static let cornerRadius: CGFloat = 4
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 8
}

// MARK: - View Components
private struct CompatibilitySection: View {
    let project: ModrinthProjectDetail
    @State private var showingVersionsPopover = false

    var body: some View {
        SectionView(title: "project.info.compatibility".localized()) {
            VStack(alignment: .leading, spacing: 12) {
                MinecraftVersionHeader()

                if !project.gameVersions.isEmpty {
                    GameVersionsSection(
                        versions: project.gameVersions,
                        showingVersionsPopover: $showingVersionsPopover
                    )
                }

                if !project.loaders.isEmpty {
                    LoadersSection(loaders: project.loaders)
                }

                PlatformSupportSection(
                    clientSide: project.clientSide,
                    serverSide: project.serverSide
                )
            }
        }
    }
}

private struct MinecraftVersionHeader: View {
    var body: some View {
        HStack {
            Text("project.info.minecraft".localized())
                .font(.headline)
            Text("project.info.minecraft.edition".localized())
                .foregroundStyle(.primary)
                .font(.caption.bold())
        }
    }
}

private struct GameVersionsSection: View {
    let versions: [String]
    @Binding var showingVersionsPopover: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("project.info.versions".localized())
                    .font(.headline)
                Spacer()
                if versions.count > Constants.maxVisibleVersions {
                    Button {
                        showingVersionsPopover = true
                    } label: {
                        Text(
                            "+\(versions.count - Constants.maxVisibleVersions)"
                        )
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingVersionsPopover) {
                        GameVersionsPopover(versions: versions)
                    }
                }
            }

            HStack {
                FlowLayout(spacing: Constants.spacing) {
                    ForEach(
                        Array(versions.prefix(Constants.maxVisibleVersions)),
                        id: \.self
                    ) { version in
                        VersionTag(version: version)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct GameVersionsPopover: View {
    let versions: [String]

    var body: some View {
        VersionGroupedView(
            items: versions.map { FilterItem(id: $0, name: $0) },
            selectedItems: .constant([])
        ) { _ in
            // No action needed for display-only popover
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
    }
}

private struct VersionTag: View {
    let version: String

    var body: some View {
        Text(version)
            .font(.caption)
            .padding(.horizontal, Constants.padding)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(Constants.cornerRadius)
    }
}

private struct LoadersSection: View {
    let loaders: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("project.info.platforms".localized())
                .font(.headline)
            FlowLayout(spacing: Constants.spacing) {
                ForEach(loaders, id: \.self) { loader in
                    VersionTag(version: loader)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct PlatformSupportSection: View {
    let clientSide: String
    let serverSide: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 使用字符串插值而非字符串拼接
            Text("\("platform.support".localized()):")
                .font(.headline)
            HStack(spacing: 8) {
                PlatformSupportItem(
                    icon: "laptopcomputer",
                    text: "platform.client.\(clientSide)".localized()
                )
                PlatformSupportItem(
                    icon: "server.rack",
                    text: "platform.server.\(serverSide)".localized()
                )
            }.padding(.top, 4)
        }
    }
}

private struct PlatformSupportItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

private struct LinksSection: View {
    let project: ModrinthProjectDetail

    var body: some View {
        SectionView(title: "project.info.links".localized()) {
            FlowLayout(spacing: Constants.spacing) {
                if let url = project.issuesUrl {
                    ProjectLink(
                        text: "project.info.links.issues".localized(),
                        url: url
                    )
                }

                if let url = project.sourceUrl {
                    ProjectLink(
                        text: "project.info.links.source".localized(),
                        url: url
                    )
                }

                if let url = project.wikiUrl {
                    ProjectLink(
                        text: "project.info.links.wiki".localized(),
                        url: url
                    )
                }

                if let url = project.discordUrl {
                    ProjectLink(
                        text: "project.info.links.discord".localized(),
                        url: url
                    )
                }
            }
        }
    }
}

private struct ProjectLink: View {
    let text: String
    let url: String

    var body: some View {
        if let url = URL(string: url) {
            Link(destination: url) {
                Text(text)
                    .font(.caption)
                    .padding(.horizontal, Constants.padding)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(Constants.cornerRadius)
            }
        }
    }
}

private struct DetailsSection: View, Equatable {
    let project: ModrinthProjectDetail

    // 缓存日期格式化结果，避免每次渲染都重新计算
    private var publishedDateString: String {
        project.published.formatted(.relative(presentation: .named))
    }

    private var updatedDateString: String {
        project.updated.formatted(.relative(presentation: .named))
    }

    var body: some View {
        SectionView(title: "project.info.details".localized()) {
            VStack(alignment: .leading, spacing: 8) {
                if let license = project.license {
                    DetailRow(
                        label: "project.info.details.licensed".localized(),
                        value: license.name
                    )
                }

                DetailRow(
                    label: "project.info.details.published".localized(),
                    value: publishedDateString
                )
                DetailRow(
                    label: "project.info.details.updated".localized(),
                    value: updatedDateString
                )
            }
        }
    }

    // 实现 Equatable，避免不必要的重新渲染
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.project.id == rhs.project.id &&
        lhs.project.license?.id == rhs.project.license?.id &&
        lhs.project.published == rhs.project.published &&
        lhs.project.updated == rhs.project.updated
    }
}

struct ModrinthProjectContentView: View {
    @State private var isLoading = false
    @State private var error: GlobalError?
    @Binding var projectDetail: ModrinthProjectDetail?
    let projectId: String

    var body: some View {
        VStack {
            if let error = error {
                newErrorView(error)
            } else if let project = projectDetail {
                CompatibilitySection(project: project)
                LinksSection(project: project)
                DetailsSection(project: project)
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
        Logger.shared.info("Loading project details for ID: \(projectId)")

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

        Logger.shared.info(
            "Successfully loaded project details for ID: \(projectId)"
        )
    }
}

// MARK: - Helper Views
private struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.top, 10)

            content()
        }
    }
}

private struct DetailRow: View, Equatable {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout.bold())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 20) // 设置最小高度，减少布局计算
    }

    // 实现 Equatable，避免不必要的重新渲染
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.label == rhs.label && lhs.value == rhs.value
    }
}

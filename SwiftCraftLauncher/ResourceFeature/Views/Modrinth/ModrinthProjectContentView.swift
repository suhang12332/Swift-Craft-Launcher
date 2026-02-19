//
//  ModrinthProjectContentView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import SwiftUI
import AppKit

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
//                MinecraftVersionHeader()

            if !project.gameVersions.isEmpty {
                GameVersionsSection(versions: project.gameVersions)
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

// private struct MinecraftVersionHeader: View {
//    var body: some View {
//        HStack {
//            Text("project.info.minecraft".localized())
//                .font(.headline)
//            Text("project.info.minecraft.edition".localized())
//                .foregroundStyle(.primary)
//                .font(.caption.bold())
//        }
//    }
// }

private struct GameVersionsSection: View {
    let versions: [String]

    var body: some View {
        GenericSectionView(
            title: "project.info.versions",
            items: versions.map { IdentifiableString(id: $0) },
            isLoading: false,
            maxItems: Constants.maxVisibleVersions
        ) { item in
            VersionTag(version: item.id)
        } overflowContentBuilder: { _ in
            AnyView(
                GameVersionsPopover(versions: versions)
            )
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
        FilterChip(
            title: version,
            isSelected: false
        ) {}
    }
}

private struct LoadersSection: View {
    let loaders: [String]

    var body: some View {
        GenericSectionView(
            title: "project.info.platforms",
            items: loaders.map { IdentifiableString(id: $0) },
            isLoading: false
        ) { item in
            VersionTag(version: item.id)
        }
    }
}

private struct PlatformSupportSection: View {
    let clientSide: String
    let serverSide: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\("platform.support".localized()):")
                .font(.headline)
                .padding(.bottom, SectionViewConstants.defaultHeaderBottomPadding)

            ContentWithOverflow(
                items: [
                    IdentifiablePlatformItem(id: "client", icon: "laptopcomputer", text: "platform.client.\(clientSide)".localized()),
                    IdentifiablePlatformItem(id: "server", icon: "server.rack", text: "platform.server.\(serverSide)".localized()),
                ],
                maxHeight: SectionViewConstants.defaultMaxHeight,
                verticalPadding: SectionViewConstants.defaultVerticalPadding
            ) { item in
                PlatformSupportItem(icon: item.icon, text: item.text)
            }
        }
    }
}

private struct IdentifiablePlatformItem: Identifiable {
    let id: String
    let icon: String
    let text: String
}

private struct PlatformSupportItem: View {
    let icon: String
    let text: String

    var body: some View {
        FilterChip(
            title: text,
            isSelected: false,
            action: {},
            iconName: icon,
            iconColor: .secondary
        )
    }
}

private struct LinksSection: View {
    let project: ModrinthProjectDetail

    var body: some View {
        let links = [
            (project.issuesUrl, "project.info.links.issues".localized()),
            (project.sourceUrl, "project.info.links.source".localized()),
            (project.wikiUrl, "project.info.links.wiki".localized()),
            (project.discordUrl, "project.info.links.discord".localized()),
        ].compactMap { url, text in
            url.map { (text, $0) }
        }

        GenericSectionView(
            title: "project.info.links",
            items: links.map { IdentifiableLink(id: $0.0, text: $0.0, url: $0.1) },
            isLoading: false
        ) { item in
            ProjectLink(text: item.text, url: item.url)
        }
    }
}

private struct IdentifiableLink: Identifiable {
    let id: String
    let text: String
    let url: String
}

private struct ProjectLink: View {
    let text: String
    let url: String

    var body: some View {
        if let url = URL(string: url) {
            FilterChip(
                title: text,
                isSelected: false
            ) {
                NSWorkspace.shared.open(url)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("project.info.details".localized())
                .font(.headline)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                DetailRow(
                    label: "project.info.details.licensed".localized(),
                    value: (project.license?.name).map { $0.isEmpty ? "Unknown" : $0 } ?? "Unknown"
                )

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
            if isLoading && projectDetail == nil && error == nil {
                loadingView
            } else if let error = error {
                newErrorView(error)
            } else if let project = projectDetail {
                CompatibilitySection(project: project)
                LinksSection(project: project)
                DetailsSection(project: project)
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

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(Constants.padding)
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

// MARK: - Helper Views

private struct DetailRow: View, Equatable {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout.bold())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            FilterChip(
                title: value,
                isSelected: false
            ) {}
        }
        .frame(minHeight: 20) // 设置最小高度，减少布局计算
    }

    // 实现 Equatable，避免不必要的重新渲染
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.label == rhs.label && lhs.value == rhs.value
    }
}

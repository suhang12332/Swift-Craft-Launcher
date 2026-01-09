import SwiftUI

public struct ContributorsView: View {
    @StateObject private var viewModel = ContributorsViewModel()
    @State private var staticContributors: [StaticContributor] = []
    @State private var staticContributorsLoaded = false
    @State private var staticContributorsLoadFailed = false
    private let gitHubService = GitHubService.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    contributorsContent
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            // 每次打开都重新获取GitHub贡献者数据
            Task {
                await viewModel.fetchContributors()
            }
            // 每次打开都重新加载静态贡献者数据
            loadStaticContributors()
        }
        .windowReferenceTracking {
            clearAllData()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Contributors Content
    private var contributorsContent: some View {
        VStack(spacing: 16) {
            // GitHub贡献者列表
            if !viewModel.contributors.isEmpty {
                contributorsList
            } else {
                EmptyView()
            }
            // 静态贡献者列表（只有成功加载时才显示）
            if staticContributorsLoaded && !staticContributorsLoadFailed {
                staticContributorsList
            }
        }
    }

    // MARK: - Static Contributors List
    private var staticContributorsList: some View {
        VStack(spacing: 0) {
            Text("contributors.core_contributors")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(staticContributors.indices, id: \.self) { index in
                staticContributorRow(staticContributors[index])

                if index < staticContributors.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Contributors List
    private var contributorsList: some View {
        VStack(spacing: 0) {
            // GitHub贡献者标题
            Text("contributors.github_contributors")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 顶级贡献者
            if !viewModel.topContributors.isEmpty {
                ForEach(
                    Array(viewModel.topContributors.enumerated()),
                    id: \.element.id
                ) { index, contributor in
                    ContributorCardView(
                        contributor: contributor,
                        isTopContributor: true,
                        rank: index + 1,
                        contributionsText: String(
                            format: "contributors.contributions.format"
                                .localized(),
                            viewModel.formatContributions(
                                contributor.contributions
                            )
                        )
                    )

                    if index < viewModel.topContributors.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }

                if !viewModel.otherContributors.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            // 其他贡献者
            ForEach(
                Array(viewModel.otherContributors.enumerated()),
                id: \.element.id
            ) { index, contributor in
                ContributorCardView(
                    contributor: contributor,
                    isTopContributor: false,
                    rank: index + viewModel.topContributors.count + 1,
                    contributionsText: String(
                        format: "contributors.contributions.format"
                            .localized(),
                        viewModel.formatContributions(
                            contributor.contributions
                        )
                    )
                )

                if index < viewModel.otherContributors.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Static Contributor Row
    private func staticContributorRow(
        _ contributor: StaticContributor
    ) -> some View {
        StaticContributorCardView(contributor: contributor)
    }
    // MARK: - Load Static Contributors
    private func loadStaticContributors() {
        // 重置状态
        staticContributorsLoaded = false
        staticContributorsLoadFailed = false
        Task {
            do {
                let contributorsData: ContributorsData = try await gitHubService.fetchStaticContributors()

                await MainActor.run {
                    staticContributors = contributorsData.contributors.map { contributorData in
                        StaticContributor(
                            name: contributorData.name,
                            url: contributorData.url,
                            avatar: contributorData.avatar,
                            contributions: contributorData.contributions.compactMap {
                                Contribution(rawValue: "contributor.contribution.\($0)")
                            }
                        )
                    }
                    staticContributorsLoaded = true
                    staticContributorsLoadFailed = false
                    Logger.shared.info(
                        "Successfully loaded",
                        staticContributors.count,
                        "contributors from GitHubService"
                    )
                }
            } catch {
                Logger.shared.error("Failed to load contributors from GitHubService:", error)
                await MainActor.run {
                    staticContributorsLoadFailed = true
                }
            }
        }
    }

    // MARK: - Clear Static Contributors Data
    private func clearStaticContributorsData() {
        staticContributors = []
        staticContributorsLoaded = false
        staticContributorsLoadFailed = false
        Logger.shared.info("Static contributors data cleared")
    }
    
    /// 清理所有数据
    private func clearAllData() {
        clearStaticContributorsData()
    }
}

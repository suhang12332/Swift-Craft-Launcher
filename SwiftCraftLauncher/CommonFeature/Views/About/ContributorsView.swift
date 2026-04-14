import SwiftUI

public struct ContributorsView: View {
    @StateObject private var viewModel = ContributorsViewModel()
    @StateObject private var staticViewModel = ContributorsStaticViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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
            Task { await viewModel.fetchContributors() }
            // 每次打开都重新加载静态贡献者数据
            staticViewModel.load()
        }
        .onDisappear {
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
        LazyVStack(spacing: 16) {
            // GitHub贡献者列表
            if !viewModel.contributors.isEmpty {
                contributorsList
            }
            // 静态贡献者列表（只有成功加载时才显示）
            if staticViewModel.loaded && !staticViewModel.loadFailed {
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

            ForEach(staticViewModel.contributors.indices, id: \.self) { index in
                staticContributorRow(staticViewModel.contributors[index])
                    .id("static-\(index)")

                if index < staticViewModel.contributors.count - 1 {
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
                    .id("top-\(contributor.id)")

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
                .id("other-\(contributor.id)")

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
    /// 清理所有数据
    private func clearAllData() {
        staticViewModel.clearAllData()
        // 清理 ViewModel 的贡献者数据，释放内存
        viewModel.clearContributors()
        Logger.shared.info("All contributors data cleared")
    }
}

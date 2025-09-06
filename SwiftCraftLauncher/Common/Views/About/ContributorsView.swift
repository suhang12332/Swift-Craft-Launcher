import SwiftUI

public struct ContributorsView: View {
    @StateObject private var viewModel = ContributorsViewModel()

    public init() {}

    // 静态贡献者定义
    struct StaticContributor {
        let name: String
        let url: String
        let avatar: String
        let contributions: [Contribution]
    }

    private let staticContributors: [StaticContributor] = [
        StaticContributor(
            name: "喵凹条",
            url: "https://www.instagram.com/houjustin732?igsh=MWdwdmN4d2I0Zm80bw==",
            avatar: "https://s2.loli.net/2025/08/31/JhG9oXzYBZrkRa4.png",
            contributions: [.design]
        ),
        StaticContributor(
            name: "CarnonLee",
            url: "",
            avatar: "👨‍💻",
            contributions: [.code]
        ),
        StaticContributor(
            name: "jiangyin14",
            url: "https://github.com/jiangyin14",
            avatar: "👨‍💻",
            contributions: [.code]
        ),
        StaticContributor(
            name: "逗趣狂想",
            url: "https://space.bilibili.com/3493127828540221",
            avatar: "🔧",
            contributions: [.infra]
        ),
        StaticContributor(
            name: "Nzcorz",
            url: "",
            avatar: "👩‍💻",
            contributions: [.code]
        ),
        StaticContributor(
            name: "桜子ちゃん",
            url: "",
            avatar: "👩‍💻",
            contributions: [.code]
        ),
        StaticContributor(
            name: "ZeroSnow",
            url: "https://github.com/chencomcdyun",
            avatar: "🎨",
            contributions: [.design]
        ),
        StaticContributor(
            name: "猫白GAF",
            url: "https://space.bilibili.com/508878020",
            avatar: "https://s2.loli.net/2025/08/31/KLGzDOtQ3A9qFxE.jpg",
            contributions: [.design]
        ),
        StaticContributor(
            name: "小希Lusiey_",
            url: "",
            avatar: "👩‍💻",
            contributions: [.test]
        ),
        StaticContributor(
            name: "骑老奶奶过马路",
            url: "",
            avatar: "👩‍💻",
            contributions: [.test]
        ),
        StaticContributor(
            name: "laiTM",
            url: "",
            avatar: "👩‍💻",
            contributions: [.test, .design]
        ),
    ]

    // 贡献类型枚举
    enum Contribution: String, CaseIterable {
        case code = "contributor.contribution.code"
        case design = "contributor.contribution.design"
        case test = "contributor.contribution.test"
        case feedback = "contributor.contribution.feedback"
        case documentation = "contributor.contribution.documentation"
        case infra = "contributor.contribution.infra"

        var localizedString: String {
            return rawValue.localized()
        }

        var color: Color {
            switch self {
            case .code: return .blue
            case .design: return .purple
            case .test: return .green
            case .feedback: return .orange
            case .documentation: return .indigo
            case .infra: return .red
            }
        }
    }

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
            // 只有在视图出现时才获取贡献者数据
            if viewModel.contributors.isEmpty && !viewModel.isLoading {
                Task {
                    await viewModel.fetchContributors()
                }
            }
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
            // 静态贡献者列表
            staticContributorsList
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
                    contributorRow(
                        contributor,
                        isTopContributor: true,
                        index: index
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
                contributorRow(
                    contributor,
                    isTopContributor: false,
                    index: index + viewModel.topContributors.count
                )

                if index < viewModel.otherContributors.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Contributor Row
    private func contributorRow(
        _ contributor: GitHubContributor,
        isTopContributor: Bool,
        index: Int
    ) -> some View {
        Group {
            if let url = URL(string: contributor.htmlUrl) {
                Link(destination: url) {
                    contributorRowContent(contributor, isTopContributor: isTopContributor, index: index)
                }
            } else {
                contributorRowContent(contributor, isTopContributor: isTopContributor, index: index)
            }
        }
    }

    // MARK: - Contributor Row Content
    private func contributorRowContent(
        _ contributor: GitHubContributor,
        isTopContributor: Bool,
        index: Int
    ) -> some View {
        HStack(spacing: 12) {
            // 头像
            contributorAvatar(contributor)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contributor.login)
                        .font(
                            .system(
                                size: 13,
                                weight: isTopContributor
                                ? .semibold : .regular
                            )
                        )
                        .foregroundColor(.primary)

                    if isTopContributor {
                        contributorRankBadge(index + 1)
                    }
                }

                HStack(spacing: 4) {
                    // 代码标签（统一标记为代码贡献者）
                    contributionTag(.code)

                    // 贡献次数
                    Text(
                        String(
                            format: "contributors.contributions.format"
                                .localized(),
                            viewModel.formatContributions(
                                contributor.contributions
                            )
                        )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 箭头
            Image("github-mark")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .imageScale(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Contribution Tag
    private func contributionTag(_ contribution: Contribution) -> some View {
        Text(contribution.localizedString)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .foregroundColor(contribution.color)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(lineWidth: 1)
                    .foregroundStyle(contribution.color)
                    .opacity(0.8)
            }
    }

    // MARK: - Contributor Avatar
    private func contributorAvatar(_ contributor: GitHubContributor) -> some View {
        AsyncImage(url: URL(string: contributor.avatarUrl)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            @unknown default:
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    // MARK: - Contributor Rank Badge
    private func contributorRankBadge(_ rank: Int) -> some View {
        let (color, icon) = rankBadgeStyle(rank)

        return ZStack {
            Circle()
                .fill(color.gradient)
                .frame(width: 20, height: 20)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private func rankBadgeStyle(_ rank: Int) -> (Color, String?) {
        switch rank {
        case 1:
            return (.yellow, "crown.fill")
        case 2:
            return (.gray, "2.circle.fill")
        case 3:
            return (.orange, "3.circle.fill")
        default:
            return (.accentColor, nil)
        }
    }

    // MARK: - Static Contributor Row
    private func staticContributorRow(
        _ contributor: StaticContributor
    ) -> some View {
        Group {
            if !contributor.url.isEmpty, let url = URL(string: contributor.url) {
                Link(destination: url) {
                    staticContributorContent(contributor)
                }
            } else {
                staticContributorContent(contributor)
            }
        }
    }

    private func staticContributorContent(
        _ contributor: StaticContributor
    ) -> some View {
        HStack(spacing: 12) {
            // 头像（emoji）
            if contributor.avatar.starts(with: "http") {
                AsyncImage(url: URL(string: contributor.avatar)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    @unknown default:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Text(contributor.avatar)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }

            // 信息部分
            VStack(alignment: .leading, spacing: 4) {
                // 用户名
                Text(contributor.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                // 贡献标签行
                HStack(spacing: 6) {
                    ForEach(contributor.contributions, id: \.self) { contribution in
                        contributionTag(contribution)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 显示箭头图标（如果有URL）
            if !contributor.url.isEmpty {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    private struct ActionButton: View {
        @Environment(\.openURL)
        private var openURL
        @State private var hovering = false

        let url: String
        let image: Image

        var body: some View {
            Button {
                if let url = URL(string: url) {
                    openURL(url)
                }
            } label: {
                image
                    .resizable()
                    .frame(width: 14, height: 14)
                    .imageScale(.medium)
                    .foregroundColor(hovering ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { hover in
                hovering = hover
            }
        }
    }
}

import SwiftMarkDownUI
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let iconSize: CGFloat = 75
    static let cornerRadius: CGFloat = 8
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 16
    static let galleryImageHeight: CGFloat = 160
    static let galleryImageMinWidth: CGFloat = 160
    static let galleryImageMaxWidth: CGFloat = 200
    static let categorySpacing: CGFloat = 6
    static let categoryPadding: CGFloat = 4
    static let categoryVerticalPadding: CGFloat = 2
    static let categoryCornerRadius: CGFloat = 12
}

// MARK: - ModrinthProjectDetailView
struct ModrinthProjectDetailView: View {
    let projectDetail: ModrinthProjectDetail?
    var suppressAnimations: Bool = false

    var body: some View {
        Group {
            if let project = projectDetail {
                projectDetailView(project)
            } else {
                loadingView
            }
        }
        .transaction { transaction in
            if suppressAnimations {
                transaction.animation = nil
            }
        }
    }

    // MARK: - Project Detail View
    private func projectDetailView(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader(project)
            if suppressAnimations {
                transitionPlaceholder
            } else {
                projectContent(project)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: - Project Header
    private func projectHeader(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            HStack(alignment: .top, spacing: Constants.spacing) {
                projectIcon(project)
                projectInfo(project)
            }
        }
        .padding(.horizontal, Constants.padding)
        .padding(.vertical, Constants.spacing)
    }

    private func projectIcon(_ project: ModrinthProjectDetail) -> some View {
        Group {
            if let iconUrl = project.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 80, height: 80)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .cornerRadius(Constants.cornerRadius)
                .clipped()
            }
        }
    }

    private func projectInfo(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.title2.bold())

            Text(project.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)

            projectStats(project)
        }
    }

    private func projectStats(_ project: ModrinthProjectDetail) -> some View {
        HStack(spacing: Constants.spacing) {
            Label("\(project.downloads)", systemImage: "arrow.down.circle")
            Label("\(project.followers)", systemImage: "heart")

            FlowLayout(spacing: Constants.categorySpacing) {
                ForEach(project.categories, id: \.self) { category in
                    CategoryTag(text: category)
                }
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    // MARK: - Project Content
    private func projectContent(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            descriptionView(project)
        }
        .padding(.horizontal, Constants.padding)
        .padding(.bottom, Constants.spacing)
    }

    private func descriptionView(_ project: ModrinthProjectDetail) -> some View {
        MixedMarkdownView(project.body)
    }

    private var transitionPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 120)
        }
        .padding(.horizontal, Constants.padding)
        .padding(.bottom, Constants.spacing)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        SkeletonDetailView()
            .redacted(reason: .placeholder)
            .shimmer()
    }
}

// MARK: - Skeleton Detail View
private struct SkeletonDetailView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            HStack(alignment: .top, spacing: Constants.spacing) {
                // 图标骨架
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: Constants.iconSize, height: Constants.iconSize)

                VStack(alignment: .leading, spacing: 4) {
                    // 标题骨架
                    Text("Loading Project Title")
                        .font(.title2.bold())

                    // 描述骨架
                    Text("Loading project description that would normally appear here with some details about the resource")
                        .font(.body)
                        .lineLimit(2)

                    // 统计数据骨架
                    HStack(spacing: Constants.spacing) {
                        Label("1234", systemImage: "arrow.down.circle")
                        Label("567", systemImage: "heart")

                        HStack(spacing: Constants.categorySpacing) {
                            CategoryTag(text: "Category1")
                            CategoryTag(text: "Category2")
                            CategoryTag(text: "Tag1")
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, Constants.padding)
            .padding(.vertical, Constants.spacing)

            // 内容骨架
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: index == 2 ? 80 : 16)
                        .frame(maxWidth: index % 2 == 0 ? .infinity : .infinity * 0.85)
                }
            }
            .padding(.horizontal, Constants.padding)
            .padding(.bottom, Constants.spacing)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

// MARK: - Shimmer Modifier
private struct ShimmerModifier: ViewModifier {

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

private extension View {

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Helper Views
private struct CategoryTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, Constants.categoryPadding)
            .padding(.vertical, Constants.categoryVerticalPadding)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(Constants.categoryCornerRadius)
    }
}

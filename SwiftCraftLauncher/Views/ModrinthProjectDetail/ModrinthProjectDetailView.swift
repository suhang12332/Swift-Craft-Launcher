import SwiftUI
import MarkdownUI

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
    @Binding var selectedTab: Int
    let projectDetail: ModrinthProjectDetail?
    @Binding var currentPage: Int
    @Binding var versionTotal: Int
    
    var body: some View {
        if let project = projectDetail {
            projectDetailView(project)
        }
    }
    
    // MARK: - Project Detail View
    private func projectDetailView(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader(project)
            projectContent(project)
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
            switch selectedTab {
            case 0:
                descriptionView(project)
            case 1:
                ModrinthProjectDetailVersionView(
                    currentPage: $currentPage,
                    versionTotal: $versionTotal,
                    projectId: project.id
                )
            case 2:
                ModrinthProjectDetailDependencyView(projectId: project.id,query: "mod")
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, Constants.padding)
        .padding(.bottom, Constants.spacing)
    }
    
    private func descriptionView(_ project: ModrinthProjectDetail) -> some View {
        Markdown(project.body)
//        EmptyView()
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

 


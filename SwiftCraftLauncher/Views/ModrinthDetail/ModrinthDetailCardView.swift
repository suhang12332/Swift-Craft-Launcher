import Foundation
import SwiftUI

struct ModrinthDetailCardView: View {
    // MARK: - Properties
    var project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool  // false = local, true = server
    @Binding var selectedItem: SidebarItem
    var onResourceChanged: (() -> Void)?
    /// 本地资源启用/禁用状态变更回调（仅 local 列表使用）
    var onLocalDisableStateChanged: ((ModrinthProject, Bool) -> Void)?
    @Binding var scannedDetailIds: Set<String> // 已扫描资源的 detailId Set，用于快速查找
    @State private var addButtonState: AddButtonState = .idle
    @State private var showDeleteAlert = false
    @State private var isResourceDisabled: Bool = false  // 资源是否被禁用（用于置灰效果）
    @EnvironmentObject private var gameRepository: GameRepository

    // MARK: - Enums
    enum AddButtonState {
        case idle
        case loading
        case installed
        case update  // 有新版本可用
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: ModrinthConstants.UIConstants.contentSpacing) {
            iconView
            VStack(alignment: .leading, spacing: ModrinthConstants.UIConstants.spacing) {
                titleView
                descriptionView
                tagsView
            }
            Spacer(minLength: 8)
            infoView
        }
        .frame(maxWidth: .infinity)
        .opacity(isResourceDisabled ? 0.5 : 1.0)  // 禁用时置灰
    }

    // MARK: - View Components
    private var iconView: some View {
        Group {
            // 使用 id 前缀判断本地资源，更可靠
            if project.projectId.hasPrefix("local_") || project.projectId.hasPrefix("file_") {
                // 本地资源显示 questionmark.circle 图标
                localResourceIcon
            } else if let iconUrl = project.iconUrl,
                let url = URL(string: iconUrl) {
                AsyncImage(
                    url: url,
                    transaction: Transaction(
                        animation: .easeInOut(duration: 0.2)
                    )
                ) { phase in
                    switch phase {
                    case .empty:
                        placeholderIcon
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    case .failure:
                        placeholderIcon
                    @unknown default:
                        placeholderIcon
                    }
                }
                .frame(
                    width: ModrinthConstants.UIConstants.iconSize,
                    height: ModrinthConstants.UIConstants.iconSize
                )
                .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
                .clipped()
                .onDisappear {
                    // 清理图片缓存，避免内存泄漏
                    URLCache.shared.removeCachedResponse(
                        for: URLRequest(url: url)
                    )
                }
            } else {
                placeholderIcon
            }
        }
    }

    private var placeholderIcon: some View {
        Color.gray.opacity(0.2)
            .frame(
                width: ModrinthConstants.UIConstants.iconSize,
                height: ModrinthConstants.UIConstants.iconSize
            )
            .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
    }

    private var localResourceIcon: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: ModrinthConstants.UIConstants.iconSize * 0.6))
            .foregroundColor(.secondary)
            .frame(
                width: ModrinthConstants.UIConstants.iconSize,
                height: ModrinthConstants.UIConstants.iconSize
            )
            .background(Color.gray.opacity(0.2))
            .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
    }

    private var titleView: some View {
        HStack(spacing: 4) {
            Text(project.title)
                .font(.headline)
                .lineLimit(1)
            Text("by \(project.author)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var descriptionView: some View {
        Text(project.description)
            .font(.subheadline)
            .lineLimit(ModrinthConstants.UIConstants.descriptionLineLimit)
            .foregroundColor(.secondary)
    }

    private var tagsView: some View {
        HStack(spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(
                Array(
                    project.displayCategories.prefix(
                        ModrinthConstants.UIConstants.maxTags
                    )
                ),
                id: \.self
            ) { tag in
                TagView(text: tag)
            }
            if project.displayCategories.count > ModrinthConstants.UIConstants.maxTags {
                Text(
                    "+\(project.displayCategories.count - ModrinthConstants.UIConstants.maxTags)"
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }

    private var infoView: some View {
        VStack(alignment: .trailing, spacing: ModrinthConstants.UIConstants.spacing) {
            downloadInfoView
            followerInfoView
            AddOrDeleteResourceButton(
                project: project,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                gameInfo: gameInfo,
                query: query,
                type: type,
                selectedItem: $selectedItem,
                onResourceChanged: onResourceChanged,
                scannedDetailIds: $scannedDetailIds,
                isResourceDisabled: $isResourceDisabled
            ) { isDisabled in
                onLocalDisableStateChanged?(project, isDisabled)
            }
            .environmentObject(gameRepository)
        }
    }

    private var downloadInfoView: some View {
        InfoRowView(
            icon: "arrow.down.circle",
            text: Self.formatNumber(project.downloads)
        )
    }

    private var followerInfoView: some View {
        InfoRowView(
            icon: "heart",
            text: Self.formatNumber(project.follows)
        )
    }

    // MARK: - Helper Methods
    static func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fk", Double(num) / 1_000)
        } else {
            return "\(num)"
        }
    }
}

// MARK: - Supporting Views
private struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, ModrinthConstants.UIConstants.tagHorizontalPadding)
            .padding(.vertical, ModrinthConstants.UIConstants.tagVerticalPadding)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(ModrinthConstants.UIConstants.tagCornerRadius)
    }
}

private struct InfoRowView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(text)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}

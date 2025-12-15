import SwiftUI

public struct AcknowledgementsView: View {
    @State private var libraries: [OpenSourceLibrary] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    private let gitHubService = GitHubService.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    loadingView
                } else {
                    librariesContent
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            // 每次打开都重新加载数据
            loadLibraries()
        }
        .onDisappear {
            // 页面关闭时清空数据
            clearLibrariesData()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Libraries Content
    private var librariesContent: some View {
        VStack(spacing: 0) {
            if !libraries.isEmpty {
                librariesList
            } else if loadFailed {
                errorView
            }
        }
    }

    // MARK: - Libraries List
    private var librariesList: some View {
        VStack(spacing: 0) {
            ForEach(libraries.indices, id: \.self) { index in
                libraryRow(libraries[index])

                if index < libraries.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Library Row
    private func libraryRow(_ library: OpenSourceLibrary) -> some View {
        Group {
            if let url = URL(string: library.url) {
                Link(destination: url) {
                    libraryRowContent(library)
                }
            } else {
                libraryRowContent(library)
            }
        }
    }

    // MARK: - Library Row Content
    private func libraryRowContent(_ library: OpenSourceLibrary) -> some View {
        HStack(spacing: 12) {
            // 头像
            libraryAvatar(library)

            // 信息部分
            VStack(alignment: .leading, spacing: 4) {
                // 库名称
                Text(library.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                // 描述（带 popover）
                if let description = library.description, !description.isEmpty {
                    DescriptionTextWithPopover(description: description)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 箭头图标
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Library Avatar
    private func libraryAvatar(_ library: OpenSourceLibrary) -> some View {
        Group {
            if let avatarURL = library.avatar, let avatar = URL(string: avatarURL) {
                AsyncImage(url: avatar) { phase in
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
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    @unknown default:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    }
                }
                .frame(width: 40, height: 40)
                .cornerRadius(8)
                .clipped()
            } else {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            Text("error.download.network_request_failed".localized())
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    // MARK: - Load Libraries
    private func loadLibraries() {
        // 重置状态
        isLoading = true
        loadFailed = false
        Task {
            do {
                let decodedLibraries: [OpenSourceLibrary] = try await gitHubService.fetchAcknowledgements()

                await MainActor.run {
                    libraries = decodedLibraries
                    isLoading = false
                    loadFailed = false
                    Logger.shared.info(
                        "Successfully loaded",
                        libraries.count,
                        "libraries from GitHubService"
                    )
                }
            } catch {
                Logger.shared.error("Failed to load libraries from GitHubService:", error)
                await MainActor.run {
                    loadFailed = true
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Clear Libraries Data
    private func clearLibrariesData() {
        libraries = []
        isLoading = true
        loadFailed = false
        Logger.shared.info("Libraries data cleared")
    }

    // MARK: - JSON Data Models
    private struct OpenSourceLibrary: Codable {
        let name: String
        let url: String
        let avatar: String?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case name
            case url
            case avatar
            case description
        }
    }
}

// MARK: - Description Text With Popover
private struct DescriptionTextWithPopover: View {
    let description: String
    @State private var isHovering = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Button {
            // 点击时也显示 popover
            showPopover.toggle()
        } label: {
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            // 取消之前的任务
            hoverTask?.cancel()

            if hovering {
                // 延迟显示 popover，避免鼠标快速移动时频繁显示
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    if !Task.isCancelled && isHovering {
                        await MainActor.run {
                            showPopover = true
                        }
                    }
                }
            } else {
                showPopover = false
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(minWidth: 200, maxWidth: 500)
            .fixedSize(horizontal: true, vertical: false)
        }
        .onDisappear {
            hoverTask?.cancel()
            showPopover = false
        }
    }
}

#Preview {
    AcknowledgementsView()
}

import SwiftUI

public struct AcknowledgementsView: View {
    @StateObject private var viewModel = AcknowledgementsViewModel()
    private let avatarSize: CGFloat = 40
    private let avatarCornerRadius: CGFloat = 8

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    librariesContent
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            viewModel.load()
        }
        .onDisappear {
            viewModel.clearAllData()
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
    @ViewBuilder private var librariesContent: some View {
        if viewModel.loadFailed {
            errorView
        } else if !viewModel.libraries.isEmpty {
            librariesList
        }
    }

    // MARK: - Libraries List
    private var librariesList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.libraries) { library in
                libraryRow(library)

                if library.id != viewModel.libraries.last?.id {
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
            libraryAvatar(library)

            VStack(alignment: .leading, spacing: 4) {
                Text(library.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let description = library.description, !description.isEmpty {
                    DescriptionTextWithPopover(description: description)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "globe")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Library Avatar
    @ViewBuilder
    private func libraryAvatar(_ library: OpenSourceLibrary) -> some View {
        if let avatarURL = library.avatar,
           let url = URL(string: avatarURL) {
            AsyncImage(url: url) { phase in
                avatarImage(for: phase)
            }
            .frame(width: avatarSize, height: avatarSize)
            .cornerRadius(avatarCornerRadius)
            .clipped()
            .onDisappear {
                URLCache.shared.removeCachedResponse(
                    for: URLRequest(url: url)
                )
            }
        } else {
            avatarPlaceholder()
                .frame(width: avatarSize, height: avatarSize)
                .cornerRadius(avatarCornerRadius)
        }
    }

    @ViewBuilder
    private func avatarImage(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case .empty:
            avatarPlaceholder(showLoading: true)
        case .success(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .failure:
            avatarPlaceholder()
        @unknown default:
            avatarPlaceholder()
        }
    }

    private func avatarPlaceholder(showLoading: Bool = false) -> some View {
        Rectangle()
            .foregroundColor(.gray.opacity(0.3))
            .overlay {
                if showLoading {
                    ProgressView()
                        .controlSize(.small)
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
}

// MARK: - Description Text With Popover
private struct DescriptionTextWithPopover: View {
    private static let hoverDelayNanoseconds: UInt64 = 500_000_000

    let description: String
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Button {
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
            if hovering {
                schedulePopover()
            } else {
                cancelHoverTask()
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
            .padding()
            .frame(maxWidth: 500)
            .fixedSize(horizontal: true, vertical: false)
        }
        .onDisappear {
            cancelHoverTask()
            showPopover = false
        }
    }

    private func schedulePopover() {
        cancelHoverTask()
        hoverTask = Task {
            try? await Task.sleep(nanoseconds: Self.hoverDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showPopover = true
            }
        }
    }

    private func cancelHoverTask() {
        hoverTask?.cancel()
        hoverTask = nil
    }
}

#Preview {
    AcknowledgementsView()
}

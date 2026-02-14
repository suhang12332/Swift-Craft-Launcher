import SwiftUI
import AppKit

// MARK: - Constants
private enum ScreenshotSectionConstants {
    static let thumbnailSize: CGFloat = 60
}

// MARK: - 截图信息区域视图
struct ScreenshotSectionView: View {
    // MARK: - Properties
    let screenshots: [ScreenshotInfo]
    let isLoading: Bool
    let gameName: String

    @State private var selectedScreenshot: ScreenshotInfo?

    // MARK: - Body
    var body: some View {
        GenericSectionView(
            title: "saveinfo.screenshots",
            items: screenshots,
            isLoading: isLoading,
            iconName: "photo.fill"
        ) { screenshot in
            screenshotChip(for: screenshot)
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(screenshot: screenshot, gameName: gameName)
        }
    }

    // MARK: - Chip Builder
    private func screenshotChip(for screenshot: ScreenshotInfo) -> some View {
        FilterChip(
            title: screenshot.name,
            action: {
                selectedScreenshot = screenshot
            },
            iconName: "photo.fill",
            isLoading: false,
            maxTextWidth: 150
        )
    }
}

// MARK: - Screenshot Thumbnail
struct ScreenshotThumbnail: View {
    let screenshot: ScreenshotInfo
    let action: () -> Void

    @State private var image: NSImage?

    var body: some View {
        Button(action: action) {
            Group {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.secondary)
                }
            }
            .frame(
                width: ScreenshotSectionConstants.thumbnailSize,
                height: ScreenshotSectionConstants.thumbnailSize
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task {
            loadImage()
        }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOf: screenshot.path) {
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }
}

// MARK: - Screenshot Detail View
struct ScreenshotDetailView: View {
    let screenshot: ScreenshotInfo
    let gameName: String
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .frame(minWidth: 600, minHeight: 400)
    }

    private var headerView: some View {
        HStack {
            Text(screenshot.name)
                .font(.headline)
            Spacer()
            ShareLink(item: screenshot.path) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyView: some View {
        ScrollView {
            ScreenshotImageView(path: screenshot.path)
                .frame(maxWidth: .infinity)
        }
    }

    private var footerView: some View {
        HStack {
            if let createdDate = screenshot.createdDate {
                Label {
                    Text(createdDate.formatted(date: .abbreviated, time: .standard))
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
            Button("common.close".localized()) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Screenshot Image View
struct ScreenshotImageView: View {
    let path: URL
    @State private var image: NSImage?
    @State private var isLoading: Bool = true
    @State private var loadFailed: Bool = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if loadFailed {
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("saveinfo.screenshot.load.failed".localized())
                        .foregroundColor(.secondary)
                }
            } else if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task {
            loadImage()
        }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOf: path) {
                DispatchQueue.main.async {
                    self.image = nsImage
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}

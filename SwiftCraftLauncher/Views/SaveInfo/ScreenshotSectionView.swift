import SwiftUI
import AppKit

// MARK: - Constants
private enum ScreenshotSectionConstants {
    static let maxHeight: CGFloat = 235
    static let verticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
    static let placeholderCount: Int = 5
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 320
    static let chipPadding: CGFloat = 16
    static let estimatedCharWidth: CGFloat = 10
    static let maxItems: Int = 6  // 最多显示6个
    static let maxWidth: CGFloat = 320
    static let thumbnailSize: CGFloat = 60
}

// MARK: - 截图信息区域视图
struct ScreenshotSectionView: View {
    // MARK: - Properties
    let screenshots: [ScreenshotInfo]
    let isLoading: Bool
    let gameName: String
    
    @State private var showOverflowPopover = false
    @State private var selectedScreenshot: ScreenshotInfo?
    
    // MARK: - Body
    var body: some View {
        VStack {
            headerView
            if isLoading {
                loadingPlaceholder
            } else {
                contentWithOverflow
            }
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(screenshot: screenshot, gameName: gameName)
        }
    }
    
    // MARK: - Header Views
    private var headerView: some View {
        let (_, overflowItems) = computeVisibleAndOverflowItems()
        return HStack {
            headerTitle
            Spacer()
            if !overflowItems.isEmpty {
                overflowButton(overflowItems: overflowItems)
            }
        }
        .padding(.bottom, ScreenshotSectionConstants.headerBottomPadding)
    }
    
    private var headerTitle: some View {
        Text("saveinfo.screenshots".localized())
            .font(.headline)
    }
    
    private func overflowButton(overflowItems: [ScreenshotInfo]) -> some View {
        Button {
            showOverflowPopover = true
        } label: {
            Text("+\(overflowItems.count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showOverflowPopover, arrowEdge: .leading) {
            overflowPopoverContent(overflowItems: overflowItems)
        }
    }
    
    private func overflowPopoverContent(
        overflowItems: [ScreenshotInfo]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                FlowLayout {
                    ForEach(overflowItems) { screenshot in
                        ScreenshotChip(
                            title: screenshot.name,
                            isLoading: false
                        ) {
                            selectedScreenshot = screenshot
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: ScreenshotSectionConstants.popoverMaxHeight)
        }
        .frame(width: ScreenshotSectionConstants.popoverWidth)
    }
    
    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        ScrollView {
            FlowLayout {
                ForEach(
                    0..<ScreenshotSectionConstants.placeholderCount,
                    id: \.self
                ) { _ in
                    ScreenshotChip(
                        title: "common.loading".localized(),
                        isLoading: true
                    )
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: ScreenshotSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, ScreenshotSectionConstants.verticalPadding)
    }
    
    private var contentWithOverflow: some View {
        let (visibleItems, _) = computeVisibleAndOverflowItems()
        return FlowLayout {
            ForEach(visibleItems) { screenshot in
                ScreenshotChip(
                    title: screenshot.name,
                    isLoading: false
                ) {
                    selectedScreenshot = screenshot
                }
            }
        }
        .frame(maxHeight: ScreenshotSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, ScreenshotSectionConstants.verticalPadding)
        .padding(.bottom, ScreenshotSectionConstants.verticalPadding)
    }
    
    // MARK: - Helper Methods
    private func computeVisibleAndOverflowItems() -> (
        [ScreenshotInfo], [ScreenshotInfo]
    ) {
        // 最多显示6个
        let visibleItems = Array(screenshots.prefix(ScreenshotSectionConstants.maxItems))
        let overflowItems = Array(screenshots.dropFirst(ScreenshotSectionConstants.maxItems))
        
        return (visibleItems, overflowItems)
    }
}

// MARK: - Screenshot Chip
struct ScreenshotChip: View {
    let title: String
    let isLoading: Bool
    let action: (() -> Void)?
    
    init(title: String, isLoading: Bool, action: (() -> Void)? = nil) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 4) {
                Image(systemName: "photo.fill")
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(maxWidth: 150)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
            )
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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
    @Environment(\.dismiss) private var dismiss
    
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
            HStack(spacing: 8) {
                ShareLink(item: screenshot.path) {
                    Image(systemName: "square.and.arrow.up")
                }

                .buttonStyle(.plain)

            }
            Button {
                dismiss()  // 关闭当前视图
            } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

        }
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
            
            Label {
                Text(gameName)
                    .lineLimit(1)
                    .truncationMode(.middle) // 可选：中间省略，长路径更好看
            } icon: {
                Image(systemName: "gamecontroller")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 300, alignment: .trailing)
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

// MARK: - Preview
#Preview {
    ScreenshotImageView(
        path: URL(fileURLWithPath: "/Users/su/Library/Application Support/Swift Craft Launcher/profiles/Fabulously Optimized-1.21.11-20251228-143710/screenshots/2025-12-28_14.48.23.png")
    )
    .frame(width: 600, height: 400)
}

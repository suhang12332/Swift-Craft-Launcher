import SwiftUI
import AppKit

public struct AppIconSettingsView: View {
    @StateObject private var appIconManager = AppIconManager.shared

    public init() {}

    public var body: some View {
        Form {
            LabeledContent("settings.app_icon.picker".localized()) {
                AppIconSelectorView(selectedIcon: $appIconManager.selectedIcon)
                    .fixedSize()
            }.labeledContentStyle(.custom)
        }
    }
}

// MARK: - App Icon Selector View
struct AppIconSelectorView: View {
    @Binding var selectedIcon: AppIconOption
    @StateObject private var appIconManager = AppIconManager.shared

    private let maxWidth: CGFloat = 600

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appIconManager.availableIcons, id: \.self) { icon in
                    AppIconOptionView(
                        icon: icon,
                        isSelected: selectedIcon == icon
                    ) {
                        selectedIcon = icon
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: maxWidth)
    }
}

// MARK: - App Icon Option View
struct AppIconOptionView: View {
    let icon: AppIconOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 图标预览
            let iconSize: CGFloat = isSelected ? 72 : 64
            if let iconImage = NSImage(named: icon.assetName) {
                Image(nsImage: iconImage)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .cornerRadius(8)
            }
            // 图标标签
            Text(icon.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 72)
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    AppIconSettingsView()
}

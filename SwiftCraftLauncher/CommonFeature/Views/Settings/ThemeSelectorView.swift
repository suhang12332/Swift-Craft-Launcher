import SwiftUI

// MARK: - Theme Selector View
struct ThemeSelectorView: View {
    @Binding var selectedTheme: ThemeMode

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ThemeMode.allCases, id: \.self) { theme in
                ThemeOptionView(
                    theme: theme,
                    isSelected: selectedTheme == theme
                ) {
                    selectedTheme = theme
                }
            }
        }
    }
}

// MARK: - Theme Option View
private struct ThemeOptionView: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3 : 0)
                    .frame(width: 61, height: 41)

                ThemeWindowIcon(theme: theme)
                    .frame(width: 60, height: 40)
            }

            Text(theme.localizedName)
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Theme Window Icon
private struct ThemeWindowIcon: View {
    let theme: ThemeMode

    var body: some View {
        Image(iconName)
            .resizable()
            .frame(width: 60, height: 40)
            .cornerRadius(6)
    }

    private var iconName: String {
        let isSystem26 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
        switch theme {
        case .system:
            return isSystem26 ? "AppearanceAuto_Normal_Normal" : "AppearanceAuto_Normal"
        case .light:
            return isSystem26 ? "AppearanceLight_Normal_Normal" : "AppearanceLight_Normal"
        case .dark:
            return isSystem26 ? "AppearanceDark_Normal_Normal" : "AppearanceDark_Normal"
        }
    }
}

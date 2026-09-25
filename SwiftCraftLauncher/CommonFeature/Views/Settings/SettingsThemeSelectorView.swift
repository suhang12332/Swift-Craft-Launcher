//
//  SettingsThemeSelectorView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Places the redesigned selector in a grouped settings row.
struct SettingsThemeRow: View {
    @Environment(ThemeManager.self)
    private var themeManager

    var body: some View {
        @Bindable var themeManager = themeManager
        LabeledContent("settings.theme.picker".localized()) {
            SettingsThemeSelectorView(selectedTheme: $themeManager.themeMode)
                .fixedSize()
        }
    }
}

/// A settings-form theme selector with captions integrated into each option.
struct SettingsThemeSelectorView: View {
    @Binding var selectedTheme: ThemeMode

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ThemeMode.allCases, id: \.self) { theme in
                SettingsThemeOptionView(
                    theme: theme,
                    isSelected: selectedTheme == theme,
                ) {
                    selectedTheme = theme
                }
                .applyPointerHandIfAvailable()
            }
        }
    }
}

private struct SettingsThemeOptionView: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3 : 0)
                    .frame(width: 61, height: 41)

                SettingsThemeWindowIcon(theme: theme)
                    .frame(width: 60, height: 40)
            }
            Text(theme.localizedName)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(minWidth: 60)
        }
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct SettingsThemeWindowIcon: View {
    let theme: ThemeMode

    var body: some View {
        Image(iconName)
            .resizable()
            .frame(width: 60, height: 40)
            .cornerRadius(6)
    }

    private var iconName: String {
        switch theme {
        case .system:
            return "AppearanceAuto_Normal"
        case .light:
            return "AppearanceLight_Normal"
        case .dark:
            return "AppearanceDark_Normal"
        }
    }
}

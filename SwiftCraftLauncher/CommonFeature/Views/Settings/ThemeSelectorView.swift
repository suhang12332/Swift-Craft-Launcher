//
//  ThemeSelectorView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for selecting a theme mode from available options.
struct ThemeSelectorView: View {
    @Binding var selectedTheme: ThemeMode

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ThemeMode.allCases, id: \.self) { theme in
                ThemeOptionView(
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

struct ThemeSelectorLabel: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(ThemeMode.allCases, id: \.self) { theme in
                Text(theme.localizedName)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .frame(minWidth: 60, alignment: .center)
            }
        }
    }
}

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
        }
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct ThemeWindowIcon: View {
    let theme: ThemeMode

    var body: some View {
        // Preview thumbnail is loaded at runtime from the macOS Appearance
        // settings extension. No image asset is bundled in the app.
        Image(assetName, bundle: SystemAppearanceBundle.value)
            .resizable()
            .frame(width: 60, height: 40)
            .cornerRadius(6)
    }

    private var assetName: String {
        switch theme {
        case .light: "AppearanceLight"
        case .dark: "AppearanceDark"
        case .system: "AppearanceAuto"
        }
    }
}

/// The system extension that ships the light/dark/auto preview images shown in
/// System Settings → Appearance. Its asset catalog is read directly at runtime.
private enum SystemAppearanceBundle {
    static let value = Bundle(
        path: "/System/Library/ExtensionKit/Extensions/Appearance.appex",
    )
}

//
//  GeneralSettingsSections.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// A row that displays the current language and opens system language settings.
struct GeneralSettingsLanguageRow: View {
    let languageManager: LanguageManager

    var body: some View {
        LabeledContent("settings.language.picker".localized()) {
            Button {
                SystemSettings.open(AppConstants.SystemSettingsDeepLinks.localizationApps)
            } label: {
                Text(languageManager.selectedLanguageDisplayName)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .help("settings.language.picker".localized())
        }
        .labeledContentStyle(.custom)
        CommonDescriptionText(text: "settings.language.translation.notice".localized())
            .padding(.bottom, 10)
    }
}

/// A row with a theme picker selector.
struct GeneralSettingsThemeRow: View {
    @Environment(ThemeManager.self)
    private var themeManager

    var body: some View {
        @Bindable var themeManager = themeManager
        Group {
            LabeledContent("settings.theme.picker".localized()) {
                ThemeSelectorView(selectedTheme: $themeManager.themeMode)
                    .fixedSize()
            }
            .labeledContentStyle(.custom)
            ThemeSelectorLabel()
        }
    }
}

/// A row for choosing the interface layout style.
struct GeneralSettingsInterfaceLayoutRow: View {
    @Environment(GeneralSettingsManager.self)
    private var generalSettings

    var body: some View {
        @Bindable var generalSettings = generalSettings
        LabeledContent("settings.interface_style.label".localized()) {
            Picker("", selection: $generalSettings.interfaceLayoutStyle) {
                ForEach(InterfaceLayoutStyle.allCases, id: \.self) { style in
                    Text(style.localizedName).tag(style)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        .labeledContentStyle(.custom)
        .padding(.bottom, 10)
    }
}

/// A row for configuring the launcher working directory.
struct GeneralSettingsWorkingDirectoryRow: View {
    @Environment(GeneralSettingsManager.self)
    private var generalSettings
    @Bindable var viewModel: GeneralSettingsViewModel
    var gameRepository: GameRepository

    var body: some View {
        LabeledContent("settings.launcher_working_directory".localized()) {
            VStack(alignment: .leading, spacing: 8) {
                if !gameRepository.workingPathOptions.isEmpty {
                    Picker("", selection: Binding(
                        get: {
                            generalSettings.launcherWorkingDirectory.isEmpty
                                ? AppPaths.launcherSupportDirectory.path
                                : generalSettings.launcherWorkingDirectory
                        },
                        set: { generalSettings.launcherWorkingDirectory = $0 },
                    )) {
                        ForEach(gameRepository.workingPathOptions, id: \.path) { item in
                            Text(viewModel.workingPathDisplayString(for: item))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .tag(item.path)
                                .help(item.path)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                DirectorySettingRow(
                    title: "settings.launcher_working_directory".localized(),
                    path: generalSettings.launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : generalSettings.launcherWorkingDirectory,
                    description: "settings.working_directory.description".localized(),
                    onChoose: { viewModel.showDirectoryPicker = true },
                    onReset: { viewModel.resetWorkingDirectorySafely() },
                )
                .fixedSize()
                .fileImporter(isPresented: $viewModel.showDirectoryPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    viewModel.handleDirectoryImport(result)
                }
            }
        }
        .labeledContentStyle(.custom)
        .onAppear {
            Task { await gameRepository.refreshWorkingPathOptions() }
        }
        .onChange(of: generalSettings.launcherWorkingDirectory) { _, _ in
            viewModel.onWorkingDirectoryChanged()
        }
    }
}

/// A row with a slider for the maximum concurrent download count.
struct GeneralSettingsConcurrentDownloadsRow: View {
    @Environment(GeneralSettingsManager.self)
    private var generalSettings
    @Bindable var viewModel: GeneralSettingsViewModel

    var body: some View {
        LabeledContent("settings.concurrent_downloads.label".localized()) {
            HStack {
                Slider(
                    value: $viewModel.concurrentDownloadsDraft,
                    in: 1 ... 64,
                ) { isEditing in
                    viewModel.commitConcurrentDownloadsIfNeeded(isEditing: isEditing)
                }
                .controlSize(.mini)

                Text("\(Int(viewModel.concurrentDownloadsDraft.rounded()))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
            .frame(width: 200)
            .gridColumnAlignment(.leading)
            .labelsHidden()
        }
        .labeledContentStyle(.custom)
        .onAppear { viewModel.onAppearSyncConcurrentDownloads() }
        .onChange(of: generalSettings.concurrentDownloads) { _, newValue in
            viewModel.onConcurrentDownloadsChanged(newValue)
        }
    }
}

/// A row that opens system network proxy settings.
struct GeneralSettingsSystemProxyRow: View {
    var body: some View {
        LabeledContent("settings.system_proxy.label".localized()) {
            Button("settings.system_proxy.open".localized()) {
                SystemSettings.open(AppConstants.SystemSettingsDeepLinks.networkProxies)
            }
        }
        .labeledContentStyle(.custom)
    }
}

/// A row to toggle the common sheet height limit.
struct GeneralSettingsCommonSheetHeightLimitRow: View {
    @Environment(GeneralSettingsManager.self)
    private var generalSettings

    var body: some View {
        @Bindable var generalSettings = generalSettings
        LabeledContent("settings.common_sheet_height_limit.label".localized()) {
            Toggle(
                "settings.common_sheet_height_limit.enable".localized(),
                isOn: $generalSettings.limitCommonSheetHeight,
            )
        }
        .labeledContentStyle(.custom)
    }
}

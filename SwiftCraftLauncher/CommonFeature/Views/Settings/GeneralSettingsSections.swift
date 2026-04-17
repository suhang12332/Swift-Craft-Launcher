import AppKit
import SwiftUI

struct GeneralSettingsLanguageRow: View {
    var body: some View {
        Group {
            LabeledContent("settings.language.picker".localized()) {
                Button {
                    SystemSettings.open(AppConstants.SystemSettingsDeepLinks.localizationApps)
                } label: {
                    Text(LanguageManager.shared.selectedLanguageDisplayName)
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
}

struct GeneralSettingsThemeRow: View {
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
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

struct GeneralSettingsInterfaceLayoutRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager

    var body: some View {
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

struct GeneralSettingsWorkingDirectoryRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @ObservedObject var gameRepository: GameRepository

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
                        set: { generalSettings.launcherWorkingDirectory = $0 }
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
                    onReset: { viewModel.resetWorkingDirectorySafely() }
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

struct GeneralSettingsConcurrentDownloadsRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        LabeledContent("settings.concurrent_downloads.label".localized()) {
            HStack {
                Slider(
                    value: $viewModel.concurrentDownloadsDraft,
                    in: 1...64
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

struct GeneralSettingsGitHubProxyRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager

    var body: some View {
        LabeledContent("settings.github_proxy.label".localized()) {
            VStack(alignment: .leading) {
                HStack {
                    Toggle("", isOn: $generalSettings.enableGitHubProxy)
                        .labelsHidden()
                    Text("settings.github_proxy.enable".localized())
                }
                HStack(spacing: 8) {
                    TextField("", text: $generalSettings.gitProxyURL)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .focusable(false)
                        .disabled(!generalSettings.enableGitHubProxy)
                    Button("settings.github_proxy.reset_default".localized()) {
                        generalSettings.gitProxyURL = "https://gh-proxy.com"
                    }
                    .disabled(!generalSettings.enableGitHubProxy)
                }
                CommonDescriptionText(text: "settings.github_proxy.description".localized())
            }
        }
        .labeledContentStyle(.custom)
        .padding(.top, 10)
    }
}

struct GeneralSettingsCommonSheetHeightLimitRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager

    var body: some View {
        LabeledContent("settings.common_sheet_height_limit.label".localized()) {
            Toggle(
                "settings.common_sheet_height_limit.enable".localized(),
                isOn: $generalSettings.limitCommonSheetHeight
            )
        }
        .labeledContentStyle(.custom)
    }
}

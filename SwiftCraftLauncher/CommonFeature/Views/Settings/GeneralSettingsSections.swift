import SwiftUI

struct GeneralSettingsLanguageRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        LabeledContent("settings.language.picker".localized()) {
            Picker("", selection: $viewModel.selectedLanguage) {
                ForEach(LanguageManager.shared.languages, id: \.1) { name, code in
                    Text(name).tag(code)
                }
            }
            .labelsHidden()
            .fixedSize()
            .onChange(of: viewModel.selectedLanguage) { _, newValue in
                viewModel.onSelectedLanguageChanged(newValue)
            }
            .confirmationDialog(
                "settings.language.restart.title".localized(),
                isPresented: $viewModel.showingRestartAlert,
                titleVisibility: .visible
            ) {
                Button("settings.language.restart.confirm".localized(), role: .destructive) {
                    viewModel.confirmLanguageChangeAndRestart()
                }
                .keyboardShortcut(.defaultAction)
                Button("common.cancel".localized(), role: .cancel) {
                    viewModel.cancelLanguageChange()
                }
            } message: {
                Text("settings.language.restart.message".localized())
            }
        }
        .labeledContentStyle(.custom)
        .padding(.bottom, 10)
    }
}

struct GeneralSettingsThemeRow: View {
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        LabeledContent("settings.theme.picker".localized()) {
            ThemeSelectorView(selectedTheme: $themeManager.themeMode)
                .fixedSize()
        }
        .labeledContentStyle(.custom)
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
        .labeledContentStyle(.custom(alignment: .firstTextBaseline))
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

struct GeneralSettingsGitHubProxyRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager

    var body: some View {
        LabeledContent("settings.github_proxy.label".localized()) {
            VStack(alignment: .leading) {
                HStack {
                    Toggle("", isOn: $generalSettings.enableGitHubProxy)
                        .labelsHidden()
                    Text("settings.github_proxy.enable".localized())
                        .font(.callout)
                        .foregroundColor(.primary)
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
                    InfoIconWithPopover(text: "settings.github_proxy.description".localized())
                }
            }
        }
        .labeledContentStyle(.custom(alignment: .firstTextBaseline))
        .padding(.top, 10)
    }
}

struct GeneralSettingsResourceCacheRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager

    var body: some View {
        LabeledContent("settings.resource_cache.label".localized()) {
            Toggle(
                "settings.resource_cache.enable".localized(),
                isOn: $generalSettings.enableResourcePageCache
            )
            .toggleStyle(.checkbox)
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
            .toggleStyle(.checkbox)
        }
        .labeledContentStyle(.custom)
    }
}

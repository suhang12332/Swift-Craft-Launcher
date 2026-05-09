import SwiftUI
import UniformTypeIdentifiers

// MARK: - Game Form Mode
enum GameFormMode {
    case creation
    case modPackImport(file: URL, shouldProcess: Bool)
    case launcherImport

    var isImportMode: Bool {
        switch self {
        case .creation:
            return false
        case .modPackImport, .launcherImport:
            return true
        }
    }
}

// MARK: - GameFormView
struct GameFormView: View {
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    // MARK: - File Picker Type
    enum FilePickerType {
        case modPack
        case gameIcon
    }

    // MARK: - State
    @State private var isDownloading = false
    @State private var isFormValid = false
    @State private var triggerConfirm = false
    @State private var triggerCancel = false
    @State private var showFilePicker = false
    @State private var filePickerType: FilePickerType = .modPack
    @State private var mode: GameFormMode
    @State private var isModPackParsed = false
    @State private var imagePickerHandler: ((Result<[URL], Error>) -> Void)?
    @StateObject private var importViewModel = GameFormImportViewModel()

    private enum ImportModePickerValue: Hashable {
        case manual
        case modPack
        case launcherImport
    }

    init(initialMode: GameFormMode = .creation) {
        _mode = State(initialValue: initialMode)
    }

    // MARK: - Body
    @ViewBuilder var body: some View {
        let content = CommonSheetView(
            header: { headerView },
            body: {

                VStack {
                    switch mode {
                    case .creation:
                        GameCreationView(
                            isDownloading: $isDownloading,
                            isFormValid: $isFormValid,
                            triggerConfirm: $triggerConfirm,
                            triggerCancel: $triggerCancel,
                            onCancel: { dismiss() },
                            onConfirm: { dismiss() },
                            onRequestImagePicker: {
                                filePickerType = .gameIcon
                                showFilePicker = true
                            },
                            onSetImagePickerHandler: { handler in
                                imagePickerHandler = handler
                            }
                        )
                    case let .modPackImport(file, shouldProcess):
                        ModPackImportView(
                            configuration: GameFormConfiguration(
                                isDownloading: $isDownloading,
                                isFormValid: $isFormValid,
                                triggerConfirm: $triggerConfirm,
                                triggerCancel: $triggerCancel,
                                onCancel: { dismiss() },
                                onConfirm: { dismiss() }
                            ),
                            preselectedFile: file,
                            shouldStartProcessing: shouldProcess
                        ) { isProcessing in
                            if !isProcessing {
                                if case .modPackImport(let file, _) = mode {
                                    mode = .modPackImport(file: file, shouldProcess: false)
                                }
                                isModPackParsed = true
                            }
                        }
                        .id(file)
                    case .launcherImport:
                        LauncherImportView(
                            configuration: GameFormConfiguration(
                                isDownloading: $isDownloading,
                                isFormValid: $isFormValid,
                                triggerConfirm: $triggerConfirm,
                                triggerCancel: $triggerCancel,
                                onCancel: { dismiss() },
                                onConfirm: { dismiss() }
                            )
                        )
                    }
                }
            },
            footer: { footerView }
        )

        // 当处于“导入启动器”模式时，避免在父视图再挂一个 fileImporter，
        // 让子视图的 fileImporter 正常工作
        if case .launcherImport = mode {
            content
        } else {
            content
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: {
                        switch filePickerType {
                        case .modPack:
                            return [
                                UTType(filenameExtension: AppConstants.FileExtensions.mrpack) ?? UTType.data,
                                .zip,
                                UTType(filenameExtension: AppConstants.FileExtensions.zip) ?? UTType.zip,
                            ]
                        case .gameIcon:
                            return [.png, .jpeg, .gif]
                        }
                    }(),
                    allowsMultipleSelection: false
                ) { result in
                    switch filePickerType {
                    case .modPack:
                        Task {
                            if let newMode = await importViewModel.prepareModPackImportMode(from: result) {
                                mode = newMode
                                isModPackParsed = false
                            }
                        }
                    case .gameIcon:
                        imagePickerHandler?(result)
                    }
                }
        }
    }

    // MARK: - View Components
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text(currentModeTitle)
                    .font(.headline)
                Spacer()
                importModePicker
            }
        }
    }

    private var currentModeTitle: String {
        switch mode {
        case .creation:
            return "game.form.mode.manual".localized()
        case .modPackImport:
            return "modpack.import.title".localized()
        case .launcherImport:
            return "launcher.import.title".localized()
        }
    }

    private var importModePickerSelection: Binding<ImportModePickerValue> {
        Binding(
            get: {
                switch mode {
                case .creation:
                    return .manual
                case .modPackImport:
                    return .modPack
                case .launcherImport:
                    return .launcherImport
                }
            },
            set: { newValue in
                switch newValue {
                case .manual:
                    mode = .creation
                case .launcherImport:
                    mode = .launcherImport
                case .modPack:
                    if case .launcherImport = mode {
                        mode = .creation
                    }
                    filePickerType = .modPack
                    DispatchQueue.main.async {
                        showFilePicker = true
                    }
                }
            }
        )
    }

    private var importModePicker: some View {
        Picker("", selection: importModePickerSelection) {
            Text("game.form.mode.manual".localized())
                .tag(ImportModePickerValue.manual)
            Text("modpack.import.title".localized())
                .tag(ImportModePickerValue.modPack)
            Text("launcher.import.title".localized())
                .tag(ImportModePickerValue.launcherImport)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize(horizontal: true, vertical: false)
        .help("game.form.mode.import".localized())
    }

    private var footerView: some View {
        HStack {
            cancelButton
            Spacer()
            confirmButton
        }
    }

    private var cancelButton: some View {
        Button {
            if isDownloading {
                // 当正在下载时，触发取消处理逻辑
                triggerCancel = true
            } else {
                // 非下载状态直接关闭窗口
                dismiss()
            }
        } label: {
            Text(isDownloading ? "common.stop".localized() : "common.cancel".localized())
        }
        .keyboardShortcut(.cancelAction)
    }

    private var confirmButton: some View {
        Button {
            triggerConfirm = true
        } label: {
            HStack {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    let buttonText: String = {
                        switch mode {
                        case .modPackImport:
                            return "modpack.import.button".localized()
                        case .launcherImport:
                            return "launcher.import.button".localized()
                        case .creation:
                            return "common.confirm".localized()
                        }
                    }()
                    Text(buttonText)
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isFormValid || isDownloading)
    }

    // MARK: - Helper Methods
}

#Preview {
    GameFormView()
}

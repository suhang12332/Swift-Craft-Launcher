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
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
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
    @State private var mode: GameFormMode = .creation
    @State private var isModPackParsed = false
    @State private var imagePickerHandler: ((Result<[URL], Error>) -> Void)?
    @State private var showImportPicker = false

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
                                UTType(filenameExtension: "mrpack") ?? UTType.data,
                                .zip,
                                UTType(filenameExtension: "zip") ?? UTType.zip,
                            ]
                        case .gameIcon:
                            return [.png, .jpeg, .gif]
                        }
                    }(),
                    allowsMultipleSelection: false
                ) { result in
                    switch filePickerType {
                    case .modPack:
                        handleModPackFileSelection(result)
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
                Text("\(currentModeTitle)")
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

    private var importModePicker: some View {
        Menu {
            Button {
                mode = .creation
            } label: {
                Label("game.form.mode.manual".localized(), systemImage: "square.and.pencil")
            }

            Button {
                // 先切换到非 launcherImport 模式
                if case .launcherImport = mode {
                    mode = .creation
                }
                filePickerType = .modPack
                // 异步等待视图更新
                DispatchQueue.main.async {
                    showFilePicker = true
                }
            } label: {
                Label("modpack.import.title".localized(), systemImage: "square.and.arrow.up")
            }

            Button {
                mode = .launcherImport
            } label: {
                Label("launcher.import.title".localized(), systemImage: "arrow.down.doc")
            }
        } label: {
            Text(currentModeTitle)
        }
        .fixedSize()
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

    private func handleModPackFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "无法访问所选文件",
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification
                )
                GlobalErrorHandler.shared.handle(globalError)
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            // 复制文件到临时目录以便后续使用
            do {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("modpack_import")
                    .appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(
                    at: tempDir,
                    withIntermediateDirectories: true
                )

                let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: tempFile)

                // 切换到导入模式并开始处理
                mode = .modPackImport(file: tempFile, shouldProcess: true)
                isModPackParsed = false
            } catch {
                let globalError = GlobalError.from(error)
                GlobalErrorHandler.shared.handle(globalError)
            }

        case .failure(let error):
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
        }
    }
}

#Preview {
    GameFormView()
}

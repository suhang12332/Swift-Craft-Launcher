import SwiftUI
import UniformTypeIdentifiers

// MARK: - Game Form Mode
enum GameFormMode {
    case creation
    case modPackImport(file: URL, shouldProcess: Bool)

    var isImportMode: Bool {
        switch self {
        case .creation:
            return false
        case .modPackImport:
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

    // MARK: - State
    @State private var isDownloading = false
    @State private var isFormValid = false
    @State private var triggerConfirm = false
    @State private var triggerCancel = false
    @State private var showModPackFilePicker = false
    @State private var mode: GameFormMode = .creation
    @State private var isModPackParsed = false

    // MARK: - Body
    var body: some View {
        CommonSheetView(
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
                            onConfirm: { dismiss() }
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
                    }
                }
            },
            footer: { footerView }
        )
        .fileImporter(
            isPresented: $showModPackFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "mrpack") ?? UTType.data,
                .zip,
                UTType(filenameExtension: "zip") ?? UTType.zip,
            ],
            allowsMultipleSelection: false
        ) { result in
            handleModPackFileSelection(result)
        }
    }

    // MARK: - View Components
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("game.form.title".localized())
                    .font(.headline)
                Spacer()
                // 只在创建模式或未解析完成时显示导入按钮
                if !mode.isImportMode || !isModPackParsed {
                    let buttonText = "game.form.mode.import".localized()
                    let buttonImage = "document.badge.arrow.up"

                    Button(
                        action: {
                            showModPackFilePicker = true
                        },
                        label: {
                            Label(buttonText, systemImage: buttonImage)
                                .labelStyle(.iconOnly)
                                .font(.title3)
                                .fontWeight(.regular)
                        }
                    )
                    .buttonStyle(.borderless)
                    .help(buttonText)
                }
            }
        }
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
                    Text(mode.isImportMode ? "modpack.import.button".localized() : "common.confirm".localized())
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

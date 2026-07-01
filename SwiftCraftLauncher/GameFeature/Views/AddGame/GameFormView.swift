//
//  GameFormView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A form view for creating games or importing mod packs.
import SwiftUI
import UniformTypeIdentifiers

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

struct GameFormView: View {
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    enum FilePickerType {
        case modPack
        case gameIcon
    }

    @State private var isDownloading = false
    @State private var isFormValid = false
    @State private var triggerConfirm = false
    @State private var triggerCancel = false
    @State private var isLoadingLoaderVersions = false
    @State private var showFilePicker = false
    @State private var filePickerType: FilePickerType = .modPack
    @State private var mode: GameFormMode
    @State private var isModPackParsed = false
    @State private var imagePickerHandler: ((Result<[URL], Error>) -> Void)?
    @StateObject private var importViewModel = GameFormImportViewModel()

    private enum ImportModePickerValue: Hashable {
        case manual
        case modPack
    }

    init(initialMode: GameFormMode = .creation) {
        _mode = State(initialValue: initialMode)
    }

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
                            isLoadingLoaderVersions: $isLoadingLoaderVersions,
                            onCancel: { dismiss() },
                            onConfirm: { dismiss() },
                            onRequestImagePicker: {
                                filePickerType = .gameIcon
                                showFilePicker = true
                            },
                            onSetImagePickerHandler: { handler in
                                imagePickerHandler = handler
                            },
                        )
                    case let .modPackImport(file, shouldProcess):
                        ModPackImportView(
                            configuration: GameFormConfiguration(
                                isDownloading: $isDownloading,
                                isFormValid: $isFormValid,
                                triggerConfirm: $triggerConfirm,
                                triggerCancel: $triggerCancel,
                                onCancel: { dismiss() },
                                onConfirm: { dismiss() },
                            ),
                            preselectedFile: file,
                            shouldStartProcessing: shouldProcess,
                        ) { isProcessing in
                            if !isProcessing {
                                if case let .modPackImport(file, _) = mode {
                                    mode = .modPackImport(file: file, shouldProcess: false)
                                }
                                isModPackParsed = true
                            }
                        }
                        .id(file)
                    }
                }
            },
            footer: { footerView },
        )
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
            allowsMultipleSelection: false,
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

    private var headerView: some View {
        HStack {
            Text(currentModeTitle)
                .font(.headline)
            Spacer()
            importModePicker
        }
    }

    private var currentModeTitle: String {
        switch mode {
        case .creation:
            return "game.form.mode.manual".localized()
        case .modPackImport:
            return "modpack.import.title".localized()
        }
    }

    private func selectImportMode(_ newValue: ImportModePickerValue) {
        isFormValid = false
        isLoadingLoaderVersions = false
        switch newValue {
        case .manual:
            mode = .creation
        case .modPack:
            filePickerType = .modPack
            DispatchQueue.main.async {
                showFilePicker = true
            }
        }
    }

    private var importModePicker: some View {
        Menu {
            Button("game.form.mode.manual".localized()) {
                selectImportMode(.manual)
            }
            Button("modpack.import.title".localized()) {
                selectImportMode(.modPack)
            }
        } label: {
            Text(currentModeTitle)
        }
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
                triggerCancel = true
            } else {
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
                if isDownloading || isLoadingLoaderVersions {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    let buttonText: String = {
                        switch mode {
                        case .modPackImport:
                            return "modpack.import.button".localized()
                        case .creation:
                            return "common.confirm".localized()
                        }
                    }()
                    Text(buttonText)
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isFormValid || isDownloading || isLoadingLoaderVersions)
    }
}

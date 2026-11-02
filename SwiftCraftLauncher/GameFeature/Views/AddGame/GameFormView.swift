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
    case modPack(ModPackInstallSource)
}

struct GameFormView: View {
    @Environment(GameRepository.self)
    private var gameRepository
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
    @State private var imagePickerHandler: ((Result<[URL], Error>) -> Void)?
    @State private var importViewModel = GameFormImportViewModel()

    private enum ImportModePickerValue: Hashable {
        case manual
        case modPack
        case download
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
                    case let .modPack(source):
                        ModPackInstallView(
                            source: source,
                            configuration: GameFormConfiguration(
                                isDownloading: $isDownloading,
                                isFormValid: $isFormValid,
                                triggerConfirm: $triggerConfirm,
                                triggerCancel: $triggerCancel,
                                isLoadingLoaderVersions: $isLoadingLoaderVersions,
                                onCancel: { dismiss() },
                                onConfirm: { dismiss() },
                            ),
                        )
                        .id(source.id)
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
                    if let file = await importViewModel.prepareModPackFile(from: result) {
                        mode = .modPack(.local(file))
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
            if showsImportModePicker {
                importModePicker
            }
        }
    }

    private var showsImportModePicker: Bool {
        if case .modPack(.project) = mode {
            return false
        }
        return true
    }

    private var currentModeTitle: String {
        switch mode {
        case .creation:
            return "game.form.mode.manual".localized()
        case let .modPack(source):
            switch source {
            case .local:
                return "modpack.import.title".localized()
            case .remoteURL:
                return "global_resource.download".localized()
            case .project:
                return "modpack.download.title".localized()
            }
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
            showFilePicker = true
        case .download:
            mode = .modPack(.remoteURL)
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
            Button("global_resource.download".localized()) {
                selectImportMode(.download)
            }
        } label: {
            Text(currentModeTitle)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help("modpack.import.title".localized())
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
            triggerCancel = true
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
                        case .creation:
                            return "common.confirm".localized()
                        case let .modPack(source):
                            switch source {
                            case .local:
                                return "modpack.import.button".localized()
                            case .remoteURL:
                                return "common.confirm".localized()
                            case .project:
                                return "global_resource.download".localized()
                            }
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

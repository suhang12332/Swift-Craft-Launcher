//
//  GameCreationView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A view for creating a new game instance with version, mod loader, and name configuration.
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

private enum Constants {
    static let formSpacing: CGFloat = 16
    static let iconSize: CGFloat = 80
    static let cornerRadius: CGFloat = 12
    static let maxImageSize: CGFloat = 1024
    static let versionGridColumns = 6
    static let versionPopoverMinWidth: CGFloat = 320
    static let versionPopoverMaxHeight: CGFloat = 360
    static let versionButtonPadding: CGFloat = 6
    static let versionButtonVerticalPadding: CGFloat = 3
}

struct GameCreationView: View {
    @State private var viewModel: GameCreationViewModel
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>
    private let onRequestImagePicker: () -> Void
    private let onSetImagePickerHandler: (@escaping (Result<[URL], Error>) -> Void) -> Void

    init(
        isDownloading: Binding<Bool>,
        isFormValid: Binding<Bool>,
        triggerConfirm: Binding<Bool>,
        triggerCancel: Binding<Bool>,
        isLoadingLoaderVersions: Binding<Bool> = .constant(false),
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        onRequestImagePicker: @escaping () -> Void,
        onSetImagePickerHandler: @escaping (@escaping (Result<[URL], Error>) -> Void) -> Void,
    ) {
        self.triggerConfirm = triggerConfirm
        self.triggerCancel = triggerCancel
        self.onRequestImagePicker = onRequestImagePicker
        self.onSetImagePickerHandler = onSetImagePickerHandler
        let configuration = GameFormConfiguration(
            isDownloading: isDownloading,
            isFormValid: isFormValid,
            triggerConfirm: triggerConfirm,
            triggerCancel: triggerCancel,
            isLoadingLoaderVersions: isLoadingLoaderVersions,
            onCancel: onCancel,
            onConfirm: onConfirm,
        )
        _viewModel = State(wrappedValue: GameCreationViewModel(configuration: configuration))
    }

    var body: some View {
        formContentView
            .onAppear {
                viewModel.setup(gameRepository: gameRepository, playerListViewModel: playerListViewModel)
                onSetImagePickerHandler(viewModel.handleImagePickerResult)
            }
            .gameFormStateListeners(viewModel: viewModel, triggerConfirm: triggerConfirm, triggerCancel: triggerCancel)
            .onChange(of: viewModel.selectedLoaderVersion) { oldValue, newValue in
                if oldValue != newValue {
                    viewModel.updateParentState()
                }
            }
            .onChange(of: viewModel.selectedModLoader) { oldValue, newLoader in
                if oldValue != newLoader {
                    viewModel.handleModLoaderChange(newLoader)
                }
            }
            .onChange(of: viewModel.selectedGameVersion) { oldValue, newVersion in
                if oldValue != newVersion {
                    viewModel.handleGameVersionChange(newVersion)
                }
            }
            .onDisappear {
                clearAllData()
            }
    }

    private func clearAllData() {
        if viewModel.isDownloading {
            viewModel.handleCancel()
        }
        viewModel.clearLoadedVersionsOnClose()
    }

    private var formContentView: some View {
        VStack {
            gameIconAndVersionSection
            if viewModel.selectedModLoader != GameLoader.vanilla.displayName {
                loaderVersionPicker
            }
            gameNameSection

            if viewModel.shouldShowProgress {
                downloadProgressSection
            }
        }
    }

    private var gameIconAndVersionSection: some View {
        FormSection {
            HStack(alignment: .top, spacing: Constants.formSpacing) {
                gameIconView
                    .padding(.trailing, 6)
                gameVersionAndLoaderView
            }
        }
    }

    private var gameIconView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.icon".localized())
                .font(.headline)

            iconContainer
                .applyPointerHandIfAvailable()
                .onTapGesture {
                    if !viewModel.gameSetupService.downloadState.isDownloading {
                        onRequestImagePicker()
                    }
                }
                .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers in
                    if !viewModel.gameSetupService.downloadState.isDownloading {
                        return viewModel.handleImageDrop(providers)
                    } else {
                        return false
                    }
                }
        }
        .disabled(viewModel.gameSetupService.downloadState.isDownloading)
    }

    private var iconContainer: some View {
        ZStack {
            if let url = viewModel.pendingIconURLForDisplay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
                            .frame(
                                width: Constants.iconSize,
                                height: Constants.iconSize,
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: Constants.cornerRadius,
                                ),
                            )
                            .contentShape(Rectangle())
                    case .failure:
                        iconPlaceholderView
                    default:
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .onDisappear {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
                }
                .id(url.absoluteString)
            } else {
                iconPlaceholderView
            }
        }
        .frame(width: Constants.iconSize, height: Constants.iconSize)
    }

    private var iconPlaceholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .fontWeight(.regular)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(emptyDropBackground())
    }

    private var gameVersionAndLoaderView: some View {
        VStack(alignment: .leading, spacing: Constants.formSpacing) {
            modLoaderPicker
            versionPicker
        }
    }

    private var versionPicker: some View {
        @Bindable var vm = viewModel
        return CustomVersionPicker(
            selected: $vm.selectedGameVersion,
            availableVersions: viewModel.availableVersions,
            time: $vm.versionTime,
        ) { version in
            await ModrinthService.queryVersionTime(from: version)
        }
        .disabled(viewModel.gameSetupService.downloadState.isDownloading)
    }

    private var modLoaderPicker: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            Text("game.form.modloader".localized())
                .font(.headline)
            CommonMenuPicker(
                selection: $vm.selectedModLoader,
            ) {
                ForEach(AppConstants.modLoaders, id: \.self) { loader in
                    switch loader {
                    case GameLoader.vanilla.displayName:
                        Text("modloader.vanilla.text".localized()).tag(loader)
                    case GameLoader.fabric.displayName:
                        Text("modloader.fabric.text".localized()).tag(loader)
                    case GameLoader.forge.displayName:
                        Text("modloader.forge.text".localized()).tag(loader)
                    case GameLoader.neoforge.displayName:
                        Text("modloader.neoforge.text".localized()).tag(loader)
                    case GameLoader.quilt.rawValue:
                        Text("modloader.quilt.text".localized()).tag(loader)
                    default:
                        Text(loader.capitalized).tag(loader)
                    }
                }
            }
            .disabled(viewModel.gameSetupService.downloadState.isDownloading)
        }
        .onChange(of: viewModel.selectedModLoader) { _, _ in
            viewModel.availableLoaderVersions = []
        }
    }

    private var loaderVersionPicker: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("game.form.loader.version".localized())
                    .font(.headline)
                Spacer()
                if viewModel.isLoadingLoaderVersions {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.85)
                }
            }
            CommonMenuPicker(
                selection: $vm.selectedLoaderVersion,
            ) {
                ForEach(viewModel.availableLoaderVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .disabled(viewModel.gameSetupService.downloadState.isDownloading || viewModel.availableLoaderVersions.isEmpty)
        }
    }

    private var gameNameSection: some View {
        FormSection {
            GameNameInputView(
                gameName: Binding(
                    get: { viewModel.gameNameValidator.gameName },
                    set: { viewModel.gameNameValidator.gameName = $0 },
                ),
                isGameNameDuplicate: Binding(
                    get: { viewModel.gameNameValidator.isGameNameDuplicate },
                    set: { viewModel.gameNameValidator.isGameNameDuplicate = $0 },
                ),
                isDisabled: viewModel.gameSetupService.downloadState.isDownloading,
                gameSetupService: viewModel.gameSetupService,
            )
        }
    }

    private var downloadProgressSection: some View {
        DownloadProgressSection(
            gameSetupService: viewModel.gameSetupService,
            selectedModLoader: viewModel.selectedModLoader,
        )
    }
}

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Constants
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

// MARK: - GameCreationView
struct GameCreationView: View {
    @StateObject private var viewModel: GameCreationViewModel
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    // Bindings from parent
    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>
    private let onRequestImagePicker: () -> Void
    private let onSetImagePickerHandler: (@escaping (Result<[URL], Error>) -> Void) -> Void

    // MARK: - Initializer
    init(
        isDownloading: Binding<Bool>,
        isFormValid: Binding<Bool>,
        triggerConfirm: Binding<Bool>,
        triggerCancel: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        onRequestImagePicker: @escaping () -> Void,
        onSetImagePickerHandler: @escaping (@escaping (Result<[URL], Error>) -> Void) -> Void
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
            onCancel: onCancel,
            onConfirm: onConfirm
        )
        self._viewModel = StateObject(wrappedValue: GameCreationViewModel(configuration: configuration))
    }

    // MARK: - Body
    var body: some View {
        formContentView
        .onAppear {
            viewModel.setup(gameRepository: gameRepository, playerListViewModel: playerListViewModel)
            onSetImagePickerHandler(viewModel.handleImagePickerResult)
        }
        .gameFormStateListeners(viewModel: viewModel, triggerConfirm: triggerConfirm, triggerCancel: triggerCancel)
        .onChange(of: viewModel.selectedLoaderVersion) { oldValue, newValue in
            // 优化：仅在值实际变化时更新
            if oldValue != newValue {
                viewModel.updateParentState()
            }
        }
        .onChange(of: viewModel.selectedModLoader) { oldValue, newLoader in
            // 优化：仅在值实际变化时处理
            if oldValue != newLoader {
                viewModel.handleModLoaderChange(newLoader)
            }
        }
        .onChange(of: viewModel.selectedGameVersion) { oldValue, newVersion in
            // 优化：仅在值实际变化时处理
            if oldValue != newVersion {
                viewModel.handleGameVersionChange(newVersion)
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 如果正在下载，取消下载任务
        if viewModel.isDownloading {
            viewModel.handleCancel()
        }
        // ViewModel 的数据会在下次打开时重新初始化，这里主要清理临时文件
        // 不重置 ViewModel 状态，可能正在使用
    }

    // MARK: - View Components

    private var formContentView: some View {
        VStack {
            gameIconAndVersionSection
            if viewModel.selectedModLoader != "vanilla" {
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
                .font(.subheadline)
                .foregroundColor(.primary)

                iconContainer
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
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
                            .frame(
                                width: Constants.iconSize,
                                height: Constants.iconSize
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: Constants.cornerRadius
                                )
                            )
                            .contentShape(Rectangle())
                    case .failure:
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .stroke(
                                Color.accentColor.opacity(0.3),
                                lineWidth: 1
                            )
                            .background(Color.gray.opacity(0.08))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.none)
                        .fontWeight(.regular)
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(emptyDropBackground())
            }
        }
        .frame(width: Constants.iconSize, height: Constants.iconSize)
    }

    private var gameVersionAndLoaderView: some View {
        VStack(alignment: .leading, spacing: Constants.formSpacing) {
            modLoaderPicker
            versionPicker
        }
    }

    private var versionPicker: some View {
        CustomVersionPicker(
            selected: $viewModel.selectedGameVersion,
            availableVersions: viewModel.availableVersions,
            time: $viewModel.versionTime
        ) { version in
            await ModrinthService.queryVersionTime(from: version)
        }
        .disabled(viewModel.gameSetupService.downloadState.isDownloading)
    }

    private var modLoaderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.modloader".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            Picker("", selection: $viewModel.selectedModLoader) {
                ForEach(AppConstants.modLoaders, id: \.self) { loader in
                    switch loader {
                    case "vanilla":
                        Text("Vanilla").tag(loader)
                    case "fabric":
                        Text("Fabric").tag(loader)
                    case "forge":
                        Text("Forge").tag(loader)
                    case "neoforge":
                        Text("NeoForge").tag(loader)
                    case "quilt":
                        Text("Quilt").tag(loader)
                    default:
                        Text(loader.capitalized).tag(loader)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .disabled(viewModel.gameSetupService.downloadState.isDownloading)
        }
    }

    private var loaderVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.loader.version".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            Picker("", selection: $viewModel.selectedLoaderVersion) {
                ForEach(viewModel.availableLoaderVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .disabled(viewModel.gameSetupService.downloadState.isDownloading || viewModel.availableLoaderVersions.isEmpty)
        }
    }

    private var gameNameSection: some View {
        FormSection {
            GameNameInputView(
                gameName: Binding(
                    get: { viewModel.gameNameValidator.gameName },
                    set: { viewModel.gameNameValidator.gameName = $0 }
                ),
                isGameNameDuplicate: Binding(
                    get: { viewModel.gameNameValidator.isGameNameDuplicate },
                    set: { viewModel.gameNameValidator.isGameNameDuplicate = $0 }
                ),
                isDisabled: viewModel.gameSetupService.downloadState.isDownloading,
                gameSetupService: viewModel.gameSetupService
            )
        }
    }

    private var downloadProgressSection: some View {
        DownloadProgressSection(
            gameSetupService: viewModel.gameSetupService,
            selectedModLoader: viewModel.selectedModLoader
        )
    }
}

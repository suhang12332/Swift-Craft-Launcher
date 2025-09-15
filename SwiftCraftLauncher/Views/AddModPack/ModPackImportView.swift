import SwiftUI
import UniformTypeIdentifiers

// MARK: - ModPackImportView
struct ModPackImportView: View {
    @StateObject private var viewModel: ModPackImportViewModel
    @EnvironmentObject var gameRepository: GameRepository

    // Bindings from parent
    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    // MARK: - Initializer
    init(
        configuration: GameFormConfiguration,
        preselectedFile: URL? = nil,
        shouldStartProcessing: Bool = false,
        onProcessingStateChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.triggerConfirm = configuration.triggerConfirm
        self.triggerCancel = configuration.triggerCancel

        self._viewModel = StateObject(wrappedValue: ModPackImportViewModel(
            configuration: configuration,
            preselectedFile: preselectedFile,
            shouldStartProcessing: shouldStartProcessing,
            onProcessingStateChanged: onProcessingStateChanged
        ))
    }

    // MARK: - Body
    var body: some View {
        formContentView
        .onAppear {
            viewModel.setup(gameRepository: gameRepository)
        }
        .gameFormStateListeners(viewModel: viewModel, triggerConfirm: triggerConfirm, triggerCancel: triggerCancel)
        .onChange(of: viewModel.selectedModPackFile) { _, _ in
            viewModel.updateParentState()
        }
        .onChange(of: viewModel.modPackIndexInfo?.modPackName) { _, _ in
            viewModel.updateParentState()
        }
        .onChange(of: viewModel.modPackViewModelForProgress.modPackInstallState.isInstalling) { _, _ in
            viewModel.updateParentState()
        }
        .onChange(of: viewModel.isProcessingModPack) { _, _ in
            viewModel.updateParentState()
        }
    }

    // MARK: - View Components

    private var formContentView: some View {
        VStack {
            modPackImportContentView.padding(.bottom, 10)
            if viewModel.hasSelectedModPack && !viewModel.isProcessingModPack && viewModel.modPackIndexInfo != nil {
                modPackGameNameInputSection
            }

            if viewModel.shouldShowProgress {
                downloadProgressSection.padding(.top, 10)
            }
        }
    }

    private var modPackImportContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isProcessingModPack {
                modPackProcessingView
            } else {
                selectedModPackView
            }
        }
    }

    private var modPackProcessingView: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.small)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text("modpack.processing.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var modPackParseErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .foregroundStyle(.secondary)
                .font(.system(size: 32))
            Text(viewModel.selectedModPackFile?.lastPathComponent ?? "")
                .font(.headline)
                .bold()

            Text("error.resource.modpack_parse_failed".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - ModPack Selection View Components

    private var selectedModPackView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.modPackIndexInfo != nil {
                // 解析完成，显示完整信息
                HStack {
                    VStack(alignment: .leading) {
                        Text(viewModel.modPackName)
                            .font(.title2)
                            .bold()
                        selectedModPackInfoRow
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
            } else {
                modPackParseErrorView
            }
        }
    }

    private var selectedModPackInfoRow: some View {
        HStack(spacing: 8) {
            Label(
                viewModel.modPackVersion,
                systemImage: "text.document.fill"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Label(viewModel.gameVersion, systemImage: "gamecontroller.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Label(viewModel.loaderInfo, systemImage: "puzzlepiece.extension.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var modPackGameNameInputSection: some View {
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
                isDisabled: viewModel.isProcessingModPack || viewModel.isDownloading,
                gameSetupService: viewModel.gameSetupService
            )
        }
    }

    private var downloadProgressSection: some View {
        DownloadProgressSection(
            gameSetupService: viewModel.gameSetupService,
            modPackViewModel: viewModel.modPackViewModelForProgress,
            modPackIndexInfo: viewModel.modPackIndexInfo
        )
    }
}

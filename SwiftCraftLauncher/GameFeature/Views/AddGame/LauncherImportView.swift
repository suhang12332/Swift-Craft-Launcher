import SwiftUI
import UniformTypeIdentifiers

struct LauncherImportView: View {
    @StateObject private var viewModel: LauncherImportViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel

    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>

    @State private var showFolderPicker = false

    private var selectedImportContentTypes: [UTType] {
        if viewModel.selectedLauncherType == .hmcl {
            return [UTType(filenameExtension: "jar") ?? .data]
        }
        return [.folder]
    }

    init(configuration: GameFormConfiguration) {
        triggerConfirm = configuration.triggerConfirm
        triggerCancel = configuration.triggerCancel
        _viewModel = StateObject(
            wrappedValue: LauncherImportViewModel(configuration: configuration)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            launcherSelectionSection
            rootSelectionSection
            instanceSelectionSection
            if viewModel.shouldShowProgress {
                VStack(spacing: 16) {
                    if let currentImportInstanceName = viewModel.currentImportInstanceName {
                        FormSection {
                            Text(currentImportInstanceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if viewModel.isImporting, let progress = viewModel.importProgress {
                        importProgressSection(progress: progress)
                    }
                    downloadProgressSection
                }
                .padding(.top, 10)
            }
        }
        .onAppear {
            viewModel.setup(
                gameRepository: gameRepository,
                playerListViewModel: playerListViewModel
            )
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .gameFormStateListeners(
            viewModel: viewModel,
            triggerConfirm: triggerConfirm,
            triggerCancel: triggerCancel
        )
        .onChange(of: viewModel.selectedLauncherType) { _, newValue in
            viewModel.handleLauncherTypeChange()
            if newValue == .hmcl {
                showFolderPicker = true
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: selectedImportContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePathSelection(result)
        }
        .fileDialogDefaultDirectory(FileManager.default.homeDirectoryForCurrentUser)
    }

    private var launcherSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 8) {
                Text("launcher.import.select_launcher".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                CommonMenuPicker(
                    selection: $viewModel.selectedLauncherType,
                    hidesLabel: true
                ) {
                    Text("")
                } content: {
                    ForEach(ImportLauncherType.allCases, id: \.self) { launcherType in
                        Text(launcherType.displayName)
                            .tag(launcherType)
                    }
                }
            }
        }
    }

    private var rootSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 8) {
                Text(rootSelectionTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    if let path = viewModel.selectedLauncherRootPath?.path {
                        PathBreadcrumbView(path: path)
                    } else {
                        Text(emptyRootSelectionTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.refreshDetectedRootAndScan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isScanning || viewModel.isImporting || viewModel.isDownloading)

                    Button("common.browse".localized()) {
                        showFolderPicker = true
                    }
                    .disabled(viewModel.isScanning || viewModel.isImporting || viewModel.isDownloading)
                }
            }
        }
    }

    private var rootSelectionTitle: String {
        if viewModel.selectedLauncherType == .hmcl {
            return "launcher.import.select_hmcl_jar".localized()
        }
        return "launcher.import.select_launcher_folder".localized()
    }

    private var emptyRootSelectionTitle: String {
        if viewModel.selectedLauncherType == .hmcl {
            return "launcher.import.no_hmcl_jar_selected".localized()
        }
        return "launcher.import.no_path_selected".localized()
    }

    private var instanceSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.selectedLauncherType == .all {
                    Text("launcher.import.scan_all_hint".localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text("\(viewModel.selectedImportInstances.count)/\(viewModel.scannedInstances.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        viewModel.selectAllInstances()
                    } label: {
                        Image(systemName: "checklist.checked")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.scannedInstances.isEmpty)

                    Button {
                        viewModel.clearSelectedInstances()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.selectedInstanceIDs.isEmpty)
                }

                if viewModel.scannedInstances.isEmpty, viewModel.isScanning {
                    HStack {
                        ProgressView()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                } else if viewModel.scannedInstances.isEmpty {
                    ContentUnavailableView(
                        viewModel.hasSelectedRoot
                            ? "launcher.import.no_instances_found".localized()
                            : "launcher.import.no_path_selected".localized(),
                        systemImage: "shippingbox"
                    )
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if viewModel.isScanning {
                            HStack {
                                ProgressView()
                                Spacer()
                            }
                        }

                        ForEach(viewModel.scannedInstances) { instance in
                            instanceRow(instance)
                            if instance.id != viewModel.scannedInstances.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func instanceRow(_ instance: ScannedLauncherInstance) -> some View {
        let isSelected = Binding(
            get: { viewModel.selectedInstanceIDs.contains(instance.id) },
            set: { viewModel.toggleSelection(for: instance, isSelected: $0) }
        )

        return Toggle(isOn: isSelected) {
            VStack(alignment: .leading, spacing: 6) {
                Text(instance.info.gameName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(instance.info.gameVersion, systemImage: "gamecontroller.fill")
                    if instance.info.modLoader != GameLoader.vanilla.displayName {
                        Label(
                            instance.info.modLoaderVersion.isEmpty
                                ? instance.info.modLoader.capitalized
                                : "\(instance.info.modLoader.capitalized) \(instance.info.modLoaderVersion)",
                            systemImage: "puzzlepiece.extension.fill"
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(instance.info.launcherType.displayName)
                    Text(instance.instancePath.lastPathComponent)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .toggleStyle(.checkbox)
        .disabled(viewModel.isImporting || viewModel.isDownloading)
    }

    private var downloadProgressSection: some View {
        DownloadProgressSection(
            gameSetupService: viewModel.gameSetupService,
            selectedModLoader: viewModel.activeImportModLoader,
            modPackViewModel: nil,
            modPackIndexInfo: nil
        )
    }

    private func importProgressSection(progress: (fileName: String, completed: Int, total: Int)) -> some View {
        FormSection {
            DownloadProgressRow(
                title: "launcher.import.copying_files".localized(),
                progress: progress.total > 0 ? Double(progress.completed) / Double(progress.total) : 0.0,
                currentFile: progress.fileName,
                completed: progress.completed,
                total: progress.total,
                version: nil
            )
        }
    }

    private func handlePathSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.updateSelectedRoot(url)
        case .failure(let error):
            AppServices.errorHandler.handle(GlobalError.from(error))
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isDownloading = false
        @State private var isFormValid = false
        @State private var triggerConfirm = false
        @State private var triggerCancel = false

        var body: some View {
            LauncherImportView(
                configuration: GameFormConfiguration(
                    isDownloading: $isDownloading,
                    isFormValid: $isFormValid,
                    triggerConfirm: $triggerConfirm,
                    triggerCancel: $triggerCancel,
                    onCancel: {},
                    onConfirm: {}
                )
            )
            .environmentObject(GameRepository())
            .environmentObject(PlayerListViewModel())
            .frame(width: 640, height: 640)
            .padding()
        }
    }

    return PreviewWrapper()
}

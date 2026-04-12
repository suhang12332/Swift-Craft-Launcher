import Foundation
import SwiftUI

public struct GameSettingsView: View {

    @StateObject private var gameSettings = GameSettingsManager.shared
    @ObservedObject private var javaDownloadManager = JavaDownloadManager.shared
    @StateObject private var viewModel = GameSettingsJavaRuntimeViewModel()

    // 内存区间
    @State private var globalMemoryRange: ClosedRange<Double> = 512...4096

    public var body: some View {
        VStack {
            Form {
                LabeledContent("settings.default_api_source.label".localized()) {
                    Picker("", selection: $gameSettings.defaultAPISource) {
                        ForEach(DataSource.allCases, id: \.self) { source in
                            Text(source.localizedName).tag(source)
                        }
                    }

                    .labelsHidden()
                    .fixedSize()
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.modpack.export.format.label".localized()) {
                    Picker("", selection: $gameSettings.defaultModPackExportFormat) {
                        ForEach(ModPackExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.game_versions.label".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettings.includeSnapshotsForGameVersions
                        )
                        .labelsHidden()
                        Text("settings.game_versions.include_snapshots.label".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.ai_crash_analysis".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettings.enableAICrashAnalysis
                        ).labelsHidden()
                        Text("settings.ai_crash_analysis.description".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.game.language.label".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettings.syncLanguageForNewGames
                        )
                        .labelsHidden()
                        Text("settings.game.language.sync_with_launcher".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                Group {
                    LabeledContent("settings.default_memory_allocation.label".localized()) {
                        HStack {
                            MiniRangeSlider(
                                range: $globalMemoryRange,
                                bounds:
                                    512...Double(gameSettings.maximumMemoryAllocation)
                            )
                            .frame(width: 200)
                            .controlSize(.mini)
                            .onChange(of: globalMemoryRange) { _, newValue in
                                gameSettings.globalXms = Int(newValue.lowerBound)
                                gameSettings.globalXmx = Int(newValue.upperBound)
                            }
                            .onAppear {
                                globalMemoryRange =
                                Double(
                                    gameSettings.globalXms
                                )...Double(gameSettings.globalXmx)
                            }
                            Text(
                                "\(Int(globalMemoryRange.lowerBound)) MB-\(Int(globalMemoryRange.upperBound)) MB"
                            )
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        }
                    }
                    .labeledContentStyle(.custom)
                    CommonDescriptionText(
                        text: "settings.default_memory_allocation.description".localized()
                    )
                }
                if let components = viewModel.installedRuntimeComponents, !components.isEmpty {
                    LabeledContent("settings.game.java.runtimes.section".localized()) {
                        HStack(spacing: 8) {
                            Picker("", selection: $viewModel.selectedRuntimeComponent) {
                                ForEach(components, id: \.self) { component in
                                    Text(component).tag(component)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()

                            Button("settings.game.java.runtime.reinstall".localized()) {
                                Task {
                                    await javaDownloadManager.downloadJavaRuntime(
                                        version: viewModel.selectedRuntimeComponent
                                    )
                                }
                            }
                            .disabled(
                                viewModel.selectedRuntimeComponent.isEmpty
                                    || javaDownloadManager.downloadState.isDownloading
                            )

                            if !viewModel.selectedRuntimeComponent.isEmpty {
                                InfoIconWithPopover(text: viewModel.javaDetailsDescription)
                            }
                        }
                    }
                    .labeledContentStyle(.custom)
                }
            }
            HStack {
                Spacer()
                Button {
                    Task {
                        await Task.detached(priority: .utility) {
                            ModCacheManager.shared.clearSilently()
                        }.value
                    }
                } label: {
                    Text("settings.game.clear_cache.label".localized())
                }
                InfoIconWithPopover(text: "settings.game.clear_cache.help".localized())
            }
        }
        .onAppear {
            viewModel.refreshInstalledRuntimes(showScanningIndicator: true)
        }
        .onChange(of: javaDownloadManager.isWindowVisible) { _, isVisible in
            if !isVisible {
                viewModel.refreshInstalledRuntimes(showScanningIndicator: false)
            }
        }
        .onChange(of: viewModel.selectedRuntimeComponent) { _, newValue in
            viewModel.loadDetails(forRuntimeComponent: newValue)
        }
        .onChange(of: javaDownloadManager.downloadState.isDownloading) { _, isDownloading in
            if !isDownloading, !viewModel.selectedRuntimeComponent.isEmpty {
                viewModel.loadDetails(forRuntimeComponent: viewModel.selectedRuntimeComponent)
            }
        }
    }
}

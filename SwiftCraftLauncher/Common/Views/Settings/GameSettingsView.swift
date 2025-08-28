import Foundation
import SwiftUI

public struct GameSettingsView: View {
    @StateObject private var cacheManager = CacheManager()

    @ObservedObject private var gameSettings = GameSettingsManager.shared
    @State private var showJavaPathPicker = false
    @State private var javaVersion: String = "java.version.not_detected"
        .localized()
    @State private var javaDetectionError: String?

    // 内存区间
    @State private var globalMemoryRange: ClosedRange<Double> = 512...4096

    public init() {}

    /// 检查 Java 版本
    /// - Parameter path: Java 安装路径
    private func checkJavaVersion(at path: String) {
        JavaVersionChecker.shared.checkJavaVersion(at: path) { result in
            self.javaVersion = result.version
            self.javaDetectionError = result.error
        }
    }

    /// 安全地计算缓存信息
    private func calculateCacheInfoSafely() {
        cacheManager.calculateMetaCacheInfo()
    }

    public var body: some View {
        Grid(alignment: .trailing) {
            GridRow {
                Text("settings.auto_handle_dependencies".localized())
                    .gridColumnAlignment(.trailing)
                HStack {
                    Toggle(
                        "",
                        isOn: $gameSettings.autoDownloadDependencies
                    ).labelsHidden()
                    Text("settings.dependencies.description".localized()).font(
                        .footnote
                    ).foregroundColor(.secondary)
                }
                .gridColumnAlignment(.leading)
            }
            .padding(.bottom, 20)

            GridRow {
                Text("settings.default_java_path.label".localized())
                    .gridColumnAlignment(.trailing)
                DirectorySettingRow(
                    title: "settings.default_java_path.label".localized(),
                    path: gameSettings.defaultJavaPath.isEmpty
                        ? AppConstants.defaultJava + "/java"
                        : gameSettings.defaultJavaPath + "/java",
                    description: gameSettings.defaultJavaPath.isEmpty
                        ? AppConstants.defaultJava + "/java"
                        : gameSettings.defaultJavaPath + "/java" + javaVersion,
                    onChoose: { showJavaPathPicker = true },
                    onReset: {
                        gameSettings.defaultJavaPath = AppConstants.defaultJava
                    }
                )
                .fixedSize()
                .fileImporter(
                    isPresented: $showJavaPathPicker,
                    allowedContentTypes: [.directory],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            gameSettings.defaultJavaPath = url.path
                        }
                    case .failure(let error):
                        GlobalErrorHandler.shared.handle(
                            GlobalError.fileSystem(
                                chineseMessage:
                                    "选择 Java 目录失败: \(error.localizedDescription)",
                                i18nKey:
                                    "error.filesystem.java_directory_selection_failed",
                                level: .notification
                            )
                        )
                    }
                }
                .onAppear {
                    checkJavaVersion(
                        at: gameSettings.defaultJavaPath.isEmpty
                            ? AppConstants.defaultJava
                            : gameSettings.defaultJavaPath
                    )
                }
                .onChange(of: gameSettings.defaultJavaPath) { old, newPath in
                    checkJavaVersion(
                        at: newPath.isEmpty ? AppConstants.defaultJava : newPath
                    )
                }
                if let error = javaDetectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 20)
            GridRow {
                Text("settings.default_memory_allocation.label".localized())
                    .gridColumnAlignment(.trailing)
                HStack {
                    MiniRangeSlider(
                        range: $globalMemoryRange,
                        bounds:
                            512...Double(gameSettings.maximumMemoryAllocation)
                    )
                    .frame(width: 200, height: 20)
                    .onChange(of: globalMemoryRange) { old, newValue in
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
                        "\(Int(globalMemoryRange.lowerBound)) MB - \(Int(globalMemoryRange.upperBound)) MB"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                .gridColumnAlignment(.leading)
            }.padding(.bottom, 20)
            GridRow {
                Text("settings.game_resource_info.label".localized())
                    .gridColumnAlignment(.trailing)
                HStack {
                    Label(
                        "\(cacheManager.cacheInfo.fileCount)",
                        systemImage: "text.document"
                    )
                    Divider().frame(height: 16)
                    Label(
                        cacheManager.cacheInfo.formattedSize,
                        systemImage: "externaldrive"
                    )
                }.foregroundStyle(.secondary)
            }
        }

        .onAppear {
            calculateCacheInfoSafely()
        }
        .globalErrorHandler()
    }
}

#Preview {
    GameSettingsView()
}

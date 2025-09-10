import Foundation
import SwiftUI

public struct GameSettingsView: View {
    @StateObject private var cacheManager = CacheManager()

    @ObservedObject private var gameSettings = GameSettingsManager.shared

    // 内存区间
    @State private var globalMemoryRange: ClosedRange<Double> = 512...4096

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
                    )
                    .foregroundColor(.secondary)
                }
                .gridColumnAlignment(.leading)
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

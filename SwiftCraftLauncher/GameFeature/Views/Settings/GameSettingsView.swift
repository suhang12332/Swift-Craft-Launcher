import Foundation
import SwiftUI

public struct GameSettingsView: View {
    @StateObject private var cacheManager = CacheManager()

    @StateObject private var gameSettings = GameSettingsManager.shared

    // 内存区间
    @State private var globalMemoryRange: ClosedRange<Double> = 512...4096

    /// 安全地计算缓存信息
    private func calculateCacheInfoSafely() {
        cacheManager.calculateMetaCacheInfo()
    }

    public var body: some View {
        Form {
            LabeledContent("settings.default_api_source.label".localized()) {
                Picker("", selection: $gameSettings.defaultAPISource) {
                    ForEach(DataSource.allCases, id: \.self) { source in
                        Text(source.localizedName).tag(source)
                    }
                }

                .labelsHidden()
                .fixedSize()
            }.labeledContentStyle(.custom(alignment: .firstTextBaseline)).padding(.bottom, 10)

            LabeledContent("settings.game_versions.label".localized()) {
                HStack {
                    Toggle(
                        "",
                        isOn: $gameSettings.includeSnapshotsForGameVersions
                    )
                    .labelsHidden()
                    Text("settings.game_versions.include_snapshots.label".localized()).font(.callout)
                        .foregroundColor(.primary)
                }
            }.labeledContentStyle(.custom).padding(.bottom, 10)

            LabeledContent("settings.ai_crash_analysis".localized()) {
                HStack {
                    Toggle(
                        "",
                        isOn: $gameSettings.enableAICrashAnalysis
                    ).labelsHidden()
                    Text("settings.ai_crash_analysis.description".localized()).font(
                        .callout
                    )
                    .foregroundColor(.primary)
                }
            }.labeledContentStyle(.custom).padding(.bottom, 10)

            LabeledContent {
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
                    InfoIconWithPopover(
                        text: "settings.default_memory_allocation.description".localized()
                    )
                }
            } label: {
                Text("settings.default_memory_allocation.label".localized())
            }
            .labeledContentStyle(.custom).padding(.bottom, 10)

            LabeledContent("settings.game_resource_info.label".localized()) {
                HStack {
                    Label(
                        "\(cacheManager.cacheInfo.fileCount)",
                        systemImage: "text.document"
                    ).font(.callout)
                    Divider().frame(height: 16)
                    Label(
                        cacheManager.cacheInfo.formattedSize,
                        systemImage: "externaldrive"
                    ).font(.callout)
                }.foregroundStyle(.primary)
            }.labeledContentStyle(.custom)
        }
        .onAppear {
            calculateCacheInfoSafely()
        }
    }
}

#Preview {
    GameSettingsView()
}

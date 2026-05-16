import SwiftUI
import Foundation

/// 设置标签页枚举
enum SettingsTab: Int {
    case general = 0
    case player = 1
    case game = 2
    case advanced = 3
    case ai = 4
}

/// 通用设置视图
/// 应用设置
public struct SettingsView: View {
    @StateObject private var general: GeneralSettingsManager
    @StateObject private var selectedGameManager: SelectedGameManager
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var selectedTab: SettingsTab = .general

    public init() {
        _general = StateObject(wrappedValue: AppServices.generalSettingsManager)
        _selectedGameManager = StateObject(wrappedValue: AppServices.selectedGameManager)
    }

    init(
        general: GeneralSettingsManager,
        selectedGameManager: SelectedGameManager
    ) {
        _general = StateObject(wrappedValue: general)
        _selectedGameManager = StateObject(wrappedValue: selectedGameManager)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general.tab".localized(), systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            PlayerSettingsView()
                .tabItem {
                    Label("settings.player.tab".localized(), systemImage: "person")
                }
                .tag(SettingsTab.player)
            GameSettingsView()
                .tabItem {
                    Label("settings.game.tab".localized(), systemImage: "gamecontroller")
                }
                .tag(SettingsTab.game)
            AISettingsView()
                .tabItem {
                    Label("settings.ai.tab".localized(), systemImage: "brain")
                }
                .tag(SettingsTab.ai)
            GameAdvancedSettingsView()
                .tabItem {
                    Label(
                        "settings.game.advanced.tab".localized(),
                        systemImage: "gearshape.2"
                    )
                }
                .tag(SettingsTab.advanced)
                .disabled(selectedGameManager.selectedGameId == nil)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .onChange(of: selectedGameManager.shouldOpenAdvancedSettings) { _, shouldOpen in
            if shouldOpen {
                checkAndOpenAdvancedSettings()
            }
        }
        .onAppear {
            checkAndOpenAdvancedSettings()
        }
    }

    private func checkAndOpenAdvancedSettings() {
        if selectedGameManager.shouldOpenAdvancedSettings && selectedGameManager.selectedGameId != nil {
            selectedTab = .advanced
            selectedGameManager.shouldOpenAdvancedSettings = false
        }
    }
}

struct CustomLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        LabeledContent {
            configuration.content
        } label: {
            HStack(spacing: 0) {
                configuration.label
                Text(":")
            }
        }
        .padding(.vertical, 2)
    }
}

struct CustomLabeledContentStyleNoColon: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        LabeledContent {
            configuration.content
        } label: {
            configuration.label
        }
        .padding(.vertical, 2)
    }
}

extension LabeledContentStyle where Self == CustomLabeledContentStyle {
    static var custom: Self { .init() }
}

extension LabeledContentStyle where Self == CustomLabeledContentStyleNoColon {
    static var customNoColon: Self { .init() }
}

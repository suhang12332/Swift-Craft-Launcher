import SwiftUI
import Foundation

/// 通用设置视图
/// 用于显示应用程序的设置选项
public struct SettingsView: View {
    @ObservedObject private var general = GeneralSettingsManager.shared

    public init() {}

    public var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general.tab".localized(), systemImage: "gearshape")
                }
            PlayerSettingsView()
                .tabItem {
                    Label("settings.player.tab".localized(), systemImage: "person.crop.circle")
                }
            GameSettingsView()
                .tabItem {
                    Label("settings.game.tab".localized(), systemImage: "gamecontroller")
                }
        }
        .padding(.vertical, 24)
        .frame(minWidth: 840)
    }
}

#Preview {
    SettingsView()
}

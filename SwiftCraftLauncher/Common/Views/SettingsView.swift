import SwiftUI
import Foundation

/// 通用设置视图
/// 用于显示应用程序的设置选项
public struct SettingsView: View {
    @ObservedObject private var general = GeneralSettingsManager.shared
    @ObservedObject private var selectedGameManager = SelectedGameManager.shared
    @EnvironmentObject private var gameRepository: GameRepository

    public init() {}

    public var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general.tab".localized(), systemImage: "gearshape")
                }
            GameSettingsView()
                .tabItem {
                    Label("settings.game.tab".localized(), systemImage: "gamecontroller")
                }
            if selectedGameManager.selectedGameId != nil {
                GameAdvancedSettingsView()
                    .tabItem {
                        Label("settings.game.advanced.tab".localized(), systemImage: "gearshape.2")
                    }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct CustomLabeledContentStyle: LabeledContentStyle {
    let alignment: VerticalAlignment

    init(alignment: VerticalAlignment = .center) {
        self.alignment = alignment
    }

    // 保留系统布局
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: alignment) {
            // 使用系统的标签布局
            HStack(spacing: 0) {
                configuration.label
                Text(":")
            }
            .layoutPriority(1)  // 保持标签优先级
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 320, alignment: .trailing)  // 容器右对齐
            // 右侧内容
            configuration.content
                .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)  // 文字左对齐
                .frame(maxWidth: .infinity, alignment: .leading)  // 容器左对齐
        }
        .padding(.vertical, 4)
    }
}

// 使用扩展避免破坏布局
extension LabeledContentStyle where Self == CustomLabeledContentStyle {
    static var custom: Self { .init() }

    static func custom(alignment: VerticalAlignment) -> Self {
        .init(alignment: alignment)
    }
}

#Preview {
    SettingsView()
}

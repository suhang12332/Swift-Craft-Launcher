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
//            PlayerSettingsView()
//                .tabItem {
//                    Label("settings.player.tab".localized(), systemImage: "person.crop.circle")
//                }
            GameSettingsView()
                .tabItem {
                    Label("settings.game.tab".localized(), systemImage: "gamecontroller")
                }
            GameAdvancedSettingsTabView()
                .tabItem {
                    Label("settings.game.advanced.tab".localized(), systemImage: "slider.horizontal.3")
                }
        }
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
            configuration.label
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

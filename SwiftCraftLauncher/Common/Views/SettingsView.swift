import SwiftUI
import Foundation

/// 设置标签页枚举
enum SettingsTab: Int {
    case general = 0
    case game = 1
    case advanced = 2
    case ai = 3
}

/// 通用设置视图
/// 应用设置
public struct SettingsView: View {
    @StateObject private var general = GeneralSettingsManager.shared
    @StateObject private var selectedGameManager = SelectedGameManager.shared
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var selectedTab: SettingsTab = .general

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general.tab".localized(), systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
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
        .padding()
        .onChange(of: selectedGameManager.shouldOpenAdvancedSettings) { _, shouldOpen in
            // 当标志被设置时（窗口已打开的情况），切换到高级设置标签
            if shouldOpen {
                checkAndOpenAdvancedSettings()
            }
        }
        .onAppear {
            // 当设置窗口首次打开时，如果标志已经被设置，则切换到高级设置标签
            // 这种情况发生在窗口未打开时点击设置按钮
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

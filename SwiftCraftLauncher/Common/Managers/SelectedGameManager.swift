import Foundation
import SwiftUI

/// 选中游戏管理器
/// 用于在主视图和设置页面之间共享当前选中的游戏ID
class SelectedGameManager: ObservableObject {
    // MARK: - 单例实例
    static let shared = SelectedGameManager()

    /// 当前选中的游戏ID
    @Published var selectedGameId: String? {
        didSet {
            // 当游戏ID变化时，自动通知观察者
            objectWillChange.send()
        }
    }

    private init() {
        // 私有初始化，确保单例模式
    }

    /// 设置选中的游戏ID
    /// - Parameter gameId: 游戏ID，如果为nil则清除选中状态
    func setSelectedGame(_ gameId: String?) {
        selectedGameId = gameId
    }

    /// 清除选中的游戏
    func clearSelection() {
        selectedGameId = nil
    }
}

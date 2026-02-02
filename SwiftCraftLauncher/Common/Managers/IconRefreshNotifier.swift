import Foundation
import Combine

/// 图标刷新通知管理器
/// 图标更新后通知视图刷新
final class IconRefreshNotifier: ObservableObject {
    static let shared = IconRefreshNotifier()

    /// 图标刷新通知发布者
    /// 发送游戏名称，nil 表示刷新所有图标
    private let refreshSubject = PassthroughSubject<String?, Never>()

    /// 图标刷新通知的发布者
    var refreshPublisher: AnyPublisher<String?, Never> {
        refreshSubject.eraseToAnyPublisher()
    }

    private init() {}

    /// 通知刷新特定游戏的图标
    /// - Parameter gameName: 游戏名称，nil 表示刷新所有图标
    func notifyRefresh(for gameName: String?) {
        refreshSubject.send(gameName)
    }

    /// 通知刷新所有图标
    func notifyRefreshAll() {
        refreshSubject.send(nil)
    }
}

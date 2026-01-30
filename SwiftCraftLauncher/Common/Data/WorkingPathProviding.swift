import Combine
import Foundation

/// 工作路径提供者
/// 用于将「当前工作路径」职责从 GameRepository 分离，由上层注入，便于测试与替换
public protocol WorkingPathProviding: AnyObject {
    /// 当前启动器工作目录；空字符串时使用默认目录
    var currentWorkingPath: String { get }
    /// 工作路径或相关设置变化时发出，用于 GameRepository 重新加载当前路径游戏
    var workingPathWillChange: AnyPublisher<Void, Never> { get }
}

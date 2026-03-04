import Combine
import Foundation

/// 工作路径提供者
public protocol WorkingPathProviding: AnyObject {
    /// 当前启动器工作目录；空字符串时使用默认目录
    var currentWorkingPath: String { get }
    var workingPathWillChange: AnyPublisher<Void, Never> { get }
}

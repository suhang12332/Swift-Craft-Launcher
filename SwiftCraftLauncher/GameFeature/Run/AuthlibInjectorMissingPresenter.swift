import Foundation

/// 用户在 authlib-injector 缺失弹窗中的选择
enum AuthlibInjectorMissingChoice {
    /// 继续启动，不注入 -javaagent
    case continueWithoutInjector
    /// 关闭弹窗，取消本次启动
    case cancel
}

/// 启动流程在 authlib-injector 缺失时等待用户确认（由主窗口弹窗消费）
@MainActor
final class AuthlibInjectorMissingPresenter: ObservableObject {
    static let shared = AuthlibInjectorMissingPresenter()

    @Published private(set) var isPresented = false

    private var continuation: CheckedContinuation<AuthlibInjectorMissingChoice, Never>?

    private init() {}

    func requestUserChoice() async -> AuthlibInjectorMissingChoice {
        if let continuation {
            continuation.resume(returning: .cancel)
            self.continuation = nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            isPresented = true
        }
    }

    func resolve(_ choice: AuthlibInjectorMissingChoice) {
        guard let continuation else { return }
        self.continuation = nil
        isPresented = false
        continuation.resume(returning: choice)
    }

    func dismissIfNeeded(as choice: AuthlibInjectorMissingChoice = .cancel) {
        guard continuation != nil else { return }
        resolve(choice)
    }
}

/// 用户关闭弹窗时，静默中止本次启动
struct AuthlibInjectorLaunchCancelled: Error {}

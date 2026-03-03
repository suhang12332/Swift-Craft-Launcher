import SwiftUI

/// 错误弹窗修饰符
struct ErrorAlertModifier: ViewModifier {
    @StateObject private var errorHandler = GlobalErrorHandler.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.notificationTitle ?? "",
                isPresented: .constant(errorHandler.currentError != nil && errorHandler.currentError?.level == .popup)
            ) {
                Button("common.close".localized()) {
                    errorHandler.clearCurrentError()
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.localizedDescription)
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// 添加错误弹窗处理
    func errorAlert() -> some View {
        self.modifier(ErrorAlertModifier())
    }
}

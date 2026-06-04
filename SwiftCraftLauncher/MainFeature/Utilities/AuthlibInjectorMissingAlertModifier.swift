import SwiftUI

/// authlib-injector 缺失时的启动确认弹窗
struct AuthlibInjectorMissingAlertModifier: ViewModifier {
    @ObservedObject private var presenter: AuthlibInjectorMissingPresenter

    init(
        presenter: AuthlibInjectorMissingPresenter = AppServices.authlibInjectorMissingPresenter
    ) {
        _presenter = ObservedObject(wrappedValue: presenter)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { presenter.isPresented },
            set: { newValue in
                if !newValue {
                    presenter.dismissIfNeeded(as: .cancel)
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "game_launch.authlib_injector_missing.title".localized(),
                isPresented: alertBinding
            ) {
                Button("common.continue".localized()) {
                    presenter.resolve(.continueWithoutInjector)
                }
                Button("common.close".localized(), role: .cancel) {
                    presenter.resolve(.cancel)
                }
            } message: {
                Text("game_launch.authlib_injector_missing.message".localized())
            }
    }
}

extension View {
    func authlibInjectorMissingAlert() -> some View {
        modifier(AuthlibInjectorMissingAlertModifier())
    }
}

import Foundation

@MainActor
final class YggdrasilAuthViewModel: ObservableObject {
    @Published var selectedOption: YggdrasilServerConfig?

    func onSelectedOptionChanged(_ option: YggdrasilServerConfig?, authService: YggdrasilAuthService) {
        if let option {
            authService.setServer(option)
        }
    }

    func onDisappear(authService: YggdrasilAuthService) {
        if case .idle = authService.authState {
            authService.logout()
        }
    }

    func selectAuthenticatedProfile(id: String, authService: YggdrasilAuthService) {
        authService.selectAuthenticatedProfile(id: id)
    }
}

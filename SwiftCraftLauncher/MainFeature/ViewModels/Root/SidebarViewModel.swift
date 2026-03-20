import Combine
import Foundation

@MainActor
final class SidebarViewModel: ObservableObject {
    @Published private(set) var iconRefreshTriggers: [String: UUID] = [:]

    private var cancellable: AnyCancellable?

    func refreshTrigger(for gameName: String) -> UUID {
        iconRefreshTriggers[gameName] ?? UUID()
    }

    func onAppear(games: [GameVersionInfo]) {
        ensureTriggers(for: games)

        cancellable = IconRefreshNotifier.shared.refreshPublisher
            .sink { [weak self] refreshedGameName in
                guard let self else { return }
                if let gameName = refreshedGameName {
                    self.iconRefreshTriggers[gameName] = UUID()
                } else {
                    for game in games {
                        self.iconRefreshTriggers[game.gameName] = UUID()
                    }
                }
            }
    }

    func onDisappear() {
        cancellable?.cancel()
        cancellable = nil
    }

    func onGamesChanged(_ newGames: [GameVersionInfo]) {
        ensureTriggers(for: newGames)
    }

    private func ensureTriggers(for games: [GameVersionInfo]) {
        for game in games where iconRefreshTriggers[game.gameName] == nil {
            iconRefreshTriggers[game.gameName] = UUID()
        }
    }
}

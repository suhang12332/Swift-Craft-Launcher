import Combine
import Foundation

@MainActor
final class SidebarViewModel: ObservableObject {
    @Published private(set) var iconRefreshTriggers: [String: UUID] = [:]

    private var cancellable: AnyCancellable?
    private let iconRefreshNotifier: IconRefreshNotifier

    init(iconRefreshNotifier: IconRefreshNotifier = AppServices.iconRefreshNotifier) {
        self.iconRefreshNotifier = iconRefreshNotifier
    }

    func refreshTrigger(for gameName: String) -> UUID {
        iconRefreshTriggers[gameName] ?? UUID()
    }

    func onAppear(games: [GameVersionInfo]) {
        ensureTriggers(for: games)

        cancellable = iconRefreshNotifier.refreshPublisher
            .sink { [weak self] refreshedGameName in
                guard let self else { return }
                if let gameName = refreshedGameName {
                    self.iconRefreshTriggers[gameName] = UUID()
                } else {
                    for gameName in self.iconRefreshTriggers.keys {
                        self.iconRefreshTriggers[gameName] = UUID()
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

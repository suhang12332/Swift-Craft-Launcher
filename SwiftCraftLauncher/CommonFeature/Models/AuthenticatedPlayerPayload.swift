import Foundation

struct AuthenticatedPlayerPayload: Equatable {
    let provider: AccountProvider
    let playerId: String
    let playerName: String
    let avatarURL: String
    let accessToken: String
    let clientToken: String
    let refreshToken: String
    let xuid: String
    let authServerBaseURL: String

    static func microsoft(from profile: MinecraftProfileResponse) -> Self {
        let avatarURL = profile.skins.first?.url.httpToHttps() ?? ""
        return Self(
            provider: .microsoft,
            playerId: profile.id,
            playerName: profile.name,
            avatarURL: avatarURL,
            accessToken: profile.accessToken,
            clientToken: "",
            refreshToken: profile.refreshToken,
            xuid: profile.authXuid,
            authServerBaseURL: ""
        )
    }
}

struct LittleSkinProfileSummary: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

struct LittleSkinAuthenticateResponse: Codable, Equatable {
    let accessToken: String
    let clientToken: String
    let availableProfiles: [LittleSkinProfileSummary]?
    let selectedProfile: LittleSkinProfileSummary?
}

struct LittleSkinErrorResponse: Codable {
    let error: String?
    let errorMessage: String?
    let message: String?
    let cause: String?
}

enum LittleSkinAuthenticationState: Equatable {
    case idle
    case authenticating
    case selectingProfiles([LittleSkinProfileSummary])
    case authenticated(AuthenticatedPlayerPayload)
    case error(String)
}

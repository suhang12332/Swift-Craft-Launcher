import Foundation

// MARK: - Device Code Response
struct DeviceCodeResponse: Codable {
    let userCode: String
    let deviceCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case userCode = "user_code"
        case deviceCode = "device_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
        case message
    }
}

// MARK: - Token Response
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Xbox Live Token Response
struct XboxLiveTokenResponse: Codable {
    let token: String
    let displayClaims: DisplayClaims
    
    enum CodingKeys: String, CodingKey {
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }
}

struct DisplayClaims: Codable {
    let xui: [XUI]
    
    enum CodingKeys: String, CodingKey {
        case xui = "xui"
    }
}

struct XUI: Codable {
    let uhs: String
    
    enum CodingKeys: String, CodingKey {
        case uhs
    }
}

// MARK: - Minecraft Profile Response
struct MinecraftProfileResponse: Codable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?
}

struct Skin: Codable {
    let id: String
    let state: String
    let url: String
    let variant: String?
    let alias: String?
}

struct Cape: Codable {
    let id: String
    let state: String
    let url: String
    let alias: String?
}

// MARK: - Authentication State
enum AuthenticationState {
    case notAuthenticated
    case requestingCode
    case waitingForUser(userCode: String, verificationUri: String)
    case authenticating
    case authenticated(profile: MinecraftProfileResponse)
    case error(String)
}

// MARK: - Authentication Error
enum MinecraftAuthError: Error, LocalizedError {
    case invalidDeviceCode
    case authorizationPending
    case authorizationDeclined
    case expiredToken
    case slowDown
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidDeviceCode:
            return "无效的设备代码"
        case .authorizationPending:
            return "授权待处理，请完成浏览器验证"
        case .authorizationDeclined:
            return "用户拒绝了授权"
        case .expiredToken:
            return "令牌已过期"
        case .slowDown:
            return "请求过于频繁，请稍后再试"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应数据"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        }
    }
} 

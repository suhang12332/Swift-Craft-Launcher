import Foundation
import SwiftUI
import AuthenticationServices

class YggdrasilAuthService: NSObject, ObservableObject {
    static let shared = YggdrasilAuthService()
    
    @Published var authState: YggdrasilAuthenticationState = .notAuthenticated
    @Published var isLoading: Bool = false
    @Published var serverConfig: YggdrasilServerConfig?
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    override private init() {
        super.init()
    }
    
    // MARK: - 设置服务器配置
    func setServerConfig(_ config: YggdrasilServerConfig) {
        self.serverConfig = config
    }
    
    // MARK: - 认证流程 (使用 ASWebAuthenticationSession)
    @MainActor
    func startAuthentication() async {
        guard let config = serverConfig else {
            Logger.shared.error("Yggdrasil 服务器配置未设置")
            authState = .error("服务器配置未设置")
            return
        }
        
        // 开始新认证前清理之前的状态
        webAuthSession?.cancel()
        webAuthSession = nil
        
        isLoading = true
        authState = .waitingForBrowserAuth
        
        guard let authURL = buildAuthorizationURL(config: config) else {
            Logger.shared.error("无法构建 Yggdrasil 授权 URL")
            isLoading = false
            authState = .error("无法构建授权 URL，请检查服务器配置")
            return
        }
        
        await withCheckedContinuation { continuation in
            webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "swift-craft-launcher"
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError {
                            if authError.code == .canceledLogin {
                                Logger.shared.info("用户取消了 Yggdrasil 认证")
                                self?.authState = .notAuthenticated
                            } else {
                                Logger.shared.error("Yggdrasil 认证失败: \(authError.localizedDescription)")
                                self?.authState = .error("minecraft.auth.error.authentication_failed".localized())
                            }
                        } else {
                            Logger.shared.error("Yggdrasil 认证发生未知错误: \(error.localizedDescription)")
                            self?.authState = .error("minecraft.auth.error.authentication_failed".localized())
                        }
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }
                    
                    guard let callbackURL = callbackURL,
                          let authResponse = AuthorizationCodeResponse(from: callbackURL) else {
                        Logger.shared.error("Yggdrasil 无效的回调 URL")
                        self?.authState = .error("minecraft.auth.error.invalid_callback_url".localized())
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }
                    
                    // 检查是否是用户拒绝授权
                    if authResponse.isUserDenied {
                        Logger.shared.info("用户拒绝了 Yggdrasil 授权")
                        self?.authState = .notAuthenticated
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }
                    
                    // 检查是否有其他错误
                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        Logger.shared.error("Yggdrasil 授权失败: \(description)")
                        self?.authState = .error("授权失败: \(description)")
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }
                    
                    // 检查是否成功获取授权码
                    guard authResponse.isSuccess, let code = authResponse.code else {
                        Logger.shared.error("未获取到授权码")
                        self?.authState = .error("minecraft.auth.error.no_authorization_code".localized())
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }
                    
                    await self?.handleAuthorizationCode(code, config: config)
                    continuation.resume()
                }
            }
            
            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = false
            webAuthSession?.start()
        }
    }
    
    // MARK: - 构建授权 URL
    private func buildAuthorizationURL(config: YggdrasilServerConfig) -> URL? {
        guard let authorizeURL = config.authorizeURL else { return nil }
        
        guard var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        var queryItems: [URLQueryItem] = []
        
        // client_id 从配置中读取
        if let clientId = config.clientId {
            queryItems.append(URLQueryItem(name: "client_id", value: clientId))
        }
        
        // 必需的参数
        queryItems.append(URLQueryItem(name: "redirect_uri", value: config.redirectURI))
        queryItems.append(URLQueryItem(name: "response_type", value: "code"))
        queryItems.append(URLQueryItem(name: "scope", value: "Yggdrasil.MinecraftToken.Create Yggdrasil.PlayerProfiles.Read"))
        
        components.queryItems = queryItems
        return components.url
    }
    
    // MARK: - 处理授权码
    @MainActor
    private func handleAuthorizationCode(_ code: String, config: YggdrasilServerConfig) async {
        authState = .processingAuthCode
        
        do {
            // 使用授权码获取访问令牌
            let tokenResponse = try await exchangeCodeForToken(code: code, config: config)
            
            // 获取用户资料
            let profile = try await getYggdrasilProfileThrowing(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? "",
                config: config
            )
            
            Logger.shared.info("Yggdrasil 认证成功，用户: \(profile.name)")
            isLoading = false
            authState = .authenticated(profile: profile)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Yggdrasil 认证失败: \(globalError.chineseMessage)")
            isLoading = false
            authState = .error(globalError.chineseMessage)
        }
    }
    
    // MARK: - 使用授权码交换访问令牌
    private func exchangeCodeForToken(code: String, config: YggdrasilServerConfig) async throws -> YggdrasilTokenResponse {
        guard let tokenURL = config.tokenURL else {
            throw GlobalError.validation(
                chineseMessage: "无效的令牌端点 URL",
                i18nKey: "error.validation.invalid_token_url",
                level: .notification
            )
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyParameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
        ]
        
        // 如果配置了 client_id 和 client_secret，添加到请求体
        if let clientId = config.clientId {
            bodyParameters["client_id"] = clientId
        }
        if let clientSecret = config.clientSecret {
            bodyParameters["client_secret"] = clientSecret
        }
        
        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)
        
        // 使用统一的 API 客户端
        let headers = ["Content-Type": "application/x-www-form-urlencoded"]
        let data = try await APIClient.post(url: tokenURL, body: bodyData, headers: headers)
        
        do {
            // 解析 OAuth 2.0 标准响应
            let oauthResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            
            // 转换为 Yggdrasil 格式
            // 注意：这里可能需要根据实际的 Yggdrasil 服务器响应格式调整
            return YggdrasilTokenResponse(
                accessToken: oauthResponse.accessToken,
                clientToken: nil,
                selectedProfile: nil,
                availableProfiles: nil,
                refreshToken: oauthResponse.refreshToken
            )
        } catch {
            // 如果解析失败，尝试直接解析为 Yggdrasil 格式
            do {
                return try JSONDecoder().decode(YggdrasilTokenResponse.self, from: data)
            } catch {
                throw GlobalError.validation(
                    chineseMessage: "解析令牌响应失败: \(error.localizedDescription)",
                    i18nKey: "error.validation.token_response_parse_failed",
                    level: .notification
                )
            }
        }
    }
    
    // MARK: - 获取 Yggdrasil 用户资料
    private func getYggdrasilProfileThrowing(accessToken: String, refreshToken: String, config: YggdrasilServerConfig) async throws -> YggdrasilProfileResponse {
        // 首先尝试从 OAuth 用户信息端点获取
        if let profileURL = config.profileURL {
            do {
                let headers = ["Authorization": "Bearer \(accessToken)"]
                let data = try await APIClient.get(url: profileURL, headers: headers)
                
                // 打印响应数据用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.shared.debug("OAuth 用户信息端点响应数据: \(responseString)")
                } else {
                    Logger.shared.debug("OAuth 用户信息端点响应数据（无法转换为 UTF-8 字符串）: \(data.count) bytes")
                }
                
                // 解析用户信息（格式可能因服务器而异）
                if let profile = try? parseOAuthProfile(data: data, accessToken: accessToken, refreshToken: refreshToken, config: config) {
                    return profile
                }
            } catch {
                Logger.shared.debug("无法从 OAuth 端点获取用户信息，尝试其他方法: \(error.localizedDescription)")
            }
        }
        
        // 如果 OAuth 端点不可用，尝试使用 Yggdrasil 标准端点
        // 注意：这需要 accessToken 是有效的 Yggdrasil token
        // 某些服务器可能需要先通过 /authserver/authenticate 端点验证
        
        throw GlobalError.validation(
            chineseMessage: "无法获取用户资料，请检查服务器配置",
            i18nKey: "error.validation.profile_fetch_failed",
            level: .notification
        )
    }
    
    // MARK: - 解析 OAuth 用户资料
    private func parseOAuthProfile(data: Data, accessToken: String, refreshToken: String, config: YggdrasilServerConfig) throws -> YggdrasilProfileResponse {
        // 首先尝试解析为角色数组（LittleSkin 等服务器的格式）
        struct ProfileItem: Codable {
            let id: String
            let name: String
            let properties: [ProfileProperty]?
        }
        
        struct ProfileProperty: Codable {
            let name: String
            let value: String
        }
        
        struct TexturesData: Codable {
            let textures: Textures?
        }
        
        struct Textures: Codable {
            let SKIN: TextureInfo?
            let CAPE: TextureInfo?
        }
        
        struct TextureInfo: Codable {
            let url: String
            let metadata: TextureMetadata?
        }
        
        struct TextureMetadata: Codable {
            let model: String?
        }
        
        // 尝试解析为角色数组
        if let profiles = try? JSONDecoder().decode([ProfileItem].self, from: data), !profiles.isEmpty {
            // 使用第一个角色（后续可以添加选择逻辑）
            let selectedProfile = profiles[1]
            
            var skins: [YggdrasilSkin] = []
            var capes: [YggdrasilCape] = []
            
            // 解析 textures 属性
            if let properties = selectedProfile.properties {
                for property in properties where property.name == "textures" {
                    if let textureData = Data(base64Encoded: property.value),
                       let texturesJson = try? JSONDecoder().decode(TexturesData.self, from: textureData) {
                        
                        // 解析皮肤
                        if let skin = texturesJson.textures?.SKIN {
                            let skinId = UUID().uuidString
                            let variant = skin.metadata?.model ?? "classic"
                            let yggdrasilSkin = YggdrasilSkin(
                                id: skinId,
                                state: "ACTIVE",
                                url: skin.url,
                                variant: variant,
                                alias: nil
                            )
                            skins.append(yggdrasilSkin)
                        }
                        
                        // 解析披风
                        if let cape = texturesJson.textures?.CAPE {
                            let capeId = UUID().uuidString
                            let yggdrasilCape = YggdrasilCape(
                                id: capeId,
                                state: "ACTIVE",
                                url: cape.url,
                                alias: nil
                            )
                            capes.append(yggdrasilCape)
                        }
                    }
                }
            }
            
            // 如果没有皮肤，创建一个默认的
            if skins.isEmpty {
                skins.append(YggdrasilSkin(
                    id: "default",
                    state: "ACTIVE",
                    url: "",
                    variant: "classic",
                    alias: nil
                ))
            }
            
            return YggdrasilProfileResponse(
                id: selectedProfile.id,
                name: selectedProfile.name,
                skins: skins,
                capes: capes.isEmpty ? nil : capes,
                accessToken: accessToken,
                refreshToken: refreshToken,
                serverBaseURL: config.baseURL
            )
        }
        
        // 如果解析数组失败，尝试解析标准的 OAuth 用户信息格式
        struct OAuthUserInfo: Codable {
            let sub: String?  // Subject (用户ID)
            let name: String?
            let preferred_username: String?
            let uuid: String?
            let username: String?
        }
        
        let userInfo = try JSONDecoder().decode(OAuthUserInfo.self, from: data)
        
        // 提取用户ID和名称
        let userId = userInfo.uuid ?? userInfo.sub ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let userName = userInfo.name ?? userInfo.preferred_username ?? userInfo.username ?? "Player"
        
        // 创建默认皮肤（如果需要可以从其他端点获取）
        let defaultSkin = YggdrasilSkin(
            id: "default",
            state: "ACTIVE",
            url: "",
            variant: "classic",
            alias: nil
        )
        
        return YggdrasilProfileResponse(
            id: userId,
            name: userName,
            skins: [defaultSkin],
            capes: nil,
            accessToken: accessToken,
            refreshToken: refreshToken,
            serverBaseURL: config.baseURL
        )
    }
    
    // MARK: - 刷新令牌
    func refreshToken(refreshToken: String, config: YggdrasilServerConfig) async throws -> YggdrasilTokenResponse {
        guard let refreshURL = config.refreshURL else {
            throw GlobalError.validation(
                chineseMessage: "无效的刷新令牌端点 URL",
                i18nKey: "error.validation.invalid_refresh_url",
                level: .notification
            )
        }
        
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "accessToken": "",  // 某些服务器可能需要
            "clientToken": "",  // 某些服务器可能需要
            "refreshToken": refreshToken
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let headers = ["Content-Type": "application/json"]
        let data = try await APIClient.post(url: refreshURL, body: bodyData, headers: headers)
        
        do {
            return try JSONDecoder().decode(YggdrasilTokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析刷新令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.refresh_token_parse_failed",
                level: .notification
            )
        }
    }
    
    // MARK: - 登出/取消认证
    @MainActor
    func logout() {
        authState = .notAuthenticated
        webAuthSession?.cancel()
        webAuthSession = nil
        isLoading = false
        serverConfig = nil
    }
    
    // MARK: - 清理认证数据
    @MainActor
    func clearAuthenticationData() {
        authState = .notAuthenticated
        isLoading = false
        webAuthSession?.cancel()
        webAuthSession = nil
        serverConfig = nil
    }
}

// MARK: - OAuth 2.0 Token Response (标准格式)
private struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension YggdrasilAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}


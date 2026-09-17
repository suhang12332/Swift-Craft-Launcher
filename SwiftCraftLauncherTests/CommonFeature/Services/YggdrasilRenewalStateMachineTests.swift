//
//  YggdrasilRenewalStateMachineTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

/// 密码登录续期状态机全路径测试:
/// validate → refresh → 静默重登 → 密码拒绝,全部经由协议缝注入桩响应。
final class YggdrasilRenewalStateMachineTests: XCTestCase {
    private let server = YggdrasilServerConfig(
        name: "TestServer",
        baseURL: URL(string: "https://test.example.com")!,
        redirectURI: "test://auth",
        authorizePath: "",
        tokenPath: "",
        profilePath: "",
        scope: "",
        parserId: .custom,
        token: "",
        loginMethod: .password,
        apiRoot: URL(string: "https://test.example.com")!,
    )

    private func credential(
        accessToken: String = "old-token",
        savedPassword: String? = "saved-pass",
        clientToken: String? = "client-token",
        loginUsername: String? = "user@example.com",
    ) -> AccountCredential {
        AccountCredential(
            userId: "uuid-1",
            authMethod: .yggdrasilPassword,
            accessToken: accessToken,
            renewalSecret: savedPassword,
            clientToken: clientToken,
            loginUsername: loginUsername,
        )
    }

    private func authResponse(
        accessToken: String,
        selected: YggdrasilAuthProfile? = nil,
        available: [YggdrasilAuthProfile] = [],
    ) -> YggdrasilAuthenticateResponse {
        YggdrasilAuthenticateResponse(
            accessToken: accessToken,
            clientToken: "client-token",
            availableProfiles: available.isEmpty && selected == nil ? nil : available,
            selectedProfile: selected,
        )
    }

    // MARK: - ① validate 有效:直接使用,零写入请求

    func testRenewal_validateValid_returnsCredentialWithoutSideEffects() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = true
        let service = YggdrasilAuthService(authServerClient: mock)
        let original = credential(accessToken: "valid-token")

        let outcome = try await service.ensureFreshPasswordCredential(original, server: server)

        XCTAssertEqual(outcome.credential, original)
        XCTAssertNil(outcome.updatedName)
        XCTAssertEqual(mock.validateCalls, 1)
        XCTAssertEqual(mock.refreshCalls, 0, "令牌有效时不应触发有吊销副作用的刷新")
        XCTAssertEqual(mock.authenticateCalls, 0)
    }

    // MARK: - ② refresh 成功

    func testRenewal_refreshSuccess_updatesAccessToken() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .success(authResponse(accessToken: "new-token"))
        let service = YggdrasilAuthService(authServerClient: mock)
        let original = credential()

        let outcome = try await service.ensureFreshPasswordCredential(original, server: server)

        XCTAssertEqual(outcome.credential.accessToken, "new-token")
        XCTAssertEqual(outcome.credential.clientToken, "client-token")
        XCTAssertEqual(outcome.credential.savedPassword, "saved-pass", "记住的密码不应被刷新流程清除")
        XCTAssertNil(outcome.updatedName)
        XCTAssertEqual(mock.refreshCalls, 1)
        XCTAssertEqual(mock.authenticateCalls, 0, "刷新成功时不应回退到密码重登")
    }

    func testRenewal_refreshSuccess_reportsRename() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .success(authResponse(
            accessToken: "new-token",
            selected: YggdrasilAuthProfile(id: "uuid-1", name: "RenamedPlayer"),
        ))
        let service = YggdrasilAuthService(authServerClient: mock)

        let outcome = try await service.ensureFreshPasswordCredential(credential(), server: server)

        XCTAssertEqual(outcome.updatedName, "RenamedPlayer")
    }

    // MARK: - ③ refresh 失败 → 静默重登

    func testRenewal_refreshFails_reloginsWithSavedPassword() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        mock.authenticateResult = .success(authResponse(
            accessToken: "relogin-token",
            available: [YggdrasilAuthProfile(id: "uuid-1", name: "ZeroY")],
        ))
        let service = YggdrasilAuthService(authServerClient: mock)

        let outcome = try await service.ensureFreshPasswordCredential(credential(), server: server)

        XCTAssertEqual(outcome.credential.accessToken, "relogin-token")
        XCTAssertEqual(outcome.updatedName, "ZeroY")
        XCTAssertEqual(mock.authenticateCalls, 1)
    }

    func testRenewal_reloginRejected_throwsPasswordRejectedWithClearedSecret() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        mock.authenticateResult = .failure(YggdrasilAuthServerError.invalidCredentials)
        let service = YggdrasilAuthService(authServerClient: mock)

        do {
            _ = try await service.ensureFreshPasswordCredential(credential(), server: server)
            XCTFail("应抛出 passwordRejected")
        } catch let error as YggdrasilAuthService.YggdrasilRenewalError {
            guard case let .passwordRejected(cleared) = error else {
                return XCTFail("错误类型不符: \(error)")
            }
            XCTAssertNil(cleared.savedPassword, "密码已改时应清除记住值")
            XCTAssertEqual(cleared.loginUsername, "user@example.com", "登录名保留供下次预填")
        }
    }

    func testRenewal_noSavedPassword_throwsReloginRequired() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        let service = YggdrasilAuthService(authServerClient: mock)
        let noPassword = credential(savedPassword: nil)

        do {
            _ = try await service.ensureFreshPasswordCredential(noPassword, server: server)
            XCTFail("应抛出要求重新登录的错误")
        } catch let error as GlobalError {
            XCTAssertEqual(error.i18nKey, "yggdrasil.error.token_expired_relogin")
        }
    }

    func testRenewal_reloginProfileMissing_throwsProfileMissing() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        mock.authenticateResult = .success(authResponse(
            accessToken: "relogin-token",
            available: [YggdrasilAuthProfile(id: "other-uuid", name: "SomeoneElse")],
        ))
        let service = YggdrasilAuthService(authServerClient: mock)

        do {
            _ = try await service.ensureFreshPasswordCredential(credential(), server: server)
            XCTFail("应抛出角色缺失错误")
        } catch let error as GlobalError {
            XCTAssertEqual(error.i18nKey, "yggdrasil.error.profile_missing")
        }
    }
}

/// 可编程桩客户端:记录调用次数,按用例配置返回值。
private final class MockAuthServerClient: YggdrasilAuthServerClientProtocol, @unchecked Sendable {
    var validateResult = true
    var refreshResult = Result<YggdrasilAuthenticateResponse, Error>.failure(YggdrasilAuthServerError.invalidToken)
    var authenticateResult = Result<YggdrasilAuthenticateResponse, Error>.failure(YggdrasilAuthServerError.invalidCredentials)

    private(set) var validateCalls = 0
    private(set) var refreshCalls = 0
    private(set) var authenticateCalls = 0

    func authenticate(
        username _: String,
        password _: String,
        clientToken _: String,
        apiRoot _: URL,
    ) async throws -> YggdrasilAuthenticateResponse {
        authenticateCalls += 1
        return try authenticateResult.get()
    }

    func refresh(
        accessToken _: String,
        clientToken _: String,
        selectedProfileId _: String?,
        apiRoot _: URL,
    ) async throws -> YggdrasilAuthenticateResponse {
        refreshCalls += 1
        return try refreshResult.get()
    }

    func validate(accessToken _: String, clientToken _: String, apiRoot _: URL) async -> Bool {
        validateCalls += 1
        return validateResult
    }

    func fetchSessionProfile(uuid: String, apiRoot _: URL) async throws -> YggdrasilSessionProfile {
        YggdrasilSessionProfile(id: uuid, name: uuid, skinURL: nil)
    }
}

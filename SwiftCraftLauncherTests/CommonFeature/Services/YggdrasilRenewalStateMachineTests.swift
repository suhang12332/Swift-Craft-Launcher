//
//  YggdrasilRenewalStateMachineTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

/// Covers every path of the password renewal state machine
/// (validate → refresh → silent re-login → password rejected) and profile binding
/// when adding an account, using a stub client injected through the protocol seam.
final class YggdrasilRenewalStateMachineTests: XCTestCase {
    private let apiRoot = URL(string: "https://test.example.com/api/yggdrasil")!

    private let passwordServer = YggdrasilServerConfig(
        name: "TestServer",
        baseURL: URL(string: "https://test.example.com/api/yggdrasil")!,
        redirectURI: "test://auth",
        authorizePath: "",
        tokenPath: "",
        profilePath: "",
        scope: "",
        parserId: .custom,
        token: "",
        loginMethod: .password,
        apiRoot: URL(string: "https://test.example.com/api/yggdrasil")!,
    )

    private func profile(
        id: String = "uuid-1",
        accessToken: String = "old-token",
        savedPassword: String? = "saved-pass",
        loginUsername: String? = "user@example.com",
    ) -> YggdrasilProfile {
        YggdrasilProfile(
            id: id,
            name: "ZeroY",
            skins: [],
            capes: nil,
            accessToken: accessToken,
            refreshToken: "",
            serverBaseURL: "https://test.example.com/api/yggdrasil",
            loginMethod: .password,
            clientToken: "client-token",
            loginUsername: loginUsername,
            savedPassword: savedPassword,
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

    // Renewal

    func testRenewal_validateValid_returnsProfileWithoutSideEffects() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = true
        let service = YggdrasilAuthService(authServerClient: mock)
        let original = profile(accessToken: "valid-token")

        let renewed = try await service.renewPasswordProfile(original, apiRoot: apiRoot)

        XCTAssertEqual(renewed, original)
        XCTAssertEqual(mock.validateCalls, 1)
        XCTAssertEqual(mock.refreshCalls, 0, "A valid token must not trigger a revoking refresh")
        XCTAssertEqual(mock.authenticateCalls, 0)
    }

    func testRenewal_refreshSuccess_updatesAccessToken() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .success(authResponse(accessToken: "new-token"))
        let service = YggdrasilAuthService(authServerClient: mock)

        let renewed = try await service.renewPasswordProfile(profile(), apiRoot: apiRoot)

        XCTAssertEqual(renewed.accessToken, "new-token")
        XCTAssertEqual(renewed.clientToken, "client-token")
        XCTAssertEqual(renewed.savedPassword, "saved-pass", "Refreshing must keep the remembered password")
        XCTAssertEqual(renewed.name, "ZeroY")
        XCTAssertEqual(mock.refreshCalls, 1)
        XCTAssertEqual(mock.authenticateCalls, 0, "A successful refresh must not fall back to re-login")
    }

    func testRenewal_refreshSuccess_reportsRename() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .success(authResponse(
            accessToken: "new-token",
            selected: YggdrasilAuthProfile(id: "uuid-1", name: "RenamedPlayer"),
        ))
        let service = YggdrasilAuthService(authServerClient: mock)

        let renewed = try await service.renewPasswordProfile(profile(), apiRoot: apiRoot)

        XCTAssertEqual(renewed.name, "RenamedPlayer")
    }

    func testRenewal_refreshFails_reloginsWithSavedPassword() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        mock.authenticateResult = .success(authResponse(
            accessToken: "relogin-token",
            available: [YggdrasilAuthProfile(id: "uuid-1", name: "ZeroY")],
        ))
        let service = YggdrasilAuthService(authServerClient: mock)

        let renewed = try await service.renewPasswordProfile(profile(), apiRoot: apiRoot)

        XCTAssertEqual(renewed.accessToken, "relogin-token")
        XCTAssertEqual(renewed.savedPassword, "saved-pass")
        XCTAssertEqual(mock.authenticateCalls, 1)
    }

    func testRenewal_reloginRejected_throwsPasswordRejectedWithClearedPassword() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        mock.authenticateResult = .failure(YggdrasilAuthServerError.invalidCredentials)
        let service = YggdrasilAuthService(authServerClient: mock)

        do {
            _ = try await service.renewPasswordProfile(profile(), apiRoot: apiRoot)
            XCTFail("Expected passwordRejected")
        } catch let error as YggdrasilAuthService.YggdrasilRenewalError {
            guard case let .passwordRejected(cleared) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertNil(cleared.savedPassword, "A changed password must clear the remembered value")
            XCTAssertEqual(cleared.loginUsername, "user@example.com", "The login name is kept for prefilling")
        }
    }

    func testRenewal_noSavedPassword_throwsReloginRequired() async throws {
        let mock = MockAuthServerClient()
        mock.validateResult = false
        mock.refreshResult = .failure(YggdrasilAuthServerError.invalidToken)
        let service = YggdrasilAuthService(authServerClient: mock)

        do {
            _ = try await service.renewPasswordProfile(profile(savedPassword: nil), apiRoot: apiRoot)
            XCTFail("Expected a re-login error")
        } catch let error as GlobalError {
            XCTAssertEqual(error.i18nKey, "yggdrasil.error.token_expired_relogin")
            XCTAssertEqual(mock.authenticateCalls, 0)
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
            _ = try await service.renewPasswordProfile(profile(), apiRoot: apiRoot)
            XCTFail("Expected a missing-profile error")
        } catch let error as GlobalError {
            XCTAssertEqual(error.i18nKey, "yggdrasil.error.profile_missing")
        }
    }

    // Binding when adding an account

    @MainActor
    func testPrepare_unboundPasswordToken_bindsAndDropsOtherCandidates() async {
        let mock = MockAuthServerClient()
        mock.refreshResult = .success(authResponse(
            accessToken: "bound-token",
            selected: YggdrasilAuthProfile(id: "uuid-2", name: "Second"),
        ))
        let service = YggdrasilAuthService(authServerClient: mock)
        service.setServer(passwordServer)
        service.authenticatedProfiles = [profile(id: "uuid-1"), profile(id: "uuid-2")]
        service.passwordTokenNeedsBinding = true

        let ready = await service.prepareProfileForAdding(profile(id: "uuid-2"))

        XCTAssertEqual(ready?.id, "uuid-2")
        XCTAssertEqual(ready?.accessToken, "bound-token")
        XCTAssertEqual(mock.refreshCalls, 1)
        XCTAssertFalse(service.passwordTokenNeedsBinding)
        XCTAssertEqual(service.authenticatedProfiles.map(\.id), ["uuid-2"], "The token is bound; other candidates are unusable")
    }

    @MainActor
    func testPrepare_bindingFails_returnsNilAndEndsInError() async {
        let mock = MockAuthServerClient()
        mock.refreshResult = .failure(YggdrasilAuthServerError.rejected("Bind failed"))
        let service = YggdrasilAuthService(authServerClient: mock)
        service.setServer(passwordServer)
        service.authenticatedProfiles = [profile(id: "uuid-1"), profile(id: "uuid-2")]
        service.passwordTokenNeedsBinding = true

        let ready = await service.prepareProfileForAdding(profile(id: "uuid-1"))

        XCTAssertNil(ready, "An unbound token must never be handed out for storage")
        XCTAssertEqual(service.authState, .error("Bind failed"))
    }

    @MainActor
    func testPrepare_alreadyBound_returnsProfileWithoutNetwork() async {
        let mock = MockAuthServerClient()
        let service = YggdrasilAuthService(authServerClient: mock)
        service.setServer(passwordServer)
        let original = profile()

        let ready = await service.prepareProfileForAdding(original)

        XCTAssertEqual(ready, original)
        XCTAssertEqual(mock.refreshCalls, 0)
    }

    // Storage compatibility

    func testProfile_decodesLegacyStoredJSONWithoutPasswordFields() throws {
        let legacy = """
        {"id":"uuid-1","name":"ZeroY","skins":[],"accessToken":"token","refreshToken":"refresh",\
        "serverBaseURL":"https://littleskin.cn"}
        """
        let decoded = try JSONDecoder().decode(YggdrasilProfile.self, from: Data(legacy.utf8))

        XCTAssertNil(decoded.loginMethod)
        XCTAssertFalse(decoded.isPasswordLogin, "Profiles stored before password login are OAuth profiles")
        XCTAssertNil(decoded.savedPassword)
    }
}

/// Programmable stub client that records calls and returns per-test results.
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

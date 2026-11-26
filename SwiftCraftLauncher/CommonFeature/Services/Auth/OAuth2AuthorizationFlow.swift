//
//  OAuth2AuthorizationFlow.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AuthenticationServices
import Foundation

/// The outcome of a browser-based OAuth2 authorization request.
enum OAuth2AuthorizationResult: Equatable {
    /// The provider returned an authorization code.
    case authorized(code: String)

    /// The user cancelled the browser session.
    case cancelled

    /// The user denied the authorization request.
    case denied
}

/// Errors produced by the shared OAuth2 authorization flow.
enum OAuth2AuthorizationError: Error, Equatable {
    case invalidCallbackURL
    case missingAuthorizationCode
    case authorizationFailed(String)
    case sessionFailed(String)
}

/// Runs the browser-based OAuth2 authorization code flow shared by all providers.
///
/// This only handles the browser session and callback parsing. Providers are
/// responsible for building the authorization URL and exchanging the returned
/// code for tokens.
@MainActor
final class OAuth2AuthorizationFlow {
    private let webAuthenticator = WebAuthenticator()

    /// Cancels any active authorization session.
    func cancel() {
        webAuthenticator.cancel()
    }

    /// Starts an authorization session and waits for the callback.
    ///
    /// - Parameters:
    ///   - authorizationURL: The URL to open in the browser.
    ///   - callbackScheme: The scheme to listen for in the callback URL.
    ///   - prefersEphemeral: Whether to use an ephemeral (private) browser session.
    /// - Returns: The authorization result.
    func requestAuthorizationCode(
        authorizationURL: URL,
        callbackScheme: String?,
        prefersEphemeral: Bool,
    ) async throws -> OAuth2AuthorizationResult {
        cancel()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OAuth2AuthorizationResult, Error>) in
            webAuthenticator.start(
                authorizationURL: authorizationURL,
                callbackScheme: callbackScheme,
                prefersEphemeral: prefersEphemeral,
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            continuation.resume(returning: .cancelled)
                        } else {
                            continuation.resume(throwing: OAuth2AuthorizationError.sessionFailed(error.localizedDescription))
                        }
                        return
                    }

                    guard let callbackURL,
                          let response = AuthorizationCodeResponse(from: callbackURL) else {
                        continuation.resume(throwing: OAuth2AuthorizationError.invalidCallbackURL)
                        return
                    }

                    if response.isUserDenied {
                        continuation.resume(returning: .denied)
                        return
                    }

                    if let error = response.error {
                        continuation.resume(throwing: OAuth2AuthorizationError.authorizationFailed(response.errorDescription ?? error))
                        return
                    }

                    guard response.isSuccess, let code = response.code else {
                        continuation.resume(throwing: OAuth2AuthorizationError.missingAuthorizationCode)
                        return
                    }

                    continuation.resume(returning: .authorized(code: code))
                }
            }
        }
    }
}

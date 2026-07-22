//
//  WebAuthenticator.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import AuthenticationServices
import Foundation

/// Encapsulates the ASWebAuthenticationSession lifecycle shared by all OAuth2 flows.
final class WebAuthenticator: NSObject {
    private var session: ASWebAuthenticationSession?

    func cancel() {
        session?.cancel()
        session = nil
    }

    /// Starts a browser-based OAuth2 authorization code flow.
    ///
    /// - Parameters:
    ///   - authorizationURL: The URL to open in the browser.
    ///   - callbackScheme: The scheme to listen for in the callback URL.
    ///   - prefersEphemeral: Whether to use an ephemeral (private) browser session.
    ///   - onCallback: Called with the callback URL or error when the flow completes.
    func start(
        authorizationURL: URL,
        callbackScheme: String?,
        prefersEphemeral: Bool,
        onCallback: @escaping (URL?, Error?) -> Void,
    ) {
        cancel()

        let newSession = ASWebAuthenticationSession(
            url: authorizationURL,
            callbackURLScheme: callbackScheme,
            completionHandler: onCallback,
        )
        newSession.presentationContextProvider = self
        newSession.prefersEphemeralWebBrowserSession = prefersEphemeral
        session = newSession
        newSession.start()
    }
}

extension WebAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

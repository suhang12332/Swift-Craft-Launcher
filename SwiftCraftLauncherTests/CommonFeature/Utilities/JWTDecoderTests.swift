//
//  JWTDecoderTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import XCTest
@testable import SwiftCraftLauncher

final class JWTDecoderTests: XCTestCase {

    func testExtractExpirationTime_validJWT() throws {
        let payload: [String: Any] = ["exp": 1700000000.0]
        let jwt = try Self.makeJWT(payload: payload)

        let result = JWTDecoder.extractExpirationTime(from: jwt)
        XCTAssertEqual(result, Date(timeIntervalSince1970: 1700000000))
    }

    func testExtractExpirationTime_invalidFormat_notThreeParts() {
        XCTAssertNil(JWTDecoder.extractExpirationTime(from: "only.two"))
    }

    func testExtractExpirationTime_invalidFormat_emptyString() {
        XCTAssertNil(JWTDecoder.extractExpirationTime(from: ""))
    }

    func testExtractExpirationTime_invalidBase64() {
        let jwt = "header.!!!invalid-base64!!!.signature"
        XCTAssertNil(JWTDecoder.extractExpirationTime(from: jwt))
    }

    func testExtractExpirationTime_missingExpField() throws {
        let payload: [String: Any] = ["sub": "1234567890"]
        let jwt = try Self.makeJWT(payload: payload)

        XCTAssertNil(JWTDecoder.extractExpirationTime(from: jwt))
    }

    func testExtractExpirationTime_emptyPayload() throws {
        let payload: [String: Any] = [:]
        let jwt = try Self.makeJWT(payload: payload)

        XCTAssertNil(JWTDecoder.extractExpirationTime(from: jwt))
    }

    func testExtractAllInfo_validJWT() throws {
        let payload: [String: Any] = ["sub": "1234567890", "name": "TestUser", "exp": 1700000000.0]
        let jwt = try Self.makeJWT(payload: payload)

        let info = JWTDecoder.extractAllInfo(from: jwt)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?["sub"] as? String, "1234567890")
        XCTAssertEqual(info?["name"] as? String, "TestUser")
        XCTAssertEqual(info?["exp"] as? TimeInterval, 1700000000)
    }

    func testExtractAllInfo_invalidFormat() {
        XCTAssertNil(JWTDecoder.extractAllInfo(from: "invalid"))
    }

    func testExtractAllInfo_emptyString() {
        XCTAssertNil(JWTDecoder.extractAllInfo(from: ""))
    }

    func testIsTokenExpiringSoon_alreadyExpired() throws {
        let payload: [String: Any] = ["exp": 1000000000.0]
        let jwt = try Self.makeJWT(payload: payload)

        XCTAssertTrue(JWTDecoder.isTokenExpiringSoon(jwt))
    }

    func testIsTokenExpiringSoon_validToken() throws {
        let futureTimestamp = Date().timeIntervalSince1970 + 7200
        let payload: [String: Any] = ["exp": futureTimestamp]
        let jwt = try Self.makeJWT(payload: payload)

        XCTAssertFalse(JWTDecoder.isTokenExpiringSoon(jwt))
    }

    func testIsTokenExpiringSoon_withBuffer_expiringIn4Minutes() throws {
        let futureTimestamp = Date().timeIntervalSince1970 + 240
        let payload: [String: Any] = ["exp": futureTimestamp]
        let jwt = try Self.makeJWT(payload: payload)

        XCTAssertTrue(JWTDecoder.isTokenExpiringSoon(jwt, bufferTime: 300))
    }

    func testIsTokenExpiringSoon_withBuffer_validToken() throws {
        let futureTimestamp = Date().timeIntervalSince1970 + 600
        let payload: [String: Any] = ["exp": futureTimestamp]
        let jwt = try Self.makeJWT(payload: payload)

        XCTAssertFalse(JWTDecoder.isTokenExpiringSoon(jwt, bufferTime: 300))
    }

    func testIsTokenExpiringSoon_invalidToken_returnsTrue() {
        XCTAssertTrue(JWTDecoder.isTokenExpiringSoon("invalid"))
    }

    func testGetMinecraftTokenExpiration_validJWT() throws {
        let payload: [String: Any] = ["exp": 1700000000.0]
        let jwt = try Self.makeJWT(payload: payload)

        let expiration = JWTDecoder.getMinecraftTokenExpiration(from: jwt)
        XCTAssertEqual(expiration, Date(timeIntervalSince1970: 1700000000))
    }

    func testGetMinecraftTokenExpiration_invalidJWT_usesDefault() {
        let before = Date()
        let expiration = JWTDecoder.getMinecraftTokenExpiration(from: "invalid")
        let after = Date()

        let expectedDefault = before.addingTimeInterval(24 * 60 * 60)
        let expectedDefaultAfter = after.addingTimeInterval(24 * 60 * 60)

        XCTAssertGreaterThanOrEqual(expiration, expectedDefault.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual(expiration, expectedDefaultAfter.addingTimeInterval(1))
    }

    private static func makeJWT(payload: [String: Any]) throws -> String {
        let header = try base64Encode(["alg": "HS256", "typ": "JWT"])
        let body = try base64Encode(payload)
        let signature = try base64Encode(["sig": "test"])
        return "\(header).\(body).\(signature)"
    }

    private static func base64Encode(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

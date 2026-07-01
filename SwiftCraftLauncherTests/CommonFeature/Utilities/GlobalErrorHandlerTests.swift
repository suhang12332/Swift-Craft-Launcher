//
//  GlobalErrorHandlerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class GlobalErrorHandlerTests: XCTestCase {
    private func flushMainQueue() {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }

    func testErrorLevel_allCases() {
        XCTAssertEqual(ErrorLevel.allCases.count, 4)
    }

    func testErrorLevel_rawValues() {
        XCTAssertEqual(ErrorLevel.popup.rawValue, "popup")
        XCTAssertEqual(ErrorLevel.notification.rawValue, "notification")
        XCTAssertEqual(ErrorLevel.silent.rawValue, "silent")
        XCTAssertEqual(ErrorLevel.disabled.rawValue, "disabled")
    }

    func testGlobalErrorKind_allCases() {
        XCTAssertEqual(GlobalErrorKind.allCases.count, 11)
    }

    func testGlobalErrorKind_defaultLevel() {
        XCTAssertEqual(GlobalErrorKind.authentication.defaultLevel, .popup)
        XCTAssertEqual(GlobalErrorKind.gameLaunch.defaultLevel, .popup)
        XCTAssertEqual(GlobalErrorKind.unknown.defaultLevel, .silent)
        XCTAssertEqual(GlobalErrorKind.network.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.fileSystem.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.validation.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.download.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.installation.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.resource.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.player.defaultLevel, .notification)
        XCTAssertEqual(GlobalErrorKind.configuration.defaultLevel, .notification)
    }

    func testGlobalErrorKind_idPrefix() {
        XCTAssertEqual(GlobalErrorKind.network.idPrefix, "network")
        XCTAssertEqual(GlobalErrorKind.fileSystem.idPrefix, "filesystem")
        XCTAssertEqual(GlobalErrorKind.authentication.idPrefix, "auth")
        XCTAssertEqual(GlobalErrorKind.validation.idPrefix, "validation")
        XCTAssertEqual(GlobalErrorKind.download.idPrefix, "download")
        XCTAssertEqual(GlobalErrorKind.installation.idPrefix, "installation")
        XCTAssertEqual(GlobalErrorKind.gameLaunch.idPrefix, "gameLaunch")
        XCTAssertEqual(GlobalErrorKind.resource.idPrefix, "resource")
        XCTAssertEqual(GlobalErrorKind.player.idPrefix, "player")
        XCTAssertEqual(GlobalErrorKind.configuration.idPrefix, "config")
        XCTAssertEqual(GlobalErrorKind.unknown.idPrefix, "unknown")
    }

    func testGlobalErrorKind_notificationTitleKey() {
        XCTAssertTrue(GlobalErrorKind.network.notificationTitleKey.contains("network"))
        XCTAssertTrue(GlobalErrorKind.authentication.notificationTitleKey.contains("authentication"))
        XCTAssertTrue(GlobalErrorKind.unknown.notificationTitleKey.contains("unknown"))
    }

    func testGlobalError_init_defaultLevel() {
        let error = GlobalError(kind: .network, i18nKey: "test.key")
        XCTAssertEqual(error.level, .notification)
    }

    func testGlobalError_init_customLevel() {
        let error = GlobalError(kind: .network, i18nKey: "test.key", level: .popup)
        XCTAssertEqual(error.level, .popup)
    }

    func testGlobalError_id_containsPrefixAndKey() {
        let error = GlobalError(kind: .network, i18nKey: "error.test")
        XCTAssertTrue(error.id.hasPrefix("network_"))
        XCTAssertTrue(error.id.contains("error.test"))
    }

    func testGlobalError_errorDescription_returnsI18nKey() {
        let error = GlobalError(kind: .validation, i18nKey: "error.validation.test")
        XCTAssertEqual(error.errorDescription, "error.validation.test".localized())
    }

    func testGlobalError_network() {
        let error = GlobalError.network(i18nKey: "error.network.test")
        XCTAssertEqual(error.kind, .network)
        XCTAssertEqual(error.level, .notification)
    }

    func testGlobalError_fileSystem() {
        let error = GlobalError.fileSystem(i18nKey: "error.fs.test")
        XCTAssertEqual(error.kind, .fileSystem)
    }

    func testGlobalError_authentication() {
        let error = GlobalError.authentication(i18nKey: "error.auth.test")
        XCTAssertEqual(error.kind, .authentication)
        XCTAssertEqual(error.level, .popup)
    }

    func testGlobalError_validation() {
        let error = GlobalError.validation(i18nKey: "error.val.test")
        XCTAssertEqual(error.kind, .validation)
    }

    func testGlobalError_download() {
        let error = GlobalError.download(i18nKey: "error.dl.test")
        XCTAssertEqual(error.kind, .download)
    }

    func testGlobalError_installation() {
        let error = GlobalError.installation(i18nKey: "error.inst.test")
        XCTAssertEqual(error.kind, .installation)
    }

    func testGlobalError_gameLaunch() {
        let error = GlobalError.gameLaunch(i18nKey: "error.launch.test")
        XCTAssertEqual(error.kind, .gameLaunch)
        XCTAssertEqual(error.level, .popup)
    }

    func testGlobalError_resource() {
        let error = GlobalError.resource(i18nKey: "error.res.test")
        XCTAssertEqual(error.kind, .resource)
    }

    func testGlobalError_player() {
        let error = GlobalError.player(i18nKey: "error.player.test")
        XCTAssertEqual(error.kind, .player)
    }

    func testGlobalError_configuration() {
        let error = GlobalError.configuration(i18nKey: "error.config.test")
        XCTAssertEqual(error.kind, .configuration)
    }

    func testGlobalError_unknown() {
        let error = GlobalError.unknown(i18nKey: "error.unknown.test")
        XCTAssertEqual(error.kind, .unknown)
        XCTAssertEqual(error.level, .silent)
    }

    func testFrom_globalError_passthrough() {
        let original = GlobalError.network(i18nKey: "test.key")
        let converted = GlobalError.from(original)
        XCTAssertEqual(converted.kind, original.kind)
    }

    func testFrom_urlError() {
        let urlError = URLError(.notConnectedToInternet)
        let converted = GlobalError.from(urlError)
        XCTAssertEqual(converted.kind, .network)
    }

    func testFrom_urlError_cancelled_isSilent() {
        let urlError = URLError(.cancelled)
        let converted = GlobalError.from(urlError)
        XCTAssertEqual(converted.level, .silent)
    }

    func testFrom_cocoaError() {
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: 260, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        let converted = GlobalError.from(cocoaError)
        XCTAssertEqual(converted.kind, .fileSystem)
    }

    func testFrom_unknownError() {
        let unknownError = NSError(domain: "com.test", code: 1, userInfo: nil)
        let converted = GlobalError.from(unknownError)
        XCTAssertEqual(converted.kind, .unknown)
    }

    func testHandle_deduplicatesSameErrorWithinWindow() {
        let handler = GlobalErrorHandler()
        let error = GlobalError.network(i18nKey: "error.dedup.test")

        handler.handle(error)
        flushMainQueue()
        let first = handler.currentError

        handler.handle(error)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.id, first?.id, "Same error within dedup window should not update currentError")
    }

    func testHandle_allowsSameErrorAfterDedupWindow() {
        let handler = GlobalErrorHandler()
        let error = GlobalError.network(i18nKey: "error.dedup.after")

        handler.handle(error)
        flushMainQueue()
        handler.clearCurrentError()
        flushMainQueue()
        XCTAssertNil(handler.currentError)

        let other = GlobalError.fileSystem(i18nKey: "error.dedup.other")
        handler.handle(other)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.id, other.id)
    }

    func testHandle_allowsDifferentErrorsImmediately() {
        let handler = GlobalErrorHandler()
        let error1 = GlobalError.network(i18nKey: "error.diff.a")
        let error2 = GlobalError.fileSystem(i18nKey: "error.diff.b")

        handler.handle(error1)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.id, error1.id)

        handler.handle(error2)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.id, error2.id)
    }

    func testHandle_rateLimitsExcessErrors() {
        let handler = GlobalErrorHandler()

        for i in 0 ..< 5 {
            handler.handle(GlobalError.network(i18nKey: "error.rate.\(i)"))
            flushMainQueue()
        }
        XCTAssertEqual(handler.currentError?.id, "network_error.rate.4")

        handler.handle(GlobalError.fileSystem(i18nKey: "error.rate.overflow"))
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.id, "network_error.rate.4", "6th error within rate-limit window should be suppressed")
    }

    func testHandle_rateLimitResetsAfterWindow() {
        let handler = GlobalErrorHandler()

        for i in 0 ..< 5 {
            handler.handle(GlobalError.network(i18nKey: "error.rl.reset.\(i)"))
            flushMainQueue()
        }
        handler.clearCurrentError()
        flushMainQueue()

        handler.cleanup()
        handler.handle(GlobalError.fileSystem(i18nKey: "error.rl.reset.new"))
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.id, "filesystem_error.rl.reset.new")
    }

    func testHandle_popupLevel_setsCurrentError() {
        let handler = GlobalErrorHandler()
        let error = GlobalError.authentication(i18nKey: "error.popup.test", level: .popup)

        handler.handle(error)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.level, .popup)
        XCTAssertEqual(handler.errorHistory.last?.level, .popup)
    }

    func testHandle_notificationLevel_setsCurrentError() {
        let handler = GlobalErrorHandler()
        let error = GlobalError.network(i18nKey: "error.notif.test", level: .notification)

        handler.handle(error)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.level, .notification)
        XCTAssertEqual(handler.errorHistory.last?.level, .notification)
    }

    func testHandle_silentLevel_setsCurrentError() {
        let handler = GlobalErrorHandler()
        let error = GlobalError.unknown(i18nKey: "error.silent.test", level: .silent)

        handler.handle(error)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.level, .silent)
        XCTAssertEqual(handler.errorHistory.last?.level, .silent)
    }

    func testHandle_disabledLevel_stillSetsCurrentError() {
        let handler = GlobalErrorHandler()
        let error = GlobalError.network(i18nKey: "error.disabled.test", level: .disabled)

        handler.handle(error)
        flushMainQueue()
        XCTAssertEqual(handler.currentError?.level, .disabled)
        XCTAssertEqual(handler.errorHistory.last?.level, .disabled)
    }

    func testHandle_allLevels_recordedInHistory() {
        let handler = GlobalErrorHandler()
        let levels: [ErrorLevel] = [.popup, .notification, .silent, .disabled]

        for (i, level) in levels.enumerated() {
            handler.handle(GlobalError.network(i18nKey: "error.level.\(i)", level: level))
            flushMainQueue()
        }

        XCTAssertEqual(handler.errorHistory.count, 4)
        let mappedLevels = handler.errorHistory.map(\.level)
        XCTAssertEqual(mappedLevels, levels)
    }

    func testCleanup_resetsAllState() {
        let handler = GlobalErrorHandler()
        handler.handle(GlobalError.network(i18nKey: "error.cleanup"))
        flushMainQueue()
        handler.cleanup()
        flushMainQueue()

        XCTAssertNil(handler.currentError)
        XCTAssertTrue(handler.errorHistory.isEmpty)
    }
}

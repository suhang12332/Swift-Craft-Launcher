//
//  GlobalErrorHandlerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class GlobalErrorHandlerTests: XCTestCase {
    func testErrorLevel_allCases() {
        XCTAssertEqual(ErrorLevel.allCases.count, 4)
    }

    func testErrorLevel_displayName() {
        XCTAssertEqual(ErrorLevel.popup.displayName, "弹窗")
        XCTAssertEqual(ErrorLevel.notification.displayName, "通知")
        XCTAssertEqual(ErrorLevel.silent.displayName, "静默")
        XCTAssertEqual(ErrorLevel.disabled.displayName, "无操作")
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
        let error = GlobalError(kind: .network, chineseMessage: "test", i18nKey: "test.key")
        XCTAssertEqual(error.level, .notification)
    }

    func testGlobalError_init_customLevel() {
        let error = GlobalError(kind: .network, chineseMessage: "test", i18nKey: "test.key", level: .popup)
        XCTAssertEqual(error.level, .popup)
    }

    func testGlobalError_id_containsPrefixAndKey() {
        let error = GlobalError(kind: .network, chineseMessage: "msg", i18nKey: "error.test")
        XCTAssertTrue(error.id.hasPrefix("network_"))
        XCTAssertTrue(error.id.contains("error.test"))
    }

    func testGlobalError_errorDescription_returnsI18nKey() {
        let error = GlobalError(kind: .validation, chineseMessage: "test", i18nKey: "error.validation.test")
        XCTAssertEqual(error.errorDescription, "error.validation.test".localized())
    }

    func testGlobalError_network() {
        let error = GlobalError.network(chineseMessage: "网络错误", i18nKey: "error.network.test")
        XCTAssertEqual(error.kind, .network)
        XCTAssertEqual(error.chineseMessage, "网络错误")
        XCTAssertEqual(error.level, .notification)
    }

    func testGlobalError_fileSystem() {
        let error = GlobalError.fileSystem(chineseMessage: "文件错误", i18nKey: "error.fs.test")
        XCTAssertEqual(error.kind, .fileSystem)
    }

    func testGlobalError_authentication() {
        let error = GlobalError.authentication(chineseMessage: "认证错误", i18nKey: "error.auth.test")
        XCTAssertEqual(error.kind, .authentication)
        XCTAssertEqual(error.level, .popup)
    }

    func testGlobalError_validation() {
        let error = GlobalError.validation(chineseMessage: "验证错误", i18nKey: "error.val.test")
        XCTAssertEqual(error.kind, .validation)
    }

    func testGlobalError_download() {
        let error = GlobalError.download(chineseMessage: "下载错误", i18nKey: "error.dl.test")
        XCTAssertEqual(error.kind, .download)
    }

    func testGlobalError_installation() {
        let error = GlobalError.installation(chineseMessage: "安装错误", i18nKey: "error.inst.test")
        XCTAssertEqual(error.kind, .installation)
    }

    func testGlobalError_gameLaunch() {
        let error = GlobalError.gameLaunch(chineseMessage: "启动错误", i18nKey: "error.launch.test")
        XCTAssertEqual(error.kind, .gameLaunch)
        XCTAssertEqual(error.level, .popup)
    }

    func testGlobalError_resource() {
        let error = GlobalError.resource(chineseMessage: "资源错误", i18nKey: "error.res.test")
        XCTAssertEqual(error.kind, .resource)
    }

    func testGlobalError_player() {
        let error = GlobalError.player(chineseMessage: "玩家错误", i18nKey: "error.player.test")
        XCTAssertEqual(error.kind, .player)
    }

    func testGlobalError_configuration() {
        let error = GlobalError.configuration(chineseMessage: "配置错误", i18nKey: "error.config.test")
        XCTAssertEqual(error.kind, .configuration)
    }

    func testGlobalError_unknown() {
        let error = GlobalError.unknown(chineseMessage: "未知错误", i18nKey: "error.unknown.test")
        XCTAssertEqual(error.kind, .unknown)
        XCTAssertEqual(error.level, .silent)
    }

    func testFrom_globalError_passthrough() {
        let original = GlobalError.network(chineseMessage: "test", i18nKey: "test.key")
        let converted = GlobalError.from(original)
        XCTAssertEqual(converted.kind, original.kind)
        XCTAssertEqual(converted.chineseMessage, original.chineseMessage)
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
}

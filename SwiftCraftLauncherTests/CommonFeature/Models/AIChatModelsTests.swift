//
//  AIChatModelsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class AIChatModelsTests: XCTestCase {
    func testMessageRole_rawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    func testMessageRole_codable() throws {
        let role = MessageRole.user
        let data = try JSONEncoder().encode(role)
        let decoded = try JSONDecoder().decode(MessageRole.self, from: data)
        XCTAssertEqual(decoded, .user)
    }

    func testMessageAttachmentType_fileId() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let type = MessageAttachmentType.file(url, "test.pdf")
        XCTAssertEqual(type.id, "file_/tmp/test.pdf")
    }

    func testChatMessage_init_defaults() {
        let message = ChatMessage(role: .user, content: "hello")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "hello")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
        XCTAssertTrue(message.attachments.isEmpty)
    }

    func testChatMessage_init_withAttachments() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let attachment = MessageAttachmentType.file(url, "test.pdf")
        let message = ChatMessage(role: .user, content: "test", attachments: [attachment])
        XCTAssertEqual(message.attachments.count, 1)
    }

    func testChatMessage_equatable() {
        let id = UUID()
        let date = Date()
        let a = ChatMessage(id: id, role: .user, content: "test", timestamp: date)
        let b = ChatMessage(id: id, role: .user, content: "test", timestamp: date)
        XCTAssertEqual(a, b)
    }

    func testChatMessage_apiRoleString() {
        XCTAssertEqual(ChatMessage(role: .user).apiRoleString, "user")
        XCTAssertEqual(ChatMessage(role: .assistant).apiRoleString, "assistant")
        XCTAssertEqual(ChatMessage(role: .system).apiRoleString, "system")
    }

    @MainActor
    func testChatState_addMessage() {
        let state = ChatState()
        let message = ChatMessage(role: .user, content: "hello")
        state.addMessage(message)
        XCTAssertEqual(state.messages.count, 1)
        XCTAssertEqual(state.messages.first?.content, "hello")
    }

    @MainActor
    func testChatState_updateLastMessage() {
        let state = ChatState()
        state.addMessage(ChatMessage(role: .user, content: "old"))
        state.updateLastMessage("new")
        XCTAssertEqual(state.messages.first?.content, "new")
    }

    @MainActor
    func testChatState_clear() {
        let state = ChatState()
        state.addMessage(ChatMessage(role: .user, content: "test"))
        state.isSending = true
        state.clear()
        XCTAssertTrue(state.messages.isEmpty)
        XCTAssertFalse(state.isSending)
    }

    @MainActor
    func testChatState_updateLastMessage_emptyMessages() {
        let state = ChatState()
        state.updateLastMessage("new")
        XCTAssertTrue(state.messages.isEmpty)
    }
}

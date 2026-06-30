//
//  AIChatScrollCoordinatorViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Coordinates automatic scroll behavior in the AI chat interface.
@MainActor
final class AIChatScrollCoordinatorViewModel: ObservableObject {
    private var lastContentLength: Int = 0
    private var scrollTask: Task<Void, Never>?
    private var periodicScrollTask: Task<Void, Never>?

    /// Handles changes to the last message content length.
    func onLastMessageChanged(contentLength: Int, scrollToBottom: @escaping @MainActor () -> Void) {
        lastContentLength = contentLength
        scheduleScroll(scrollToBottom: scrollToBottom)
    }

    /// Handles changes to the message count.
    func onMessagesCountChanged(hasLastMessage: Bool, scrollToBottom: @escaping @MainActor () -> Void) {
        guard hasLastMessage else { return }
        scheduleScroll(scrollToBottom: scrollToBottom)
    }

    /// Handles transitions between sending and idle states.
    func onSendingChanged(
        wasSending: Bool,
        isSending: Bool,
        scrollToBottom: @escaping @MainActor () -> Void,
        getLastMessageContentLength: @escaping @MainActor () -> Int?,
    ) {
        if !wasSending, isSending {
            startPeriodicScrollCheck(
                scrollToBottom: scrollToBottom,
                getLastMessageContentLength: getLastMessageContentLength,
            ) {
                isSending
            }
        } else if wasSending, !isSending {
            stopPeriodicScrollCheck()
            scheduleScroll(scrollToBottom: scrollToBottom)
        }
    }

    /// Starts periodic scroll checking if currently sending.
    func onAppearIfSending(
        isSending: Bool,
        scrollToBottom: @escaping @MainActor () -> Void,
        getLastMessageContentLength: @escaping @MainActor () -> Int?,
    ) {
        guard isSending else { return }
        startPeriodicScrollCheck(
            scrollToBottom: scrollToBottom,
            getLastMessageContentLength: getLastMessageContentLength,
        ) {
            isSending
        }
    }

    /// Stops all scroll tasks when the view disappears.
    func onDisappear() {
        stopPeriodicScrollCheck()
        scrollTask?.cancel()
        scrollTask = nil
    }

    private func scheduleScroll(scrollToBottom: @escaping @MainActor () -> Void) {
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s throttle
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
            guard !Task.isCancelled else { return }
            scrollToBottom()
        }
    }

    private func startPeriodicScrollCheck(
        scrollToBottom: @escaping @MainActor () -> Void,
        getLastMessageContentLength: @escaping @MainActor () -> Int?,
        isSending: @escaping @MainActor () -> Bool,
    ) {
        stopPeriodicScrollCheck()
        periodicScrollTask = Task { @MainActor in
            while !Task.isCancelled, isSending() {
                if let currentLength = getLastMessageContentLength(),
                   currentLength > lastContentLength {
                    lastContentLength = currentLength
                    scrollToBottom()
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func stopPeriodicScrollCheck() {
        periodicScrollTask?.cancel()
        periodicScrollTask = nil
    }
}

//
//  AtomicCounter.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A thread-safe counter backed by an actor, suitable for concurrent progress tracking.
actor AtomicCounter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }

    func reset() {
        value = 0
    }
}

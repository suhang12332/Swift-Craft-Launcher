//
//  LazyContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

// MARK: - @Lazy

/// Thread-safe lazy property wrapper. Creates the value on first access, then caches it.
///
/// Usage: `@Lazy var foo: Foo = Foo()`
/// The `= Foo()` part is an autoclosure — evaluated only on first access.
@propertyWrapper
final class Lazy<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var instance: T?
    private let factory: () -> T

    init(wrappedValue: @autoclosure @escaping () -> T) {
        self.factory = wrappedValue
    }

    var wrappedValue: T {
        lock.lock()
        defer { lock.unlock() }
        if let instance { return instance }
        let created = factory()
        instance = created
        return created
    }

    var projectedValue: Lazy<T> { self }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        instance = nil
    }
}

// MARK: - @MainActorLazy

/// Main-actor-isolated lazy property wrapper. Value created on first access on the main actor.
///
/// Usage: `@MainActorLazy var manager: Manager = Manager()`
/// The property becomes implicitly `@MainActor`.
@propertyWrapper
final class MainActorLazy<T> {
    private let factory: @MainActor () -> T
    private var storage: T?

    init(wrappedValue: @MainActor @autoclosure @escaping () -> T) {
        self.factory = wrappedValue
    }

    @MainActor var wrappedValue: T {
        if let storage { return storage }
        let v = factory()
        storage = v
        return v
    }

    var projectedValue: MainActorLazy<T> { self }
}

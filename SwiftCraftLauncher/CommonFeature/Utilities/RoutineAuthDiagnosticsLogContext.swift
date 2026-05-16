import Foundation

enum RoutineAuthDiagnosticsLogContext {
    @TaskLocal static var suppressRoutineDebugLogs = false

    static var shouldSuppressRoutineDebugLogs: Bool {
        suppressRoutineDebugLogs
    }

    static func withSuppressedRoutineDebugLogs<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await $suppressRoutineDebugLogs.withValue(true, operation: operation)
    }
}

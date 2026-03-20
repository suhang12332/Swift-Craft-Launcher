import Foundation

extension GameAdvancedSettingsViewModel {
    func parseExistingJvmArguments(_ arguments: String) -> Bool {
        let args = arguments.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        let gcMap: [(String, GarbageCollector)] = [
            ("-XX:+UseG1GC", .g1gc),
            ("-XX:+UseZGC", .zgc),
            ("-XX:+UseShenandoahGC", .shenandoah),
            ("-XX:+UseParallelGC", .parallel),
            ("-XX:+UseSerialGC", .serial),
        ]

        guard let (_, gc) = gcMap.first(where: { args.contains($0.0) }) else {
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
            return false
        }

        if gc.isSupported(by: currentJavaVersion) {
            selectedGarbageCollector = gc
        } else {
            Logger.shared.warning("检测到不兼容的垃圾回收器 \(gc.displayName)（需要 Java \(gc.minimumJavaVersion)+，当前 Java \(currentJavaVersion)），自动切换到兼容选项")
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
            return false
        }

        enableOptimizations = args.contains("-XX:+OptimizeStringConcat") ||
            args.contains("-XX:+OmitStackTraceInFastThrow")
        enableMemoryOptimizations = args.contains("-XX:+UseCompressedOops") ||
            args.contains("-XX:+UseCompressedClassPointers") ||
            args.contains("-XX:+UseCompactObjectHeaders")
        enableThreadOptimizations = args.contains("-XX:+OmitStackTraceInFastThrow")

        if selectedGarbageCollector == .g1gc {
            enableAikarFlags = args.contains("-XX:+ParallelRefProcEnabled") &&
                args.contains("-XX:MaxGCPauseMillis=200") &&
                args.contains("-XX:+AlwaysPreTouch")
        } else {
            enableAikarFlags = false
        }

        enableNetworkOptimizations = args.contains("-Djava.net.preferIPv4Stack=true")
        updateOptimizationPreset()

        if optimizationPreset == .maximum && selectedGarbageCollector != .g1gc {
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        }
        return true
    }

    func applyOptimizationPreset(_ preset: OptimizationPreset) {
        switch preset {
        case .disabled:
            enableOptimizations = false
            enableAikarFlags = false
            enableMemoryOptimizations = false
            enableThreadOptimizations = false
            enableNetworkOptimizations = false

        case .basic, .balanced:
            enableOptimizations = true
            enableAikarFlags = false
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = false

        case .maximum:
            enableOptimizations = true
            enableAikarFlags = true
            enableMemoryOptimizations = true
            enableThreadOptimizations = true
            enableNetworkOptimizations = true
        }
    }

    func updateOptimizationPreset() {
        if !enableOptimizations {
            optimizationPreset = .disabled
        } else if enableAikarFlags && enableNetworkOptimizations {
            optimizationPreset = .maximum
        } else if enableMemoryOptimizations && enableThreadOptimizations {
            optimizationPreset = .balanced
        } else {
            optimizationPreset = .basic
        }
    }

    func generateJvmArguments() -> String {
        let trimmed = customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return customJvmArguments
        }

        let gc = selectedGarbageCollector.isSupported(by: currentJavaVersion)
            ? selectedGarbageCollector
            : (availableGarbageCollectors.first ?? .g1gc)

        var arguments: [String] = []
        arguments.append(contentsOf: gc.arguments)

        if gc == .g1gc {
            arguments.append(contentsOf: [
                "-XX:+ParallelRefProcEnabled",
                "-XX:MaxGCPauseMillis=200",
            ])

            if enableAikarFlags {
                arguments.append(contentsOf: [
                    "-XX:+UnlockExperimentalVMOptions",
                    "-XX:+DisableExplicitGC",
                    "-XX:+AlwaysPreTouch",
                    "-XX:G1NewSizePercent=30",
                    "-XX:G1MaxNewSizePercent=40",
                    "-XX:G1HeapRegionSize=8M",
                    "-XX:G1ReservePercent=20",
                    "-XX:G1HeapWastePercent=5",
                    "-XX:G1MixedGCCountTarget=4",
                    "-XX:InitiatingHeapOccupancyPercent=15",
                    "-XX:G1MixedGCLiveThresholdPercent=90",
                    "-XX:G1RSetUpdatingPauseTimePercent=5",
                    "-XX:SurvivorRatio=32",
                    "-XX:MaxTenuringThreshold=1",
                ])
            }
        }

        if enableOptimizations {
            arguments.append(contentsOf: [
                "-XX:+OptimizeStringConcat",
                "-XX:+OmitStackTraceInFastThrow",
            ])
        }

        if enableMemoryOptimizations {
            if currentJavaVersion < 15 {
                arguments.append("-XX:+UseCompressedOops")
            } else if currentJavaVersion < 25 {
                arguments.append(contentsOf: [
                    "-XX:+UseCompressedOops",
                    "-XX:+UseCompressedClassPointers",
                ])
            } else {
                arguments.append(contentsOf: [
                    "-XX:+UseCompressedOops",
                    "-XX:+UseCompressedClassPointers",
                    "-XX:+UseCompactObjectHeaders",
                ])
            }
        }

        if enableNetworkOptimizations {
            arguments.append("-Djava.net.preferIPv4Stack=true")
        }

        return arguments.joined(separator: " ")
    }
}

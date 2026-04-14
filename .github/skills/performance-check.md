# Skill: Performance Analysis

## Detect

- Blocking IO
- Large memory allocations
- Inefficient loops
- Unbounded caches
- Heavy work in SwiftUI `body` / frequent recomputation

## Rules

- Prefer async when possible
- Avoid repeated computation
- Cache where appropriate
- Avoid doing file/network work on the main thread
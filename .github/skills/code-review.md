# Skill: Code Review

## Focus

- Clean code principles
- SOLID design
- Maintainability
- SwiftUI readability (small views, extracted subviews, clear data flow)

## Rules

- Avoid deep nesting (>3 levels)
- Prefer small functions
- Avoid magic numbers
- Enforce consistent style
- Prefer `guard` for early exits and clarity
- Avoid `try!` / forced unwraps unless justified
- Keep UI work on main thread; annotate with `@MainActor` when appropriate

## Anti-patterns

- God object
- Spaghetti code
- Duplicate logic
- Large SwiftUI `body` with business logic embedded
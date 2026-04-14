# Skill: Security Analysis

## Detect

- Hardcoded API keys
- Insecure HTTP usage
- Weak cryptography
- Sensitive data logging (tokens, auth codes, PII)
- Insecure token storage patterns

## Rules

- Always validate input
- Prefer Keychain for secrets/tokens on Apple platforms
- Avoid printing secrets to logs (including in CI)
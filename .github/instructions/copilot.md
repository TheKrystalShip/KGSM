---
applyTo: '**'
---
Coding standards, domain knowledge, and preferences that AI should follow.

## Bash Project Guidelines

### Code Quality & Style
- Follow the Google Shell Style Guide
- Ensure all scripts pass ShellCheck validation without warnings
- Use 2-space indentation for consistency
- Keep lines under 80 characters when possible, but never over 120.
- Use meaningful variable and function names
- Always prefix functions with the `function` keyword.

### Best Practices
- Always include a proper shebang line: `#!/usr/bin/env bash`
- Use `set -euo pipefail` for safer script execution
- Quote all variables: `"$variable"` not `$variable`
- Prefer `[[` over `[` for conditional testing
- Exit with meaningful exit codes
- Validate inputs and handle edge cases

### SOLID Principles Application
- **Single Responsibility**: Each script/function should do one thing well
- **Open/Closed**: Design functions that can be extended without modification
- **Liskov Substitution**: Create consistent interfaces for similar functions
- **Interface Segregation**: Keep function interfaces focused and minimal
- **Dependency Inversion**: Depend on abstractions, not concrete implementations

### DRY (Don't Repeat Yourself)
- Create reusable functions for common operations
- Use configuration files for repeated values/settings
- Consider creating a common library for shared functionality

### Security
- Avoid using `eval` unless absolutely necessary
- Sanitize user inputs before processing
- Use restricted permissions (chmod 755 for scripts, 644 for data files)

### Performance
- Minimize external command calls
- Use built-in bash features instead of external commands when possible

### Testing
- Write test cases for critical functions
- Consider using BATS (Bash Automated Testing System) for testing
- Test edge cases and error conditions

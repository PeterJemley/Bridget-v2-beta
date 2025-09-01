# Git Hooks Setup for Bridget

This project uses git hooks to enforce code style and formatting standards.

## Setup

The git hooks are already configured and will run automatically on every commit.

## What the Hooks Do

### Pre-commit Hook (`.git/hooks/pre-commit`)

1. **SwiftFormat**: Auto-formats code according to `.swiftformat` rules
2. **SwiftLint**: Checks for style violations according to `.swiftlint.yml` rules
3. **Auto-fix**: Automatically fixes minor issues and re-stages files
4. **Blocking**: Prevents commits if critical errors are found

## Configuration Files

### `.swiftformat`
- Configures automatic code formatting
- Aligns with project's 200 LOC guideline
- Handles indentation, spacing, and import organization

### `.swiftlint.yml`
- **Error-level rules**: Block commits (force_cast, force_try, unused_import, etc.)
- **Warning-level rules**: Show but allow commits (style preferences)
- **Custom rules**: Enforce @Observable usage and file headers

## How It Works

1. When you commit, the pre-commit hook runs automatically
2. SwiftFormat formats your code and re-stages changes
3. SwiftLint checks for style violations
4. If SwiftLint finds errors, the commit is blocked
5. If only warnings are found, the commit proceeds

## Manual Usage

You can run the tools manually:

```bash
# Format code
swift run --package-path . swiftformat Bridget/ --config .swiftformat

# Lint code
swift run --package-path . swiftlint lint Bridget/ --config .swiftlint.yml

# Auto-fix linting issues
swift run --package-path . swiftlint lint Bridget/ --config .swiftlint.yml --fix
```

## Troubleshooting

If the hooks aren't working:

1. **Check permissions**: `chmod +x .git/hooks/pre-commit`
2. **Install dependencies**: `swift package resolve`
3. **Test manually**: Run the commands above manually

## Dependencies

The hooks use Swift Package Manager to manage SwiftLint and SwiftFormat versions:
- SwiftLint: `0.50.0+`
- SwiftFormat: `0.51.0+`

These are locked in `Package.swift` to ensure consistent tool versions across the team. 
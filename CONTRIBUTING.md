# Contributing

## Development Setup

Requirements:

- macOS 12 or later
- Node.js 18 or later
- Xcode or Xcode Command Line Tools

Run the complete local verification:

```bash
node --test tests/*.test.js
./build.sh --clean
./build.sh --dmg
codesign --verify --deep --strict build/CodexStatusBar.app
```

## Pull Requests

Keep changes focused and include tests for hook or installer behavior. Confirm that unrelated Codex hooks and `config.toml` settings survive install and uninstall. Include screenshots for visible interface changes.

Use clear commit messages and explain the user impact, validation performed, and any remaining distribution limitations in the pull request.

## Project Structure

- `Sources/CodexStatusBar/`: native AppKit menu-bar application
- `hooks/`: Codex lifecycle hook, notifier, installer, and uninstaller
- `tests/`: Node.js hook integration tests
- `build.sh`: app and DMG packaging

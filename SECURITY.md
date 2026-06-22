# Security Policy

## Supported Versions

Security fixes are provided for the latest release.

## Reporting A Vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's **Report a vulnerability** feature in the repository Security tab and include reproduction steps, affected versions, and expected impact.

Please allow a reasonable investigation period before public disclosure.

## Security Model

Codex Status Bar runs locally and does not make network requests. It copies its hook scripts to `~/.codex/statusbar/hooks`, writes status to a user-only state file, and modifies only its own marked entries in Codex configuration. Users must review and trust hook commands in Codex before execution.

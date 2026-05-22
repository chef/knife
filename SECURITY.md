# Security Policy

## Reporting a Vulnerability

See https://chef.io/security for our security policy and how to report a vulnerability.

## Secret Scanning

This repository uses [Gitleaks](https://github.com/gitleaks/gitleaks) for automated secret detection.

### How it runs

A CI job (`.github/workflows/secret-scan.yml`) runs Gitleaks on every push to `main` and every pull request using `gitleaks/gitleaks-action@v2`. Full git history is scanned to catch secrets in any commit, not just the latest diff.

### Configuration

Allowlist rules are defined in `.gitleaks.toml` at the repository root.

### Justified ignores

The following paths are excluded from scanning because they contain **intentional test fixtures**, not real secrets:

| Path | Reason |
|------|--------|
| `spec/` | RSpec test files use placeholder credentials (fake passwords, PEM blobs, API keys) by design. No real secret material. |
| `chef-server/chef-keys/` | Development-only key pair used for local Chef Server setup in Vagrant/Docker. Not used in production. |

### Adding new exclusions

If Gitleaks flags a false positive:
1. Verify the finding is genuinely safe (not an accidentally committed secret).
2. Add a path or regex rule to `.gitleaks.toml` with a comment explaining the justification.
3. Include the change in the same PR that introduces the allowlisted pattern.

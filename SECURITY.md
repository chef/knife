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

## Local Development (Pre-commit Hook)

A [pre-commit](https://pre-commit.com) configuration (`.pre-commit-config.yaml`) is
provided so developers can catch secrets **before pushing**, not just in CI.

### Setup

```bash
# Install the pre-commit tool (once, system-wide)
pip install pre-commit

# Install the hooks into your local git clone (once per clone)
pre-commit install

# Run manually against all files at any time
pre-commit run --all-files
```

The hook uses the same Gitleaks version and `.gitleaks.toml` allowlist as CI,
so local and remote scans produce consistent results.

### What the hook scans

On every `git commit`, Gitleaks scans the **staged changes** only (fast).
The CI job scans full history (thorough). Together they provide:

| Layer | When | Scope |
|-------|------|-------|
| Pre-commit hook | `git commit` | Staged diff |
| CI secret-scan job | PR / push to main | Full git history |

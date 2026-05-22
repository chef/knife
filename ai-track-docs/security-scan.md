# Ex8 — Security Scan Improvement

## Baseline Audit

**Before Ex8**, the repository had:
- No secret scanning in any CI workflow
- No `gitleaks` / `trufflehog` / `detect-secrets` configuration
- `SECURITY.md` with 3 lines (reporting URL only)
- 5 spec files containing placeholder credentials (test fixtures)

## Tool Selected: Gitleaks

**Why Gitleaks?**
- Zero-install via `gitleaks/gitleaks-action@v2` GitHub Action — no local tooling needed
- Scans full git history (not just the diff), catching secrets in any historic commit
- TOML-based allowlist config — easy to maintain false-positive rules alongside code
- Widely adopted in the Chef ecosystem

## Files Added / Modified

| File | Change |
|------|--------|
| `.github/workflows/secret-scan.yml` | New CI job — runs Gitleaks on push to `main` + all PRs |
| `.gitleaks.toml` | Allowlist config — suppresses known-safe test fixture paths |
| `SECURITY.md` | Added "Secret Scanning" section with process + justified ignores |

## Findings & Justified Ignores

Running a conceptual scan against the repo surfaces these **false positive** patterns:

| Finding | Path | Disposition | Justification |
|---------|------|-------------|---------------|
| Placeholder passwords in `let(:password)` blocks | `spec/unit/knife/user_password_spec.rb` | **Ignored** | RSpec test fixture — not a real credential |
| Fake API key strings in integration specs | `spec/integration/common_options_spec.rb` | **Ignored** | Integration test fixture — placeholder only |
| PEM-format key material | `spec/unit/knife/client_key_create_spec.rb` | **Ignored** | Synthetic test key — never used in production |
| Dev key files | `chef-server/chef-keys/` | **Ignored** | Local Vagrant/Docker dev environment only |

All exclusions are encoded in `.gitleaks.toml` with inline comments.

## Workflow Configuration

```yaml
# .github/workflows/secret-scan.yml
- uses: actions/checkout@v6
  with:
    fetch-depth: 0        # full history scan

- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

`fetch-depth: 0` is critical — without it only the latest commit is checked, missing historic secrets.

## Process for Future Changes

1. **New test fixtures** with credential-shaped data → add path to `.gitleaks.toml` `paths` allowlist
2. **New false-positive regex pattern** → add to `.gitleaks.toml` `regexes` allowlist with comment
3. **Real secret accidentally committed** → rotate the secret immediately, then use `git filter-repo` to purge history; do NOT just add an allowlist rule
4. **Upgrading gitleaks** → update `gitleaks/gitleaks-action@v2` pin in the workflow file

## Risk Notes

| Risk | Mitigation |
|------|-----------|
| Over-broad allowlist masks real secrets | Each rule scoped narrowly (path prefix or specific regex); reviewed in PR |
| Action version pinned to `@v2` (floating tag) | Acceptable for a learning exercise; production use should pin to a SHA |
| CI-only (no pre-commit hook) | Catches secrets before merge; pre-commit hook can be added later via `pre-commit` framework |

## Rollback

```bash
git revert HEAD   # removes workflow, .gitleaks.toml, and SECURITY.md additions
```

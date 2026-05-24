# Security Hygiene — Run Ex8

## Scan Methodology

Manual review of `lib/chef/knife/` focused on three common classes:
1. File creation permissions for sensitive material
2. Shell injection via `exec()` with string arguments
3. No secrets scanner needed — `gitleaks` CI job (Walk Ex8) already covers secret detection

---

## Finding 1 — Private key / PEM files created without restricted permissions

### Risk
`File.open(path, "w")` creates a file with permissions derived from the process umask.
On a default Linux system (umask `022`) this yields mode `0644` — **world-readable**.
A private key or PEM file at `0644` can be read by any local user on the same machine.

### Affected files (8)

| File | Writes |
|------|--------|
| `lib/chef/knife/key_create.rb:67` | Actor private key |
| `lib/chef/knife/key_edit.rb:69` | Actor private key |
| `lib/chef/knife/org_create.rb:53` | Org private key |
| `lib/chef/knife/user_create.rb:156` | User private key |
| `lib/chef/knife/user_reregister.rb:50` | User private key |
| `lib/chef/knife/client_reregister.rb:49` | Client private key |
| `lib/chef/knife/client_create.rb:97` | Client private key |
| `lib/chef/knife/configure_client.rb:41` | `validation.pem` |

### Fix
```ruby
# BEFORE
File.open(path, "w") { |f| f.print(key) }

# AFTER
File.open(path, "w", 0600) { |f| f.print(key) }
```
`0600` = owner read/write only. Applies at file creation time regardless of umask.

### Scripted verification
```bash
# After knife key create --file /tmp/test.pem ...
stat -c "%a" /tmp/test.pem  # should print 600
```

### Rollback
```bash
git revert HEAD -- lib/chef/knife/key_create.rb \
  lib/chef/knife/key_edit.rb lib/chef/knife/org_create.rb \
  lib/chef/knife/user_create.rb lib/chef/knife/user_reregister.rb \
  lib/chef/knife/client_reregister.rb lib/chef/knife/client_create.rb \
  lib/chef/knife/configure_client.rb
```

---

## Finding 2 — `exec(cssh_cmd)` shell-string injection (ssh.rb:575)

### Risk
`cssh_cmd` is built from `server.user` and `server.host` via string concatenation,
then passed as a **single string** to `exec()`. When `exec` receives a string, Ruby
invokes the shell (`/bin/sh -c`), which processes metacharacters (`; | & $() ...`).
If a hostname or username contains shell metacharacters, arbitrary commands could execute.

### Fix
```ruby
# BEFORE — passes through shell
exec(cssh_cmd)

# AFTER — bypasses shell; each token is a separate argv element
exec(*cssh_args)   # cssh_args is built as an Array
```

`exec` with multiple arguments (or a single-element array splatted) does **not** invoke
the shell — arguments are passed directly to the OS as `execvp(3)` entries.

### Rollback
```bash
git revert HEAD -- lib/chef/knife/ssh.rb
```

---

## Regression Evidence

```
bundle exec rspec spec/unit/

1421 examples, 0 failures, 2 pending
```

All existing specs updated to assert the new `0600` mode argument, confirming
the permission change is validated in the test suite.

---

## Update Process for Future Security Reviews

1. **File creation**: Any `File.open(path, "w")` that writes key material, tokens,
   or PEM content should include mode `0600` as the third argument.
2. **Shell injection**: Prefer array form of `system()`, `exec()`, and `Open3.popen*`
   over string interpolation. Use `Shellwords.escape` if string form is unavoidable.
3. **Secret scanning**: Gitleaks CI job (`.github/workflows/secret-scan.yml`) scans
   every PR — do not add real credentials to any file tracked by git.
4. Run `bundle exec rspec spec/unit/` after any security change to catch mock mismatches.

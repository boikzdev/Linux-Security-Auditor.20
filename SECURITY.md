# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark:  |

## Reporting a Vulnerability

If you find a security vulnerability in Linux Security Auditor itself
(not a finding it reports about *your* system, but a flaw in the tool),
please **do not open a public GitHub issue**. Instead:

1. Open a [GitHub Security Advisory](../../security/advisories/new) on
   this repository, or email the maintainer directly if that's not
   available to you.
2. Include a description of the issue, the version affected, and, if
   possible, steps to reproduce it.
3. You can expect an initial response within 5 business days.

We'll credit reporters (unless you'd prefer to stay anonymous) once a
fix has shipped.

## What Counts as a Vulnerability Here

Examples of things we want to hear about:

- A way for `linux-audit scan` to be tricked into modifying the system
  without the `--apply` flag *and* explicit confirmation.
- A code path where user-controlled input (a config file, a filename,
  a log line) reaches a shell or `subprocess` call unsafely.
- A finding that silently swallows an exception in a way that could
  mask a real, severe misconfiguration (false negative).
- Secrets, credentials, or full file contents (e.g. `/etc/shadow`)
  leaking into logs or reports.

Things that are expected behavior, not vulnerabilities:

- The tool needing root privileges to read `/etc/shadow` or full
  `journalctl` output. Findings that say "requires elevated
  privileges" are working as intended.
- False positives/negatives in individual findings - please file these
  as regular bug reports instead, they're valuable but not security
  issues in the tool itself.

## Design Principles That Back This Policy

- **No destructive automatic action.** `hardening.py` never mutates
  the system unless `--apply` is passed *and* each individual fix is
  interactively confirmed.
- **No secrets ever leave the host.** Nothing in this project makes a
  network call with system data; all reporting is local files.
- **All subprocess calls go through one audited helper**
  (`auditor.utils.shell.run_command`), which never uses `shell=True`
  and always applies a timeout.

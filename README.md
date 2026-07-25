# Linux Security Auditor

[![CI](https://github.com/boikzdev/linux-security-auditor/actions/workflows/security.yml/badge.svg)](https://github.com/boikzdev/linux-security-auditor/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.11+](https://img.shields.io/badge/python-3.11%2B-blue)](pyproject.toml)

A lightweight, dependency-thin Linux security auditing and hardening
toolkit. It audits a host's configuration, users, network exposure,
filesystem permissions, and authentication logs; produces a terminal,
JSON, or Markdown report; and offers hardening recommendations that are
**never applied automatically** without your explicit confirmation.

Built for Linux administrators, DevOps/security engineers, SOC
analysts, and anyone learning practical DevSecOps.

## Contents

- [Features](#features)
- [What it looks like](#what-it-looks-like)
- [Installation](#installation)
- [Usage](#usage)
- [Docker](#docker)
- [Architecture](#architecture)
- [Testing](#testing)
- [Security disclaimer](#security-disclaimer)
- [Contributing](#contributing)

## Features

- **System audit** - OS/kernel identification, running services,
  firewall status (ufw/firewalld/nftables/iptables), SSH daemon
  configuration (including modern `sshd_config.d/*.conf` drop-ins),
  pending package updates.
- **User audit** - non-root UID 0 accounts, sensitive file permissions
  (`/etc/shadow`, `/etc/sudoers`, ...), empty password hashes (when
  readable), risky `NOPASSWD: ALL` sudoers entries.
- **Network audit** - listening sockets exposed on all interfaces,
  known high-risk services (telnet, FTP, Redis, MongoDB, etc.), and an
  *optional* `nmap` service-version cross-check that's skipped
  gracefully if `nmap` isn't installed.
- **Filesystem permission audit** - world-writable files and
  SUID/SGID binaries outside an expected allowlist, both scoped and
  time-boxed so they can't hang on a large filesystem.
- **Log analysis** - failed logins, brute-force pattern detection,
  privilege-escalation attempts, with a `journalctl` fallback when
  `auth.log`/`secure` don't exist; `fail2ban` presence check.
- **Hardening recommendations** - every finding maps to an actionable
  fix. A small, explicitly curated subset of safe, reversible fixes can
  be applied with `--apply`, but only after per-fix interactive
  confirmation - nothing changes silently.
- **Three report formats** - a `rich` terminal report, timestamped
  JSON, and timestamped Markdown, all from the same underlying data.
- **Named profiles** - `--profile server|workstation|cloud|quick` to
  run a curated check set instead of listing flags every time.
- **Runs without root**, with checks that need elevated privileges
  degrading to a clear `INFO` finding instead of crashing.

## What it looks like

```
──────────────────────────── Linux Security Auditor ────────────────────────────
Host: web-01   Platform: Linux-6.8.0-generic-x86_64-with-glibc2.39
Generated: 2026-07-18T12:00:00+00:00
Risk score: 83/100

                                    Findings
┏━━━━━━━━━━┳━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Severity ┃ Category    ┃ Issue                    ┃ Recommendation           ┃
┡━━━━━━━━━━╇━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ HIGH     │ firewall    │ No active host firewall  │ Enable a host firewall   │
│          │             │ detected                 │ and default-deny inbound │
│ MEDIUM   │ permissions │ 1 world-writable file(s) │ Remove world-write       │
│          │             │ found under /etc, ...    │ permission               │
│ LOW      │ logs        │ fail2ban is not installed│ Consider installing it   │
└──────────┴─────────────┴──────────────────────────┴──────────────────────────┘

Summary -> HIGH: 1  MEDIUM: 1  LOW: 1
json report written: reports/security_report_20260718_120000.json
markdown report written: reports/security_report_20260718_120000.md
```
*(Real output from a `--full --format all` run; colors don't render in Markdown.)*

## Installation

Requires Python 3.11+ on a Linux host (Ubuntu 22.04+, Debian, Kali,
WSL2 all supported).

```bash
git clone https://github.com/boikzdev/linux-security-auditor.git
cd linux-security-auditor
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

This installs the `linux-audit` command via a console-script entry
point. Verify it:

```bash
linux-audit --version
```

For development (linting, tests, security scanning), install the dev
extras instead:

```bash
pip install -e ".[dev]"
```

### Optional external tools

These enhance specific checks but are **not required** - every check
degrades gracefully if a tool is missing:

| Tool | Used by | Effect if missing |
|---|---|---|
| `nmap` | network audit | Service-version fingerprinting skipped; port listing still works via `psutil`/`ss` |
| `fail2ban-client` | log analysis | Reported as "not installed" (a `LOW` finding) instead of checked |
| `ufw` / `firewall-cmd` / `nft` / `iptables` | system audit | Firewall status check tries each in turn; reports "none" if none are present |

## Usage

```bash
linux-audit scan --full                          # everything, terminal report
linux-audit scan --system --network              # just these two checks
linux-audit scan --profile workstation           # a named check set
linux-audit scan --full --format all             # terminal + JSON + Markdown
linux-audit scan --full --hardening              # + remediation detail
linux-audit scan --full --hardening --apply       # + confirm-then-apply safe fixes
```

See [`docs/USAGE.md`](docs/USAGE.md) for the full flag reference and
[`docs/HARDENING.md`](docs/HARDENING.md) for manual remediation steps
per finding.

## Docker

```bash
docker build -t linux-security-auditor .
docker run --rm linux-security-auditor scan --full
```

Or with `docker compose` (writes reports to `./reports` on the host):

```bash
docker compose up auditor
```

By default this audits the **container's own** filesystem and network
namespace, not your host. There's an optional, more invasive
`auditor-host` profile for auditing the actual host - read the caveat
comment in [`docker-compose.yml`](docker-compose.yml) before using it;
for a fully accurate host audit, installing natively with `pip` and
running `linux-audit` directly on that host is the recommended path.

## Architecture

```
CLI (argparse + rich) -> main.run_audit (orchestrator)
   -> system_audit / user_audit / network_audit / permission_audit / log_analysis
   -> hardening engine (recommendations; --apply is confirmation-gated)
   -> report_generator (terminal / JSON / Markdown)
```

Full breakdown, module responsibilities, and design principles in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

```
linux-security-auditor/
├── src/auditor/
│   ├── main.py, cli.py
│   ├── modules/        # system_audit, user_audit, network_audit,
│   │                    permission_audit, log_analysis, hardening
│   ├── reporting/       # report_generator (terminal/JSON/Markdown)
│   └── utils/           # findings model, config, logger, shell, netinfo
├── tests/                # 89 tests, mocked subprocess/filesystem, no root needed
├── configs/              # audit_profiles.yaml, security_standards.yaml
├── docs/                 # ARCHITECTURE, USAGE, HARDENING, TROUBLESHOOTING
├── .github/workflows/    # CI: ruff, bandit, pip-audit, pytest, docker build
├── Dockerfile, docker-compose.yml
└── pyproject.toml
```

## Testing

```bash
pip install -e ".[dev]"
pytest tests/ --cov=auditor --cov-report=term-missing
```

89 tests, ~83% coverage, no root privileges or real system mutation
required - external commands and privileged filesystem access are
mocked so the suite is deterministic in CI. The same commands CI runs:

```bash
ruff check src/ tests/     # lint
bandit -r src/             # static security analysis
pip-audit -r requirements.txt   # dependency vulnerability scan
pytest tests/ --cov=auditor
```

## Security disclaimer

This tool reports on security posture; it does not guarantee security.
A clean report is not a certification, and a high risk score does not
mean a system is definitely compromised - always apply human judgment
and follow your organization's change-management process before acting
on any finding, especially with `--apply`. See [`SECURITY.md`](SECURITY.md)
for the project's own security policy and design guarantees (no
destructive automatic action, no data leaves the host, all subprocess
calls are argv-only and time-boxed).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the dev setup, module
contract, and required pre-PR checks.

## License

[MIT](LICENSE)

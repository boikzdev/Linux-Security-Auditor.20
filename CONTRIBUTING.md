# Contributing to Linux Security Auditor

Thanks for considering a contribution. This is a portfolio-grade but
genuinely functional project, so contributions are held to a
production bar, not a demo one.

## Getting set up

```bash
git clone https://github.com/boikzdev/linux-security-auditor.git
cd linux-security-auditor
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Before opening a PR

Run all of these locally - CI runs the same checks and will fail the
build otherwise:

```bash
ruff check src/ tests/
bandit -r src/
pip-audit -r requirements.txt
pytest tests/ --cov=auditor --cov-report=term-missing
```

## Adding a new audit module

Every module under `src/auditor/modules/` follows the same contract:

```python
def run(config: AuditorConfig) -> ModuleResult:
    ...
```

`ModuleResult` has two fields: `facts` (a plain dict of whatever raw
data you gathered - shown in JSON reports and available for future
checks) and `findings` (a list of `Finding` objects).

Guidelines:

- **Never crash the whole audit.** Wrap anything that touches the
  filesystem, a subprocess, or a privileged file in error handling.
  Missing permissions or missing tools should degrade to an `INFO`
  finding, not an exception.
- **Route every external command through `auditor.utils.shell.run_command`.**
  Never call `subprocess` directly - `run_command` enforces "argv list,
  never `shell=True`, always time-boxed."
- **No destructive actions.** If your check suggests a fix, it belongs
  in `hardening.py`'s recommendation text, not executed automatically.
  If a fix is genuinely safe, reversible, and worth auto-applying, add
  it to hardening's `_SAFE_FIX_REGISTRY` - but it must still go through
  the interactive confirmation flow.
- **Write tests that don't depend on the real host.** Monkeypatch
  `run_command`, `is_available`, and filesystem paths so tests are
  deterministic in CI (see `tests/test_system_audit.py` for examples).

## Code style

- Ruff is the source of truth for style/lint (`ruff check`). Don't
  hand-format around it.
- Type hints are expected on new public functions.
- Keep dependencies minimal - this project deliberately avoids heavy
  frameworks. If you think a new dependency is worth it, explain why
  in the PR description.

## Reporting bugs / requesting features

Please open a GitHub issue with:

- What you ran (`linux-audit scan --...`)
- What you expected vs. what happened
- Your distro and Python version (`python3 --version`)

Security vulnerabilities should go through [SECURITY.md](SECURITY.md)
instead of a public issue.

.PHONY: install install-dev lint security test test-cov scan docker docker-run clean

install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"

lint:
	ruff check src/ tests/

security:
	bandit -r src/
	pip-audit -r requirements.txt

test:
	pytest tests/

test-cov:
	pytest tests/ --cov=auditor --cov-report=term-missing

scan:
	linux-audit scan --full --format all --hardening

docker:
	docker build -t linux-security-auditor .

docker-run:
	docker run --rm linux-security-auditor scan --full

clean:
	rm -rf .pytest_cache .ruff_cache .coverage coverage.xml build dist *.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} +

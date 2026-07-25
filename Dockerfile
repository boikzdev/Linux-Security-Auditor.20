# syntax=docker/dockerfile:1

########################
# Build stage
########################
FROM python:3.12-slim AS builder

WORKDIR /build

# Only copy what's needed to resolve dependencies + build the wheel,
# so dependency layers cache independently of application code changes.
COPY pyproject.toml requirements.txt README.md LICENSE ./
COPY src/ src/

RUN pip install --no-cache-dir --upgrade pip build && \
    python -m build --wheel --outdir /build/dist

########################
# Runtime stage
########################
FROM python:3.12-slim AS runtime

LABEL org.opencontainers.image.title="linux-security-auditor" \
      org.opencontainers.image.description="Lightweight Linux security auditing and hardening toolkit" \
      org.opencontainers.image.source="https://github.com/boikzdev/linux-security-auditor" \
      org.opencontainers.image.licenses="MIT"

# Runtime tool integrations are optional-by-design (the auditor degrades
# gracefully without them), but installing the common ones keeps the
# default container experience complete out of the box.
RUN apt-get update && apt-get install -y --no-install-recommends \
        procps \
        iproute2 \
        nmap \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 auditor && \
    useradd --uid 1000 --gid auditor --create-home --shell /usr/sbin/nologin auditor

COPY --from=builder /build/dist/*.whl /tmp/
RUN pip install --no-cache-dir /tmp/*.whl && rm -rf /tmp/*.whl

# Reports and diagnostic logs are written here at runtime; owned by the
# unprivileged user the container actually runs as.
RUN mkdir -p /home/auditor/reports && chown -R auditor:auditor /home/auditor

USER auditor
WORKDIR /home/auditor
ENV XDG_STATE_HOME=/home/auditor/.state

ENTRYPOINT ["linux-audit"]
CMD ["scan", "--full", "--format", "terminal"]

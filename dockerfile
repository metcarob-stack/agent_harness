#ARG HERMES_VERSION=v2026.7.30
ARG HERMES_VERSION=v2026.8.3

FROM nousresearch/hermes-agent:${HERMES_VERSION}

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        jq \
        ca-certificates \
        gnupg \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

ENV VAULT_ADDR=https://vault.metcarob.com

RUN VAULT_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/vault \
      | grep -o '"current_version":"[0-9.]*"' \
      | cut -d'"' -f4) && \
    curl -fsSLo /tmp/vault.zip \
      https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
    unzip /tmp/vault.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/vault && \
    rm /tmp/vault.zip

# -------------------------
# qvault
# -------------------------
COPY qvault /usr/local/bin/qvault
RUN chmod +x /usr/local/bin/qvault
COPY qvaultfromopenclaw /usr/local/bin/qvaultfromopenclaw
RUN chmod +x /usr/local/bin/qvaultfromopenclaw


COPY /entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gateway", "run"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:18789/ >/dev/null || exit 1

## PATCH
## watch https://github.com/NousResearch/hermes-agent/pull/48625
COPY login_page.py.v2026.8.3.patched /opt/hermes/hermes_cli/dashboard_auth/login_page.py
COPY middleware.py.v2026.8.3.patched /opt/hermes/hermes_cli/dashboard_auth/middleware.py

RUN groupadd --gid 1000 node && \
    useradd --uid 1000 --gid 1000 --create-home --home-dir /home/node --shell /bin/bash node

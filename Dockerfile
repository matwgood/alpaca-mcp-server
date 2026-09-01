# Build OpenAI Secure MCP Tunnel client
FROM golang:1.26-alpine AS tunnel-builder

RUN apk add --no-cache git

WORKDIR /src

RUN git clone --depth 1 --branch v0.0.13 \
    https://github.com/openai/tunnel-client.git .

RUN CGO_ENABLED=0 go build \
    -o /out/tunnel-client \
    ./cmd/client


# Alpaca MCP runtime
FROM python:3.11-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project

COPY pyproject.toml uv.lock README.md ./
COPY src/ ./src/
COPY .github/core/ ./.github/core/

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

COPY --from=tunnel-builder \
    /out/tunnel-client \
    /usr/local/bin/tunnel-client

ENV PATH="/app/.venv/bin:$PATH"

CMD [
  "tunnel-client",
  "run",
  "--mcp-command",
  "alpaca-mcp-server",
  "--health.listen-addr",
  "127.0.0.1:8080"
]

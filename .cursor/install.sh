#!/usr/bin/env bash
# Idempotent Cloud Agent setup for the Bruin CLI.
#
# The base image already provides Go, a Rust/cargo toolchain, gcc/g++, and
# Node.js. This script installs the one missing tool (uv) and warms the build
# so `bin/bruin` is ready and the Go/cargo caches are populated. It is safe to
# run repeatedly.
#
# Note: we build the binary directly instead of `make build` so setup never
# runs `go mod tidy` (which the `make deps` prerequisite does) and therefore
# never rewrites go.sum, leaving the working tree clean on every boot.
set -euo pipefail

# ~/.local/bin is already on the login-shell PATH via ~/.profile, so a uv
# install there is available to future shells. Export it here for this run.
export PATH="$HOME/.local/bin:$PATH"

# uv powers `make lint-python`, `make format`, and Bruin's ingestr / Python
# asset execution. Install it only when it is not already present.
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  echo "==> uv already installed: $(uv --version)"
fi

# Warm the Go module cache without mutating go.mod/go.sum.
echo "==> Downloading Go modules"
go mod download

# Build the Rust SQL parser FFI static library required by the CGO build.
echo "==> Building Rust SQL parser library"
make rustsqlparser-lib

# Build the CLI (CGO enabled, no_duckdb_arrow tag). This warms the Go build
# cache for fast incremental rebuilds on later boots.
echo "==> Building bruin"
CGO_ENABLED=1 go build -tags="no_duckdb_arrow" -o bin/bruin .

echo "==> Setup complete: $(./bin/bruin --version 2>/dev/null || echo 'bruin built')"

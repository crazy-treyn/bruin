#!/usr/bin/env bash
# Idempotent Cloud Agent setup for the Bruin CLI.
#
# The base image already provides Go, a Rust/cargo toolchain, gcc/g++, and
# Node.js. This script installs the one missing tool (uv) and warms the build
# so `bin/bruin` is ready and the Go/cargo caches are populated. It is safe to
# run repeatedly.
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

# Build the CLI: compiles the Rust SQL parser FFI static library and the Go
# binary (CGO, no_duckdb_arrow tag). This also warms the module and build
# caches for fast incremental rebuilds on later boots.
echo "==> Building bruin (make build)"
make build

echo "==> Setup complete: $(./bin/bruin --version 2>/dev/null || echo 'bruin built')"

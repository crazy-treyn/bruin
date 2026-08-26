#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Bruin CLI.
#
# The base image already ships Go (with per-module toolchain fetch), Rust/Cargo,
# Node, gcc, git, curl and jq. This script adds the two tools the Makefile needs
# that are not in the base image, then warms the Go/Rust build caches so the
# first `make build`/`make test` in a fresh agent is fast.
set -euo pipefail

BIN_DIR=/usr/local/bin

# uv: required by `make format`/`make lint-python` (ruff via uvx) and Python assets.
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv into ${BIN_DIR}"
  curl -LsSf https://astral.sh/uv/install.sh \
    | sudo env UV_INSTALL_DIR="${BIN_DIR}" UV_NO_MODIFY_PATH=1 INSTALLER_NO_MODIFY_PATH=1 sh
else
  echo "==> uv already present: $(command -v uv)"
fi

# golangci-lint: required by `make lint`/`make format`. `make setup` installs the
# pinned version into $(go env GOPATH)/bin, which is not on PATH, so copy it to a
# directory that always is.
if ! command -v golangci-lint >/dev/null 2>&1; then
  echo "==> Installing golangci-lint"
  make setup
  sudo install -m 0755 "$(go env GOPATH)/bin/golangci-lint" "${BIN_DIR}/golangci-lint"
else
  echo "==> golangci-lint already present: $(command -v golangci-lint)"
fi

# Resolve Go module dependencies and build the Rust SQL parser static library +
# the bruin binary. This warms the build caches captured by the environment snapshot.
echo "==> Building bruin (Rust static lib + Go binary)"
make build

echo "==> Bootstrap complete: $(./bin/bruin --version 2>/dev/null | head -1 || echo 'bruin built')"

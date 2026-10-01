#!/usr/bin/env bash
set -euo pipefail

# Install host-side dependencies needed to build grpcio remotely on GitHub Actions.
# This is intentionally not a full Termux build environment.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
mkdir -p "$BUILD_DIR"

echo "[host-deps] ROOT_DIR=$ROOT_DIR"

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    python3-dev \
    python3-pip \
    curl \
    wget \
    unzip \
    git \
    pkg-config
else
  echo "[host-deps] apt-get not found, skipping host dependency install"
fi

python3 --version
cmake --version | head -1 || true
ninja --version || true

echo "[host-deps] host dependencies ready"

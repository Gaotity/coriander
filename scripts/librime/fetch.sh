#!/usr/bin/env bash
# Fetch the pinned librime source (Ticket 02 prerequisite).
set -euo pipefail

LIBRIME_VERSION="1.17.0"
ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/.scratch/librime"

if [[ ! -d "$SRC/.git" ]]; then
  git clone --depth 1 --branch "$LIBRIME_VERSION" https://github.com/rime/librime.git "$SRC"
fi
git -C "$SRC" submodule update --init --depth 1
echo "librime $LIBRIME_VERSION ready at $SRC"

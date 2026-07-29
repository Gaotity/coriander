#!/usr/bin/env bash
# Fetch the pinned baseline Rime data sources (Ticket 06 prerequisite).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
S="$ROOT/.scratch"

clone_pin() { # $1 repo, $2 sha
  local dir="$S/$1"
  if [[ ! -d "$dir/.git" ]]; then
    git clone --filter=blob:none --no-checkout "https://github.com/rime/$1.git" "$dir"
  fi
  git -C "$dir" fetch --depth 1 origin "$2" 2>/dev/null || true
  git -C "$dir" checkout -q "$2"
  echo "$1 @ $2"
}

clone_pin rime-prelude      082425ea0684bca36474415d4a0e8db9b016487e
clone_pin rime-luna-pinyin  56b934b099dfbeab842320f13aa8b461a6ab3e42
clone_pin rime-essay        e9b1a374a6ea015fca5bdd04318924b4483ac35a

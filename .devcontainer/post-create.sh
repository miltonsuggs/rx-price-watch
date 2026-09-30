#!/usr/bin/env bash
# Runs once when the Codespace is created (and again after a rebuild).
set -uo pipefail

echo "==> Installing the Astro CLI (needed in Module 5)"
if ! command -v astro >/dev/null 2>&1; then
  curl -sSL install.astronomer.io | sudo bash -s || echo "!! Astro CLI install failed - see REBUILD.md step B1"
fi

echo "==> Cloning the reference build into /workspaces/reference"
if [ ! -d /workspaces/reference/.git ]; then
  git clone https://github.com/miltonsuggs/rx-price-watch-reference.git /workspaces/reference \
    || echo "!! Could not clone the reference repo - see REBUILD.md step B2"
fi

echo "==> Adding rx-price-watch helper commands to ~/.bashrc"
if ! grep -q "rx-price-watch helpers" ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# --- rx-price-watch helpers (added by .devcontainer/post-create.sh) ---
export RX_PROJECT_ROOT=/workspaces/rx-price-watch
export REF=/workspaces/reference
[ -f "$RX_PROJECT_ROOT/.venv/bin/activate" ] && source "$RX_PROJECT_ROOT/.venv/bin/activate"
refat()   { git -C "$REF" checkout -q "$1" && echo "reference is now at $1"; }
ref()     { code "$REF/$1"; }
mk()      { mkdir -p "$(dirname "$RX_PROJECT_ROOT/$1")" && touch "$RX_PROJECT_ROOT/$1" && code "$RX_PROJECT_ROOT/$1"; }
check()   { code --diff "$REF/$1" "$RX_PROJECT_ROOT/$1"; }
same()    { if cmp -s "$REF/$1" "$RX_PROJECT_ROOT/$1"; then echo "identical: $1"; else diff -u "$REF/$1" "$RX_PROJECT_ROOT/$1" | head -40; fi; }
loadenv() { set -a; source "$RX_PROJECT_ROOT/.env"; set +a; echo "loaded .env into this terminal"; }
BASHRC
fi
echo "==> Done. Open a NEW terminal (Ctrl+Shift+\`) so the helpers load."


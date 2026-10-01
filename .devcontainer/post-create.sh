#!/usr/bin/env bash
# Runs once when the Codespace is created (and again after a rebuild).
# Every install is allowed to fail without breaking the Codespace: failures
# print a "!!" line and you can re-run this script later with:
#   bash .devcontainer/post-create.sh
set -uo pipefail

if ! command -v unzip >/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y -qq unzip
fi

echo "==> Installing uv (Python project + dependency manager)"
if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh \
    || echo "!! uv install failed - re-run: bash .devcontainer/post-create.sh"
fi

echo "==> Installing Terraform"
if ! command -v terraform >/dev/null 2>&1; then
  TF_VERSION=$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform 2>/dev/null \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['current_version'])" 2>/dev/null)
  TF_VERSION=${TF_VERSION:-1.9.8}
  curl -fsSL -o /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" \
    && sudo unzip -o -q /tmp/terraform.zip terraform -d /usr/local/bin \
    || echo "!! Terraform install failed - re-run: bash .devcontainer/post-create.sh"
fi

echo "==> Installing the AWS CLI"
if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    && unzip -o -q /tmp/awscliv2.zip -d /tmp \
    && sudo /tmp/aws/install --update \
    || echo "!! AWS CLI install failed - re-run: bash .devcontainer/post-create.sh"
fi

echo "==> Installing the Astro CLI (needed in Module 5)"
if ! command -v astro >/dev/null 2>&1; then
  curl -sSL install.astronomer.io | sudo bash -s \
    || echo "!! Astro CLI install failed - re-run: bash .devcontainer/post-create.sh"
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

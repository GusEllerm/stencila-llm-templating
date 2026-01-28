#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Generic Dev Container bootstrap (safe + idempotent)
#
# - Installs a nicer shell (zsh + Oh My Zsh + Powerlevel10k)
# - Installs baseline developer tooling
# - Adds optional project-specific installs at the bottom
#
# Notes:
# - Keep this file reproducible: pin versions where it matters (Node, Python tools).
# - Avoid anything that requires credentials (git clone private repos) here.
###############################################################################

# Helper function to run commands with sudo if available, without if root
run_as_root() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  elif [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    echo "Error: Need root privileges but sudo not available and not running as root"
    exit 1
  fi
}

echo "==> Checking SSH agent (optional)"
if [ -S "${SSH_AUTH_SOCK:-}" ]; then
  echo "SSH agent detected at: ${SSH_AUTH_SOCK}"
else
  echo "No SSH agent detected. Git over SSH may not work; use HTTPS or set up SSH."
fi

# Install sudo if not available (needed for vscode user)
if ! command -v sudo >/dev/null 2>&1; then
  echo "==> Installing sudo"
  if [ "$(id -u)" -eq 0 ]; then
    apt-get update
    apt-get install -y sudo
  else
    echo "Warning: Cannot install sudo without root privileges"
  fi
fi

echo "==> Base packages"
# Check what's already installed and only install what's missing
run_as_root apt-get update
PACKAGES_TO_INSTALL=""
for pkg in ca-certificates curl git openssh-client build-essential pkg-config zsh; do
  if ! dpkg -l | grep -q "^ii  $pkg "; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
  fi
done
if [ -n "$PACKAGES_TO_INSTALL" ]; then
  run_as_root apt-get install -y --no-install-recommends $PACKAGES_TO_INSTALL
else
  echo "All base packages already installed"
fi

###############################################################################
# Zsh + Oh My Zsh + Powerlevel10k (optional convenience)
###############################################################################
echo "==> Setting up Oh My Zsh + Powerlevel10k (optional)"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes     sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git     "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Ensure .zshrc uses p10k
if [ -f "$HOME/.zshrc" ]; then
  if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
    sed -i.bak 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$HOME/.zshrc"
  else
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$HOME/.zshrc"
  fi
fi

###############################################################################
# Language toolchains
###############################################################################
echo "==> Installing Python tooling"
# Check if pipx is installed, install if missing
if ! command -v pipx >/dev/null 2>&1; then
  PACKAGES_TO_INSTALL=""
  for pkg in python3 python3-pip python3-venv pipx; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
      PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
    fi
  done
  if [ -n "$PACKAGES_TO_INSTALL" ]; then
    run_as_root apt-get install -y --no-install-recommends $PACKAGES_TO_INSTALL
  fi
else
  echo "Python tooling already installed"
fi

# Upgrade pip if python3 is available
if command -v python3 >/dev/null 2>&1; then
  python3 -m pip install --upgrade pip --break-system-packages 2>/dev/null || python3 -m pip install --upgrade pip --user
fi

echo "==> Checking Node.js installation"
# Check if Node.js 22 is already installed (likely from Dockerfile)
if command -v node >/dev/null 2>&1; then
  NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
  if [ "$NODE_VERSION" = "22" ]; then
    echo "Node.js 22 already installed"
  else
    echo "==> Installing Node.js 22 (via NodeSource)"
    curl -fsSL https://deb.nodesource.com/setup_22.x | run_as_root bash -
    run_as_root apt-get install -y --no-install-recommends nodejs
  fi
else
  echo "==> Installing Node.js 22 (via NodeSource)"
  curl -fsSL https://deb.nodesource.com/setup_22.x | run_as_root bash -
  run_as_root apt-get install -y --no-install-recommends nodejs
fi

echo "==> Enable Corepack + pnpm"
if command -v corepack >/dev/null 2>&1; then
  run_as_root corepack enable || corepack enable
  corepack prepare pnpm@latest --activate || true
else
  echo "Corepack not available, skipping pnpm setup"
fi

###############################################################################
# Project-specific setup (edit this section per repo)
###############################################################################
echo "==> Project-specific setup placeholder"
# Examples:
# - Python venv:
#   python3 -m venv .venv
#   . .venv/bin/activate
#   pip install -r requirements.txt
#
# - Node install:
#   pnpm install
#
# - Rust:
#   cargo build

echo "==> Versions:"
python3 --version
node --version
pnpm --version
rustc --version || true

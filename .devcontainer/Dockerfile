# Multi-stage dev container for Stencila development
# This sets up all build tools but doesn't compile anything automatically

# Base stage with Rust and Node.js
FROM rust:1.89 AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    cmake \
    pkg-config \
    libssl-dev \
    curl \
    git \
    build-essential \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    mold \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (using NodeSource repository for specific version)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node --version

# Verify Python version (should be 3.10+ for Stencila)
RUN python3 --version

# Install Python tools
# Using --break-system-packages is safe in a dev container environment
# Note: pip, setuptools, and wheel are already installed by Debian package manager
# Install uv (fast Python package manager used by Stencila)
RUN pip3 install uv --break-system-packages

# Install Python tools used by the project (ruff, pyright)
RUN pip3 install ruff pyright --break-system-packages

# Install cargo-binstall (for installing Rust tools) for root
# This installs to /root/.cargo/bin
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash || echo "cargo-binstall may already be installed"

# Create vscode user (matching devcontainer default)
RUN useradd -m -s /bin/bash vscode \
    && usermod -aG sudo vscode \
    && echo 'vscode ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up Rust toolchain for root (rustup should be in PATH from rust image)
# The rust-toolchain.toml in the repo will be used automatically
RUN rustup component add rustfmt clippy rust-src || true

# Install common Rust tools (but don't run full setup yet)
# These will be available for manual installation later
ENV PATH="/root/.cargo/bin:${PATH}"

# Create vscode user's home directory and set up Rust environment
# We need to do this before switching users
RUN mkdir -p /home/vscode/.cargo /home/vscode/.rustup \
    && chown -R vscode:vscode /home/vscode

# Switch to vscode user for development
USER vscode
WORKDIR /workspace

# Set up cargo environment for vscode user
# Rustup from the rust image should be in /usr/local/cargo/bin
ENV PATH="/home/vscode/.cargo/bin:/usr/local/cargo/bin:${PATH}"
ENV CARGO_HOME="/home/vscode/.cargo"
ENV RUSTUP_HOME="/home/vscode/.rustup"

# Install cargo-binstall for vscode user
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash || echo "cargo-binstall installation failed, will retry later"

# Set up Rust toolchain for vscode user
# The rust:1.89 image already has Rust 1.89.0 installed system-wide
# We need to initialize rustup for this user and ensure the toolchain is available
# The rust-toolchain.toml file will be picked up automatically when cargo runs in the workspace
RUN rustup default 1.89.0 || (rustup toolchain install 1.89.0 && rustup default 1.89.0) \
    && rustup component add rustfmt clippy rust-src --toolchain 1.89.0 \
    && rustc --version && cargo --version

# Note: Rust tools like cargo-audit, cargo-insta, etc. can be installed later with:
# cargo binstall --no-confirm cargo-audit cargo-insta cargo-llvm-cov cargo-machete cargo-outdated cargo-watch
# Or run: make -C rust setup

# Set environment variables
ENV NODE_VERSION=22
ENV RUST_VERSION=1.89.0
# Python version will be determined by what's available in the base image

# Default command
CMD ["/bin/bash"]

#!/bin/bash
# Setup script for Stencila dev container
# This runs after the container is created

set -euo pipefail

echo "🚀 Setting up Stencila development environment..."

# Navigate to workspace root
cd /workspace

# Install Rust tools (cargo-binstall and other utilities)
echo "📦 Installing Rust development tools..."
if ! command -v cargo-binstall >/dev/null 2>&1; then
	echo "Installing cargo-binstall..."
	curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
fi

# Install cargo tools
echo "Installing cargo utilities..."
cargo binstall --no-confirm cargo-audit cargo-insta cargo-llvm-cov cargo-machete cargo-outdated cargo-watch || true

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --ignore-scripts

# Run the vega patch script manually (normally runs as postinstall)
echo "🔧 Patching vega packages for Parcel compatibility..."
node web/scripts/patch-vega.js

# Build TypeScript
echo "🔨 Building TypeScript..."
cd ts && npm run build && cd ..

# Build web (this is needed for the Rust CLI build)
echo "🔨 Building web components..."
cd web && npm run build && cd ..

# Setup Rust linker configuration for faster builds
echo "⚙️  Configuring Rust for faster builds..."
mkdir -p ~/.cargo

# Detect architecture and configure appropriate linker
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    TARGET="x86_64-unknown-linux-gnu"
    # Prefer mold if available, fallback to lld
    if command -v mold >/dev/null 2>&1; then
        LINKER="mold"
    else
        LINKER="lld"
    fi
elif [ "$ARCH" = "aarch64" ]; then
    TARGET="aarch64-unknown-linux-gnu"
    # Use lld for ARM64 (mold support on ARM64 is limited)
    LINKER="lld"
else
    TARGET="${ARCH}-unknown-linux-gnu"
    LINKER="lld"
fi

cat > ~/.cargo/config.toml <<EOF
[target.${TARGET}]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=${LINKER}"]
EOF

echo "Configured Rust linker for ${TARGET} using ${LINKER}"

echo "✅ Development environment setup complete!"
echo ""
echo "To build the Stencila CLI:"
echo "  cd rust && make build"
echo ""
echo "To run the development server:"
echo "  cd rust && make serve"
echo ""
echo "To export the binary for use in other containers:"
echo "  cd rust && cargo build --bin stencila --release"
echo "  # Binary will be at: target/release/stencila"

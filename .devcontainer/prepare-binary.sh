#!/bin/bash
# Build and prepare Stencila binary for use by other containers
# This builds a release binary and optionally exports it

set -euo pipefail

BUILD_TYPE="${1:-release}"  # debug or release
EXPORT_PATH="${2:-}"  # Optional: path to export binary

echo "🔨 Building Stencila binary ($BUILD_TYPE)..."

cd /workspace/rust

if [ "$BUILD_TYPE" = "release" ]; then
    echo "Building release binary (optimized, smaller)..."
    cargo build --bin stencila --release
    # Cargo workspace uses workspace-level target directory
    BINARY_PATH="/workspace/target/release/stencila"
else
    echo "Building debug binary (faster build, larger size)..."
    cargo build --bin stencila
    # Cargo workspace uses workspace-level target directory
    BINARY_PATH="/workspace/target/debug/stencila"
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build failed - binary not found"
    exit 1
fi

BINARY_SIZE=$(du -h "$BINARY_PATH" | cut -f1)
echo "✅ Binary built successfully!"
echo "   Location: $BINARY_PATH"
echo "   Size: $BINARY_SIZE"

if [ -n "$EXPORT_PATH" ]; then
    echo "📦 Exporting binary to $EXPORT_PATH..."
    cp "$BINARY_PATH" "$EXPORT_PATH"
    chmod +x "$EXPORT_PATH"
    echo "✅ Binary exported to $EXPORT_PATH"
fi

echo ""
echo "💡 Usage from other containers:"
echo "   docker exec <container-name> $BINARY_PATH --version"
echo "   docker exec <container-name> $BINARY_PATH convert input.md output.html"
echo ""
echo "💡 Or mount the target directory:"
echo "   -v /workspace/target:/stencila-binaries:ro"

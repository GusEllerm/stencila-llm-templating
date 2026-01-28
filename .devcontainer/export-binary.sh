#!/bin/bash
# Helper script to export the built Stencila binary from the dev container
# Usage: ./export-binary.sh [output-path]

set -euo pipefail

OUTPUT_PATH="${1:-./stencila}"
# Cargo workspace uses workspace-level target directory
BINARY_PATH="/workspace/target/release/stencila"

echo "🔍 Checking if binary exists..."
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Binary not found at $BINARY_PATH"
    echo "💡 Building release binary first..."
    cd /workspace/rust
    cargo build --bin stencila --release
    cd /workspace
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build failed or binary still not found"
    exit 1
fi

echo "📦 Copying binary to $OUTPUT_PATH..."
cp "$BINARY_PATH" "$OUTPUT_PATH"
chmod +x "$OUTPUT_PATH"

echo "✅ Binary exported successfully!"
echo "   Location: $OUTPUT_PATH"
echo "   Size: $(du -h "$OUTPUT_PATH" | cut -f1)"

#!/bin/bash
# Build Stencila with better progress monitoring
# This shows elapsed time and rough progress estimates

set -euo pipefail

BUILD_TYPE="${1:-release}"
BUILD_FLAGS=""

if [ "$BUILD_TYPE" = "release" ]; then
    BUILD_FLAGS="--release"
    echo "🔨 Building Stencila (release mode - optimized, takes longer)..."
else
    echo "🔨 Building Stencila (debug mode - faster build)..."
fi

cd /workspace/rust

# Count total compilation units (rough estimate)
echo "📊 Analyzing workspace..."
TOTAL_UNITS=$(cargo tree --edges normal 2>/dev/null | wc -l || echo "?")
echo "   Found ~$TOTAL_UNITS compilation units"
echo ""

START_TIME=$(date +%s)
LAST_UPDATE=$START_TIME

# Build with progress tracking
# Use stdbuf to disable buffering so we see output in real-time
# Use --message-format=human to ensure we get readable output even when piped
# Pass through all output, but track progress when we see it
stdbuf -oL -eL cargo build --bin stencila $BUILD_FLAGS --message-format=human 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    
    # Check for cargo's progress line (multiple possible formats)
    if [[ $line =~ Building.*\[.*\]\ ([0-9]+)/([0-9]+): ]] || \
       [[ $line =~ ^\ *([0-9]+)/([0-9]+)\ +Compiling ]] || \
       [[ $line =~ \[([0-9]+)/([0-9]+)\] ]]; then
        # Extract current and total
        if [[ $line =~ Building.*\[.*\]\ ([0-9]+)/([0-9]+): ]]; then
            CURRENT="${BASH_REMATCH[1]}"
            TOTAL="${BASH_REMATCH[2]}"
        elif [[ $line =~ ^\ *([0-9]+)/([0-9]+)\ +Compiling ]]; then
            CURRENT="${BASH_REMATCH[1]}"
            TOTAL="${BASH_REMATCH[2]}"
        elif [[ $line =~ \[([0-9]+)/([0-9]+)\] ]]; then
            CURRENT="${BASH_REMATCH[1]}"
            TOTAL="${BASH_REMATCH[2]}"
        fi
        
        PERCENT=$((CURRENT * 100 / TOTAL))
        
        # Calculate rough ETA based on average time per unit
        if [ "$CURRENT" -gt 5 ] && [ "$CURRENT" -gt 0 ]; then
            AVG_TIME=$((ELAPSED / CURRENT))
            REMAINING=$((TOTAL - CURRENT))
            ETA=$((REMAINING * AVG_TIME))
            ETA_MIN=$((ETA / 60))
            ETA_SEC=$((ETA % 60))
            
            # Show progress on same line, but also show the original cargo line
            echo -e "\r⏱️  [$CURRENT/$TOTAL] ${PERCENT}% | Elapsed: ${ELAPSED}s | ETA: ~${ETA_MIN}m${ETA_SEC}s"
            echo "$line"
        else
            echo -e "\r⏱️  [$CURRENT/$TOTAL] ${PERCENT}% | Elapsed: ${ELAPSED}s | ETA: calculating..."
            echo "$line"
        fi
    else
        # Pass through all other lines (this includes all cargo output)
        echo "$line"
    fi
done

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
echo "✅ Build completed in ${MINUTES}m ${SECONDS}s"

# Show binary info
# Note: This is a Cargo workspace, so target is at workspace root, not in rust/
if [ "$BUILD_TYPE" = "release" ]; then
    BINARY="/workspace/target/release/stencila"
else
    BINARY="/workspace/target/debug/stencila"
fi

if [ -f "$BINARY" ]; then
    SIZE=$(du -h "$BINARY" | cut -f1)
    echo "📦 Binary: $BINARY ($SIZE)"
fi

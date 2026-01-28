#!/bin/bash
# Monitor cargo build progress and estimate time remaining
# Usage: ./monitor-build.sh [build-command]
# Example: ./monitor-build.sh "cargo build --bin stencila --release"

set -euo pipefail

BUILD_CMD="${1:-cargo build --bin stencila --release}"
TOTAL_CRATES=$(cargo tree --edges normal 2>/dev/null | wc -l || echo "unknown")

echo "🔨 Starting build monitoring..."
echo "Command: $BUILD_CMD"
echo "Total crates in workspace: $TOTAL_CRATES"
echo ""

# Start build in background and capture output
BUILD_LOG=$(mktemp)
START_TIME=$(date +%s)

echo "⏱️  Build started at $(date '+%H:%M:%S')"
echo ""

# Run build with timestamps
eval "$BUILD_CMD" 2>&1 | tee "$BUILD_LOG" | while IFS= read -r line; do
    # Extract crate count from cargo's progress output
    if [[ $line =~ Building.*\[.*\]\ ([0-9]+)/([0-9]+): ]]; then
        CURRENT="${BASH_REMATCH[1]}"
        TOTAL="${BASH_REMATCH[2]}"
        ELAPSED=$(($(date +%s) - START_TIME))
        
        if [ "$CURRENT" -gt 0 ]; then
            PERCENT=$((CURRENT * 100 / TOTAL))
            AVG_TIME_PER_CRATE=$((ELAPSED / CURRENT))
            REMAINING_CRATES=$((TOTAL - CURRENT))
            ESTIMATED_REMAINING=$((REMAINING_CRATES * AVG_TIME_PER_CRATE))
            
            echo -ne "\r📊 Progress: $CURRENT/$TOTAL ($PERCENT%) | "
            echo -n "Elapsed: ${ELAPSED}s | "
            echo -n "ETA: ~${ESTIMATED_REMAINING}s"
        fi
    else
        # Show the line normally
        echo "$line"
    fi
done

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo ""
echo "✅ Build completed in ${TOTAL_TIME}s ($(($TOTAL_TIME / 60))m $(($TOTAL_TIME % 60))s)"
rm -f "$BUILD_LOG"

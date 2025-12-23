#!/bin/bash
# =============================================================================
# Patch Reachy Mini Dashboard JavaScript for WSS support
# Fixes WebSocket URLs to use wss:// when page is loaded over HTTPS
# =============================================================================

echo "🔧 Patching dashboard JavaScript for WSS support..."

# Find the reachy-mini dashboard static files
DASHBOARD_DIR=$(python3 -c "import reachy_mini; import os; print(os.path.dirname(reachy_mini.__file__))" 2>/dev/null)

if [ -z "$DASHBOARD_DIR" ]; then
    echo "⚠️  Could not find reachy-mini installation directory"
    exit 0
fi

echo "📁 Dashboard directory: $DASHBOARD_DIR"

# Find all JS files and patch WebSocket URLs
# Replace: new WebSocket('ws://' or new WebSocket(`ws://
# With: protocol-aware version

find "$DASHBOARD_DIR" -name "*.js" -type f 2>/dev/null | while read jsfile; do
    if grep -q "WebSocket.*ws://" "$jsfile" 2>/dev/null; then
        echo "   Patching: $jsfile"
        
        # Create backup
        cp "$jsfile" "${jsfile}.bak"
        
        # Patch: Replace ws:// with protocol detection
        # This handles both 'ws://' and `ws://` patterns
        sed -i "s|new WebSocket('ws://|new WebSocket((window.location.protocol === 'https:' ? 'wss://' : 'ws://') + '|g" "$jsfile"
        sed -i "s|new WebSocket(\`ws://|new WebSocket((window.location.protocol === 'https:' ? 'wss://' : 'ws://') + \`|g" "$jsfile"
        
        # Also handle WebSocket("ws://
        sed -i 's|new WebSocket("ws://|new WebSocket((window.location.protocol === "https:" ? "wss://" : "ws://") + "|g' "$jsfile"
    fi
done

# Also patch any hardcoded ws:// + location.host patterns
find "$DASHBOARD_DIR" -name "*.js" -type f 2>/dev/null | while read jsfile; do
    if grep -q "'ws://' *+ *location" "$jsfile" 2>/dev/null || grep -q "'ws://' *+ *window.location" "$jsfile" 2>/dev/null; then
        echo "   Patching location pattern: $jsfile"
        sed -i "s|'ws://' *+ *location|((window.location.protocol === 'https:' ? 'wss://' : 'ws://') + location|g" "$jsfile"
        sed -i "s|'ws://' *+ *window.location|((window.location.protocol === 'https:' ? 'wss://' : 'ws://') + window.location|g" "$jsfile"
    fi
done

echo "✅ WebSocket patching complete"


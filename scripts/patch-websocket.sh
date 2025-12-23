#!/bin/bash
# =============================================================================
# Patch Reachy Mini Dashboard for WSS support
# Injects a WebSocket override script into the HTML base template
# This is more reliable than patching individual JS files
# =============================================================================

echo "🔧 Patching dashboard for WSS support..."

# Find the base HTML template
BASE_HTML="/usr/local/lib/python3.12/dist-packages/reachy_mini/daemon/app/dashboard/templates/base.html"

if [ ! -f "$BASE_HTML" ]; then
    echo "⚠️  Could not find base.html at: $BASE_HTML"
    # Try to find it
    BASE_HTML=$(find /usr -name "base.html" -path "*reachy_mini*dashboard*" 2>/dev/null | head -1)
    if [ -z "$BASE_HTML" ]; then
        echo "❌ Could not locate base.html template"
        exit 0
    fi
    echo "📁 Found base.html at: $BASE_HTML"
fi

# Check if already patched
if grep -q "WSS_OVERRIDE_PATCHED" "$BASE_HTML" 2>/dev/null; then
    echo "✅ Already patched, skipping"
    exit 0
fi

# Create backup
cp "$BASE_HTML" "${BASE_HTML}.bak"

# The WebSocket override script - patches the constructor globally
WS_OVERRIDE='<!-- WSS_OVERRIDE_PATCHED -->
<script>
(function() {
    // Override WebSocket to automatically use wss:// on HTTPS pages
    const OriginalWebSocket = window.WebSocket;
    window.WebSocket = function(url, protocols) {
        // If page is HTTPS and URL starts with ws://, upgrade to wss://
        if (window.location.protocol === "https:" && url && url.startsWith("ws://")) {
            url = "wss://" + url.substring(5);
            console.log("[WSS Override] Upgraded WebSocket URL to:", url);
        }
        if (protocols !== undefined) {
            return new OriginalWebSocket(url, protocols);
        }
        return new OriginalWebSocket(url);
    };
    window.WebSocket.prototype = OriginalWebSocket.prototype;
    window.WebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
    window.WebSocket.OPEN = OriginalWebSocket.OPEN;
    window.WebSocket.CLOSING = OriginalWebSocket.CLOSING;
    window.WebSocket.CLOSED = OriginalWebSocket.CLOSED;
    console.log("[WSS Override] WebSocket constructor patched for HTTPS compatibility");
})();
</script>'

# Inject the script right after <head> tag
if grep -q "<head>" "$BASE_HTML"; then
    echo "📝 Injecting WebSocket override into base.html..."
    sed -i "s|<head>|<head>\n${WS_OVERRIDE}|" "$BASE_HTML"
    echo "✅ WebSocket override injected successfully"
else
    echo "⚠️  Could not find <head> tag in base.html"
    # Try after <!DOCTYPE or at the very beginning
    echo "📝 Trying alternative injection point..."
    sed -i "1i\\${WS_OVERRIDE}" "$BASE_HTML"
fi

# Verify the patch
if grep -q "WSS_OVERRIDE_PATCHED" "$BASE_HTML"; then
    echo "✅ Patch verified successfully"
else
    echo "❌ Patch verification failed"
fi

echo "✅ WSS patching complete"

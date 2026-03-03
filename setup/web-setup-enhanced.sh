#!/usr/bin/env bash

# DEPRECATED: This script is deprecated and will be removed in a future version.
# Please use setup/install.sh instead.

echo "⚠️  WARNING: setup/web-setup-enhanced.sh is deprecated!" >&2
echo "📁 Please use setup/install.sh instead." >&2
echo "🔄 This wrapper will be removed in a future version." >&2
echo "" >&2

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute the new script with all passed arguments
exec "$SCRIPT_DIR/install.sh" "$@"

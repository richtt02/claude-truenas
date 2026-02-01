#!/bin/bash
#
# Entrypoint script for Claude Code container
# Handles dynamic UID/GID mapping to match host user
#

set -e

# Initialize firewall (must run as root before dropping privileges)
# SECURITY: Firewall failure is FATAL - do not run container unprotected
if [ -x /usr/local/bin/init-firewall.sh ]; then
    echo "Initializing firewall..."
    if ! /usr/local/bin/init-firewall.sh; then
        echo "FATAL: Firewall setup failed. Refusing to run unprotected." >&2
        exit 1
    fi
fi

# Default to user 4000:4000 if not specified
# UID 4000 = claude
# GID 4000 = claude
USER_UID=${USER_UID:-4000}
USER_GID=${USER_GID:-4000}

# Validate UID/GID are numeric and in valid range (0-65534)
validate_id() {
    local value="$1"
    local name="$2"
    if ! echo "$value" | grep -qE '^[0-9]+$'; then
        echo "FATAL: $name must be a positive integer, got: '$value'" >&2
        exit 1
    fi
    if [ "$value" -gt 65534 ]; then
        echo "FATAL: $name must be <= 65534, got: $value" >&2
        exit 1
    fi
}

validate_id "$USER_UID" "USER_UID"
validate_id "$USER_GID" "USER_GID"

# If running as root (UID 0), stay as root
if [ "$USER_UID" -eq 0 ]; then
    echo "WARNING: Running as root (USER_UID=0). Not recommended for production." >&2
    exec "$@"
fi

# Create group if it doesn't exist
# First check if GID is already in use
if ! getent group "$USER_GID" >/dev/null 2>&1; then
    groupadd -g "$USER_GID" claude 2>/dev/null || true
else
    # If GID exists but not with name 'claude', use existing group
    EXISTING_GROUP=$(getent group "$USER_GID" | cut -d: -f1)
    if [ -n "$EXISTING_GROUP" ] && [ "$EXISTING_GROUP" != "claude" ]; then
        GROUP_NAME="$EXISTING_GROUP"
    else
        GROUP_NAME="claude"
    fi
fi

# Default group name if not set
GROUP_NAME=${GROUP_NAME:-claude}

# Create user if it doesn't exist
# First check if UID is already in use
if ! getent passwd "$USER_UID" >/dev/null 2>&1; then
    useradd -u "$USER_UID" -g "$GROUP_NAME" -d /home/claude -s /bin/bash -m claude 2>/dev/null || true
    USER_NAME="claude"
else
    # If UID exists, use existing user
    USER_NAME=$(getent passwd "$USER_UID" | cut -d: -f1)
fi

# Ensure config directory is accessible without modifying existing credential files
# Only fix ownership of the directory itself, not its contents
if [ -d /claude ]; then
    # Change ownership of the directory itself
    chown "$USER_UID:$USER_GID" /claude 2>/dev/null || true
    # Ensure it's writable
    chmod 755 /claude 2>/dev/null || true
fi

# Don't recursively chown workspace - files created by the container will automatically
# have the correct ownership since we're running as USER_UID:USER_GID
# Only ensure the directory itself is accessible
if [ -d /workspace ]; then
    chmod 755 /workspace 2>/dev/null || true
fi

# Ensure code-server directories exist with correct ownership
mkdir -p /home/claude/.config/code-server /home/claude/.local/share/code-server
chown -R "$USER_UID:$USER_GID" /home/claude/.config /home/claude/.local 2>/dev/null || true

# Switch to the user and execute the command
# Use the actual username to ensure proper environment setup
# Set SHELL environment variable for Claude Code
export SHELL=/bin/bash

# Start code-server in background (as unprivileged user) if PASSWORD is set
if [ -n "${PASSWORD:-}" ]; then
    echo "Starting code-server on port 8443..."
    gosu "${USER_NAME}" code-server --bind-addr 0.0.0.0:8443 --auth password /workspace &
fi

exec gosu "${USER_NAME}" "$@"
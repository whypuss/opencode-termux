#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# OpenCode Uninstaller for Termux (Android)
#
# Usage:
#   bash uninstall.sh [--purge]
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
INSTALL_DIR="${HOME}/.opencode"
SYSTEM_BIN="${PREFIX}/bin/opencode"

PURGE_DATA=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--purge)
            PURGE_DATA=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -p, --purge    Remove all configs, caches, sessions and logs"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${YELLOW}${BOLD}==> Uninstalling OpenCode from Termux...${NC}"

# 1. Stop background service if running
if [ -x "$INSTALL_DIR/bin/opencode" ]; then
    echo -e "    Stopping running OpenCode daemon..."
    "$INSTALL_DIR/bin/opencode" service stop 2>/dev/null || true
fi

# Kill any lingering opencode-bin process
pkill -f "opencode-bin" 2>/dev/null || true

# 2. Remove installation folder and binary symlink
echo -e "    Removing installation directory: ${CYAN}${INSTALL_DIR}${NC}"
rm -rf "$INSTALL_DIR"

if [ -L "$SYSTEM_BIN" ] || [ -f "$SYSTEM_BIN" ]; then
    echo -e "    Removing binary symlink: ${CYAN}${SYSTEM_BIN}${NC}"
    rm -f "$SYSTEM_BIN"
fi

# 3. Clean up shell rc files
remove_path_from_rc() {
    local rc="$1"
    if [ -f "$rc" ]; then
        if grep -q "opencode/bin" "$rc"; then
            sed -i '/# opencode/d' "$rc"
            sed -i '/opencode\/bin/d' "$rc"
            echo -e "    Cleaned PATH from ${CYAN}${rc}${NC}"
        fi
    fi
}
remove_path_from_rc "$HOME/.bashrc"
remove_path_from_rc "$HOME/.zshrc"

# 4. Optional purge of user data
if [ "$PURGE_DATA" = true ]; then
    echo -e "    Purging user configuration, caches, and logs..."
    rm -rf "$HOME/.config/opencode"
    rm -rf "$HOME/.cache/opencode"
    rm -rf "$HOME/.local/share/opencode"
    rm -rf "$HOME/.local/state/opencode"
    echo -e "    ${GREEN}All OpenCode data has been purged.${NC}"
else
    echo -e "    ${YELLOW}Note:${NC} Configuration and session data kept at ~/.config/opencode."
    echo -e "    (Run with ${CYAN}--purge${NC} to delete them completely)."
fi

echo -e "${GREEN}${BOLD}✓ OpenCode has been successfully uninstalled.${NC}"

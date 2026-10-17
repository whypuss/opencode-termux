#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# OpenCode Installer for Termux (Android)
#
# GitHub: https://github.com/your-username/opencode-termux
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/install.sh | bash
#   or: bash install.sh [--version <version>] [--mirror <npm|npmmirror>]
# ==============================================================================

set -e

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
INSTALL_DIR="${HOME}/.opencode"
BIN_DIR="${INSTALL_DIR}/bin"
WRAPPER_FILE="${BIN_DIR}/opencode"
BINARY_FILE="${BIN_DIR}/opencode-bin"
SYSTEM_BIN="${PREFIX}/bin/opencode"

REQUESTED_VERSION=""
REQUESTED_MIRROR=""

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ___                    ____          _      "
    echo " / _ \ _ __   ___ _ __  / ___|___   __| | ___ "
    echo "| | | | '_ \ / _ \ '_ \| |   / _ \ / _\` |/ _ \\"
    echo "| |_| | |_) |  __/ | | | |__| (_) | (_| |  __/"
    echo " \___/| .__/ \___|_| |_|\____\___/ \__,_|\___|"
    echo "      |_|            Termux Installer         "
    echo -e "${NC}"
}

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -v, --version <version>  Install a specific version (e.g. 2.0.32)"
    echo "  -m, --mirror <name>      Registry mirror to use: npm, npmmirror, or auto (default: auto)"
    echo "  -u, --uninstall          Uninstall OpenCode from Termux"
    echo "  -h, --help               Show this help message"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            REQUESTED_VERSION="$2"
            shift 2
            ;;
        -m|--mirror)
            REQUESTED_MIRROR="$2"
            shift 2
            ;;
        -u|--uninstall)
            DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
            if [ -f "$DIR/uninstall.sh" ]; then
                exec bash "$DIR/uninstall.sh" "$@"
            else
                echo -e "${YELLOW}Uninstalling OpenCode...${NC}"
                rm -rf "$INSTALL_DIR"
                rm -f "$SYSTEM_BIN"
                echo -e "${GREEN}OpenCode has been successfully uninstalled.${NC}"
                exit 0
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

print_banner

# 1. Environment Verification
echo -e "${BLUE}==>${NC} ${BOLD}Checking environment...${NC}"
if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
    echo -e "${YELLOW}Warning: Termux environment not detected. This installer is optimized for Termux on Android.${NC}"
fi

# 2. Architecture Detection
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|arm64)
        TARGET="linux-arm64"
        ;;
    x86_64|amd64)
        TARGET="linux-x64"
        ;;
    *)
        echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
        echo "OpenCode CLI binary currently only supports aarch64 (ARM64) and x86_64."
        exit 1
        ;;
esac
echo -e "    Detected architecture: ${CYAN}${ARCH} (${TARGET})${NC}"

# 3. Termux Dependencies Installation
echo -e "${BLUE}==>${NC} ${BOLD}Checking and installing required dependencies...${NC}"

ensure_package() {
    local cmd="$1"
    local pkg="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "    Installing missing package: ${YELLOW}${pkg}${NC}..."
        pkg install -y "$pkg"
    fi
}

# Basic utilities
ensure_package "curl" "curl"
ensure_package "tar" "tar"
ensure_package "which" "which"
ensure_package "setsid" "util-linux"

# Glibc runner & repository
if ! dpkg -s glibc-repo >/dev/null 2>&1; then
    echo -e "    Adding ${YELLOW}glibc-repo${NC}..."
    pkg install -y glibc-repo || true
fi

if ! command -v grun >/dev/null 2>&1; then
    echo -e "    Installing ${YELLOW}glibc-runner${NC}..."
    pkg install -y glibc-runner
fi

if ! command -v grun >/dev/null 2>&1; then
    echo -e "${RED}Error: 'grun' (from glibc-runner) is still not available.${NC}"
    echo "Please run: pkg install -y glibc-repo && pkg install -y glibc-runner"
    exit 1
fi
echo -e "    Dependencies check: ${GREEN}OK (grun, setsid, curl, tar ready)${NC}"

# 4. Mirror Selection
choose_mirror() {
    if [ "$REQUESTED_MIRROR" = "npm" ]; then
        REGISTRY="https://registry.npmjs.org"
        echo -e "    Using npm registry: ${CYAN}$REGISTRY${NC}"
        return
    elif [ "$REQUESTED_MIRROR" = "npmmirror" ]; then
        REGISTRY="https://registry.npmmirror.com"
        echo -e "    Using npmmirror registry: ${CYAN}$REGISTRY${NC}"
        return
    fi

    echo -e "${BLUE}==>${NC} ${BOLD}Testing registry latency...${NC}"
    # Test official npm registry with 2s timeout
    if curl -sI -m 2 https://registry.npmjs.org/ >/dev/null 2>&1; then
        REGISTRY="https://registry.npmjs.org"
        echo -e "    Selected registry: ${CYAN}npm (official)${NC}"
    else
        REGISTRY="https://registry.npmmirror.com"
        echo -e "    Selected mirror: ${CYAN}npmmirror (fast mirror)${NC}"
    fi
}
choose_mirror

# 5. Determine Version
echo -e "${BLUE}==>${NC} ${BOLD}Fetching version information...${NC}"
if [ -n "$REQUESTED_VERSION" ]; then
    VERSION="${REQUESTED_VERSION#v}"
    echo -e "    Using specified version: ${CYAN}v${VERSION}${NC}"
else
    # Fetch latest version from registry
    VERSION=$(curl -fsSL --connect-timeout 8 "${REGISTRY}/@opencode/cli/latest" 2>/dev/null | grep -o '"version":"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
    
    # Fallback to update API if needed
    if [ -z "$VERSION" ]; then
        VERSION=$(curl -fsSL --connect-timeout 8 "https://opencode.ai/update/api/latest/cli/npm" 2>/dev/null | grep -o '"version":"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
    fi

    # Fallback to secondary mirror if needed
    if [ -z "$VERSION" ] && [ "$REGISTRY" != "https://registry.npmmirror.com" ]; then
        REGISTRY="https://registry.npmmirror.com"
        VERSION=$(curl -fsSL --connect-timeout 8 "${REGISTRY}/@opencode/cli/latest" 2>/dev/null | grep -o '"version":"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
    fi

    if [ -z "$VERSION" ]; then
        echo -e "${RED}Error: Failed to determine latest OpenCode version.${NC}"
        echo "Please specify a version manually with --version <ver>, e.g., --version 2.0.32"
        exit 1
    fi
    echo -e "    Latest version resolved: ${CYAN}v${VERSION}${NC}"
fi

# 6. Download Package
PACKAGE_NAME="@opencode/cli-${TARGET}"
TARBALL_URL="${REGISTRY}/${PACKAGE_NAME}/-/cli-${TARGET}-${VERSION}.tgz"

echo -e "${BLUE}==>${NC} ${BOLD}Downloading OpenCode package...${NC}"
echo -e "    URL: ${CYAN}${TARBALL_URL}${NC}"

mkdir -p "$BIN_DIR"
TMP_TARBALL=$(mktemp "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/opencode-XXXXXX.tgz" 2>/dev/null || echo "/data/data/com.termux/files/usr/tmp/opencode-${VERSION}.tgz")

cleanup() {
    rm -f "$TMP_TARBALL"
}
trap cleanup EXIT

if ! curl -# -fSL "$TARBALL_URL" -o "$TMP_TARBALL"; then
    echo -e "${YELLOW}Download from primary URL failed, trying fallback mirror...${NC}"
    if [[ "$REGISTRY" == *"npmjs.org"* ]]; then
        FALLBACK_URL="https://registry.npmmirror.com/${PACKAGE_NAME}/-/cli-${TARGET}-${VERSION}.tgz"
    else
        FALLBACK_URL="https://registry.npmjs.org/${PACKAGE_NAME}/-/cli-${TARGET}-${VERSION}.tgz"
    fi
    echo -e "    Fallback URL: ${CYAN}${FALLBACK_URL}${NC}"
    if ! curl -# -fSL "$FALLBACK_URL" -o "$TMP_TARBALL"; then
        echo -e "${RED}Error: Failed to download OpenCode binary archive.${NC}"
        exit 1
    fi
fi

# 7. Extract Binary
echo -e "${BLUE}==>${NC} ${BOLD}Extracting native binary...${NC}"
tar -xzf "$TMP_TARBALL" -C "$BIN_DIR" package/bin/opencode
mv -f "${BIN_DIR}/package/bin/opencode" "$BINARY_FILE"
rm -rf "${BIN_DIR}/package"
chmod 755 "$BINARY_FILE"
echo -e "    Installed binary: ${GREEN}${BINARY_FILE}${NC}"

# 8. Create / Install Wrapper Script
echo -e "${BLUE}==>${NC} ${BOLD}Configuring Termux launcher wrapper...${NC}"

cat << 'EOF' > "$WRAPPER_FILE"
#!/data/data/com.termux/files/usr/bin/bash
# OpenCode Wrapper for Termux
# Executes OpenCode using glibc-runner (grun) and manages background daemon

set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/service.json"

# Resolve grun executable
if command -v grun >/dev/null 2>&1; then
    GRUN_CMD="grun"
elif [ -x "$PREFIX/bin/grun" ]; then
    GRUN_CMD="$PREFIX/bin/grun"
else
    echo "Error: 'grun' (from glibc-runner) not found. Please install glibc-runner: pkg in -y glibc-repo && pkg in -y glibc-runner" >&2
    exit 1
fi

OPENCODE_BIN="$BIN_DIR/opencode-bin"
if [ ! -f "$OPENCODE_BIN" ]; then
    echo "Error: OpenCode binary not found at $OPENCODE_BIN" >&2
    exit 1
fi

is_service_running() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    local pid
    pid=$(grep -o '"pid":[0-9]*' "$STATE_FILE" 2>/dev/null | cut -d: -f2)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    return 1
}

start_service() {
    if is_service_running; then
        return 0
    fi
    rm -f "$STATE_FILE"
    setsid "$GRUN_CMD" "$OPENCODE_BIN" serve --service < /dev/null > /dev/null 2>&1 &
    local count=0
    while [ $count -lt 50 ]; do
        if is_service_running; then
            return 0
        fi
        sleep 0.1
        count=$((count + 1))
    done
    echo "Warning: Background service starting took longer than expected." >&2
    return 0
}

stop_service() {
    if [ -f "$STATE_FILE" ]; then
        local pid
        pid=$(grep -o '"pid":[0-9]*' "$STATE_FILE" 2>/dev/null | cut -d: -f2)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 30 ]; do
                sleep 0.1
                count=$((count + 1))
            done
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$STATE_FILE"
    fi
}

# Dispatch
case "$1" in
    serve)
        exec "$GRUN_CMD" "$OPENCODE_BIN" "$@"
        ;;
    --help|-h|--version|-v)
        exec "$GRUN_CMD" "$OPENCODE_BIN" "$@"
        ;;
    service)
        case "$2" in
            start)
                start_service
                url=$(grep -o '"url":"[^"]*' "$STATE_FILE" 2>/dev/null | cut -d'"' -f4)
                echo "${url:-http://127.0.0.1:49374}"
                exit 0
                ;;
            stop)
                stop_service
                echo "OpenCode service stopped."
                exit 0
                ;;
            restart)
                stop_service
                start_service
                url=$(grep -o '"url":"[^"]*' "$STATE_FILE" 2>/dev/null | cut -d'"' -f4)
                echo "${url:-http://127.0.0.1:49374}"
                exit 0
                ;;
            status)
                if is_service_running; then
                    url=$(grep -o '"url":"[^"]*' "$STATE_FILE" 2>/dev/null | cut -d'"' -f4)
                    echo "running (${url:-http://127.0.0.1:49374})"
                else
                    echo "stopped"
                fi
                exit 0
                ;;
            *)
                start_service
                exec "$GRUN_CMD" "$OPENCODE_BIN" "$@"
                ;;
        esac
        ;;
    *)
        start_service
        exec "$GRUN_CMD" "$OPENCODE_BIN" "$@"
        ;;
esac
EOF

chmod 755 "$WRAPPER_FILE"

# 9. Link to $PREFIX/bin
if [ -d "$PREFIX/bin" ]; then
    ln -sf "$WRAPPER_FILE" "$SYSTEM_BIN"
    echo -e "    Linked command: ${GREEN}${SYSTEM_BIN}${NC} -> ${WRAPPER_FILE}"
fi

# 10. Update shell rc if needed
add_path_to_rc() {
    local rc="$1"
    if [ -f "$rc" ]; then
        if ! grep -q "opencode/bin" "$rc"; then
            echo '' >> "$rc"
            echo '# opencode' >> "$rc"
            echo 'export PATH="$HOME/.opencode/bin:$PATH"' >> "$rc"
            echo -e "    Added PATH to ${CYAN}${rc}${NC}"
        fi
    fi
}
add_path_to_rc "$HOME/.bashrc"
add_path_to_rc "$HOME/.zshrc"

# 11. Verification
echo -e "${BLUE}==>${NC} ${BOLD}Verifying installation...${NC}"
INSTALLED_VER=$("$WRAPPER_FILE" --version 2>/dev/null || echo "failed")

if [ "$INSTALLED_VER" = "failed" ]; then
    echo -e "${RED}Verification failed. OpenCode wrapper encountered an issue.${NC}"
    exit 1
fi

echo -e "${GREEN}${BOLD}✓ Installation successful!${NC} (version: ${CYAN}${INSTALLED_VER}${NC})"
echo ""
echo -e "${BOLD}Quick Start:${NC}"
echo -e "  ${CYAN}opencode${NC}                 Launch OpenCode interactive TUI"
echo -e "  ${CYAN}opencode models${NC}          List available AI models"
echo -e "  ${CYAN}opencode stats${NC}           Show usage statistics"
echo -e "  ${CYAN}opencode service status${NC}  Check background daemon status"
echo -e "  ${CYAN}opencode service stop${NC}    Stop background daemon"
echo ""
echo -e "${YELLOW}Tip:${NC} If running in background for long tasks, consider running ${CYAN}termux-wake-lock${NC} to prevent Android CPU sleeping."
echo ""

#!/bin/bash

# Script: 03_install_python.sh
# Purpose: Check and install Python 3.12 via pyenv and uv

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_command() { echo -e "${BLUE}[RUN]${NC} $1"; }

# Parse arguments
AUTO_YES=false
if [[ "$1" == "-y" ]]; then
    AUTO_YES=true
fi

NEEDS_PATH_UPDATE=false

# Function to reload shell environment
reload_shell_env() {
    # Source bashrc to get latest PATH
    if [ -f ~/.bashrc ]; then
        source ~/.bashrc
    fi
    
    # Reload pyenv if installed
    if [ -d "$HOME/.pyenv" ]; then
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        if command -v pyenv &> /dev/null; then
            eval "$(pyenv init -)"
        fi
    fi
    
    # Reload cargo/uv path if installed
    if [ -d "$HOME/.cargo/bin" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
}

# Initial environment load
reload_shell_env

print_info "Checking pyenv availability..."
if command -v pyenv &> /dev/null; then
    print_info "✓ pyenv detected ($(pyenv --version | head -1))"
else
    print_warning "pyenv not found; it will be required if you choose to install a new Python version."
fi

find_system_python3() {
    local candidates=(
        /usr/bin/python3
        /usr/local/bin/python3
        /bin/python3
    )

    for candidate in "${candidates[@]}"; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    echo ""
    return 1
}

fetch_latest_python_version() {
    local latest=""

    if command -v pyenv &> /dev/null; then
        latest=$(pyenv install --list 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tr -d ' ' | tail -1)
    elif command -v curl &> /dev/null; then
        latest=$(curl -fsSL https://www.python.org/downloads/ 2>/dev/null | \
            grep -m1 -oP 'Latest Python 3 Release - Python \K[0-9]+\.[0-9]+\.[0-9]+')
    fi

    if [ -z "$latest" ]; then
        latest="3.12.0"
    fi

    echo "$latest"
}

ensure_pyenv() {
    if command -v pyenv &> /dev/null; then
        return 0
    fi

    print_warning "pyenv is not installed"

    local INSTALL_PYENV
    if [ "$AUTO_YES" = true ]; then
        INSTALL_PYENV="y"
        print_info "Automatic mode enabled (-y): installing pyenv"
    else
        read -p "Install pyenv? (y/n): " INSTALL_PYENV
    fi

    if [[ ! "$INSTALL_PYENV" =~ ^[Yy]$ ]]; then
        print_error "pyenv installation declined. Cannot proceed with Python installation."
        exit 1
    fi

    print_info "Installing pyenv..."
    curl https://pyenv.run | bash

    if ! grep -q "PYENV_ROOT" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc <<'EOF'

# Pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
        print_info "Added pyenv initialization to ~/.bashrc"
        NEEDS_PATH_UPDATE=true
    fi

    print_info "Reloading shell environment..."
    reload_shell_env

    if command -v pyenv &> /dev/null; then
        print_info "✓ pyenv installed successfully"
        print_info "  Location: $(which pyenv)"
    else
        print_error "pyenv installation failed"
        print_error "Please run: source ~/.bashrc"
        print_error "Then rerun this script"
        exit 1
    fi
}

ensure_runpod_pyenv_guard() {
    local bashrc="$HOME/.bashrc"
    local marker="# runpod_pyenv_guard"

    if [ ! -f "$bashrc" ]; then
        return
    fi

    if ! grep -q "/etc/rp_environment" "$bashrc" 2>/dev/null; then
        return
    fi

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        return
    fi

    if ! command -v python3 &> /dev/null; then
        print_warning "python3 not available for RunPod guard modification; skipping"
        return
    fi

    python3 - <<'PY'
from pathlib import Path

bashrc_path = Path.home() / ".bashrc"
text = bashrc_path.read_text()
needle = "source /etc/rp_environment"
if needle not in text:
    raise SystemExit(0)

guard = """

# runpod_pyenv_guard: ensure pyenv remains active after RunPod environment sourcing
if [ -d "$HOME/.pyenv" ]; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    if command -v pyenv >/dev/null 2>&1; then
        eval "$(pyenv init -)"
    fi
fi
"""

if guard.strip() in text:
    raise SystemExit(0)

text = text.replace(needle, needle + guard, 1)
bashrc_path.write_text(text)
PY

    print_info "Added RunPod pyenv guard to ~/.bashrc"
    NEEDS_PATH_UPDATE=true
}

# Step 1 & 2: Evaluate current Python and decide on installation
PYENV_EXPECTED=false
TARGET_PYTHON_VERSION=""

print_info "Checking python3 availability..."
CURRENT_PYTHON_VERSION=""
PYTHON_PRESENT=false
PYTHON_PATH=""

if command -v python3 &> /dev/null; then
    PYTHON_PATH=$(command -v python3)
    CURRENT_PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_PRESENT=true
    print_info "✓ python3 found on PATH at $PYTHON_PATH (version $CURRENT_PYTHON_VERSION)"
else
    SYSTEM_PYTHON_BIN=$(find_system_python3)
    if [ -n "$SYSTEM_PYTHON_BIN" ]; then
        CURRENT_PYTHON_VERSION=$($SYSTEM_PYTHON_BIN --version 2>&1 | awk '{print $2}')
        PYTHON_PRESENT=true
        PYTHON_PATH="$SYSTEM_PYTHON_BIN"
        print_info "✓ System python3 located at $SYSTEM_PYTHON_BIN (version $CURRENT_PYTHON_VERSION)"
    else
        print_warning "python3 not found via PATH or standard locations"
    fi
fi

LATEST_PYTHON_VERSION=$(fetch_latest_python_version)
if [ -z "$LATEST_PYTHON_VERSION" ]; then
    LATEST_PYTHON_VERSION="3.12.0"
    print_warning "Unable to determine the latest Python release automatically; defaulting to $LATEST_PYTHON_VERSION"
else
    print_info "Latest Python release detected: $LATEST_PYTHON_VERSION"
fi

PYTHON_ACTION=""

if [ "$PYTHON_PRESENT" = false ]; then
    print_warning "No existing python3 installation detected; a new version will be installed."
    PYTHON_ACTION="install_latest"
else
    if [ "$AUTO_YES" = true ]; then
        PYTHON_ACTION="install_latest"
        print_info "Automatic mode (-y): installing latest Python via pyenv ($LATEST_PYTHON_VERSION)"
    else
        while true; do
            echo "Choose Python setup option:"
            echo "  1) Keep current version ($CURRENT_PYTHON_VERSION)"
            echo "  2) Install latest version via pyenv ($LATEST_PYTHON_VERSION)"
            echo "  3) Install custom version via pyenv"
            read -p "Enter choice (1/2/3): " PYTHON_CHOICE

            if [[ ! "$PYTHON_CHOICE" =~ ^[123]$ ]]; then
                print_error "Invalid choice. Please enter 1, 2, or 3."
                continue
            fi

            if [ "$PYTHON_CHOICE" = "1" ]; then
                PYTHON_ACTION="keep"
                break
            elif [ "$PYTHON_CHOICE" = "2" ]; then
                PYTHON_ACTION="install_latest"
                break
            elif [ "$PYTHON_CHOICE" = "3" ]; then
                PYTHON_ACTION="install_custom"
                break
            fi
        done
    fi
fi

CUSTOM_VERSION=""
if [ "$PYTHON_ACTION" = "install_custom" ]; then
    while true; do
        read -p "Enter desired Python version (e.g. 3.11.8): " CUSTOM_VERSION
        if [[ "$CUSTOM_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
            break
        else
            print_error "Invalid version format. Please use numeric values like 3.11.8"
        fi
    done
    TARGET_PYTHON_VERSION="$CUSTOM_VERSION"
fi

if [ "$PYTHON_ACTION" = "keep" ]; then
    TARGET_PYTHON_VERSION="$CURRENT_PYTHON_VERSION"
    print_info "Keeping existing python3 version $TARGET_PYTHON_VERSION"
else
    ensure_pyenv
    PYENV_EXPECTED=true

    if [ "$PYTHON_ACTION" = "install_latest" ]; then
        # Re-fetch latest version now that pyenv is available
        LATEST_PYTHON_VERSION=$(fetch_latest_python_version)
        TARGET_PYTHON_VERSION="$LATEST_PYTHON_VERSION"
    fi

    if [ -z "$TARGET_PYTHON_VERSION" ]; then
        print_error "No target Python version specified"
        exit 1
    fi

    if pyenv versions 2>/dev/null | tr -d ' *' | grep -qx "$TARGET_PYTHON_VERSION"; then
        print_info "Python $TARGET_PYTHON_VERSION already installed via pyenv"
    else
        print_info "Installing Python $TARGET_PYTHON_VERSION via pyenv..."
        print_info "This compiles Python from source and may take several minutes."
        MAKE_OPTS="-j$(nproc)" pyenv install "$TARGET_PYTHON_VERSION"
        if [ $? -ne 0 ]; then
            print_error "Failed to install Python $TARGET_PYTHON_VERSION"
            exit 1
        fi
    fi

    pyenv global "$TARGET_PYTHON_VERSION"
    pyenv rehash
    reload_shell_env
    ensure_runpod_pyenv_guard
    CURRENT_PYTHON_VERSION="$TARGET_PYTHON_VERSION"
    PYTHON_PRESENT=true
    print_info "Python $TARGET_PYTHON_VERSION is now set as the global pyenv version"
fi

echo ""

# Step 3: Check and install uv
print_info "Checking uv..."
if command -v uv &> /dev/null; then
    print_info "✓ uv is installed ($(uv --version))"
else
    print_error "✗ uv is not installed"
    
    if [ "$AUTO_YES" = true ]; then
        INSTALL_UV="y"
    else
        read -p "Install uv? (y/n): " INSTALL_UV
    fi
    
    if [[ "$INSTALL_UV" =~ ^[Yy]$ ]]; then
        print_info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        
        # Add to PATH if not present
        if ! grep -q ".cargo/bin" ~/.bashrc; then
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
            print_info "Added cargo/bin to PATH in ~/.bashrc"
            NEEDS_PATH_UPDATE=true
        fi
        
        # Reload environment
        print_info "Reloading shell environment..."
        reload_shell_env
        
        # Verify installation - check multiple times as sometimes it takes a moment
        for i in {1..3}; do
            if command -v uv &> /dev/null; then
                print_info "✓ uv installed successfully"
                print_info "  Location: $(which uv)"
                break
            else
                sleep 1
            fi
        done
        
        if ! command -v uv &> /dev/null; then
            print_error "uv not found in PATH"
            print_info "Please run: source ~/.bashrc"
            print_info "Then verify with: which uv"
        fi
    else
        print_info "Skipping uv installation."
    fi
fi

echo ""
echo "=============================================="

# Final verification
ALL_GOOD=true

print_info "Final verification:"

if command -v pyenv &> /dev/null; then
    print_info "  ✓ pyenv: $(pyenv --version | head -1)"
    print_info "    Location: $(which pyenv)"
elif [ "$PYENV_EXPECTED" = true ]; then
    print_error "  ✗ pyenv not found despite installation attempt"
    ALL_GOOD=false
else
    print_info "  ℹ pyenv not installed (not requested)"
fi

if command -v python3 &> /dev/null; then
    ACTIVE_PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    print_info "  ✓ python3: $(python3 --version)"
    print_info "    Location: $(which python3)"
    if [ -n "$TARGET_PYTHON_VERSION" ] && [ "$PYTHON_ACTION" != "keep" ] && [ "$ACTIVE_PYTHON_VERSION" != "$TARGET_PYTHON_VERSION" ]; then
        print_warning "  ! Expected python3 version $TARGET_PYTHON_VERSION but found $ACTIVE_PYTHON_VERSION"
        print_info "    Run: pyenv global $TARGET_PYTHON_VERSION"
        ALL_GOOD=false
    fi
else
    print_error "  ✗ python3 not found"
    ALL_GOOD=false
fi

# Check uv
if command -v uv &> /dev/null; then
    print_info "  ✓ uv: $(uv --version)"
    print_info "    Location: $(which uv)"
else
    print_error "  ✗ uv not found"
    ALL_GOOD=false
fi

echo ""

# Summary
if [ "$ALL_GOOD" = true ]; then
    print_info "✅ All Python tools are properly installed!"
else
    if [ "$NEEDS_PATH_UPDATE" = true ]; then
        print_warning "Some tools may not be visible until you reload your shell."
        print_info "Please run:"
        print_command "source ~/.bashrc"
        print_info "Or start a new terminal session, then run this script again to verify."
    else
        print_error "Some tools are missing or not properly configured."
    fi
fi

# Debug info if needed
if [ "$ALL_GOOD" = false ]; then
    echo ""
    print_info "Debug information:"
    print_info "  PATH: $PATH"
    print_info "  PYENV_ROOT: ${PYENV_ROOT:-not set}"
fi

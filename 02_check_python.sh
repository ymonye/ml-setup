#!/bin/bash

# Script: check_python.sh
# Purpose: Check and install Python 3.11.9 via pyenv and uv

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

# Step 1: Check and install pyenv
print_info "Checking pyenv..."
if command -v pyenv &> /dev/null; then
    print_info "✓ pyenv is installed"
else
    print_error "✗ pyenv is not installed"
    
    if [ "$AUTO_YES" = true ]; then
        INSTALL_PYENV="y"
    else
        read -p "Install pyenv? (y/n): " INSTALL_PYENV
    fi
    
    if [[ "$INSTALL_PYENV" =~ ^[Yy]$ ]]; then
        print_info "Installing pyenv..."
        curl https://pyenv.run | bash
        
        # Add to bashrc if not present
        if ! grep -q "PYENV_ROOT" ~/.bashrc; then
            cat >> ~/.bashrc << 'EOF'

# Pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
            print_info "Added pyenv to ~/.bashrc"
            NEEDS_PATH_UPDATE=true
        fi
        
        # Reload environment
        print_info "Reloading shell environment..."
        reload_shell_env
        
        # Verify installation
        if command -v pyenv &> /dev/null; then
            print_info "✓ pyenv installed successfully"
            print_info "  Location: $(which pyenv)"
        else
            print_error "Failed to install pyenv"
            print_error "Please run: source ~/.bashrc"
            print_error "Then run this script again"
            exit 1
        fi
    else
        print_info "Skipping pyenv installation. Cannot proceed without pyenv."
        exit 1
    fi
fi

echo ""

# Step 2: Check and install Python 3.11.9
print_info "Checking Python 3.11.9..."
if pyenv versions 2>/dev/null | grep -q "3.11.9"; then
    print_info "✓ Python 3.11.9 is installed"
    
    # Check if it's the global version
    if pyenv version | grep -q "3.11.9"; then
        print_info "✓ Python 3.11.9 is set as global"
    else
        print_warning "Python 3.11.9 is installed but not set as global"
        if [ "$AUTO_YES" = true ]; then
            SET_GLOBAL="y"
        else
            read -p "Set Python 3.11.9 as global? (y/n): " SET_GLOBAL
        fi
        
        if [[ "$SET_GLOBAL" =~ ^[Yy]$ ]]; then
            pyenv global 3.11.9
            pyenv rehash
            print_info "✓ Set Python 3.11.9 as global"
        fi
    fi
else
    print_error "✗ Python 3.11.9 is not installed"
    
    if [ "$AUTO_YES" = true ]; then
        INSTALL_PYTHON="y"
    else
        read -p "Install Python 3.11.9? This will take 5-15 minutes. (y/n): " INSTALL_PYTHON
    fi
    
    if [[ "$INSTALL_PYTHON" =~ ^[Yy]$ ]]; then
        print_info "Installing Python 3.11.9 via pyenv..."
        print_info "This compiles Python from source and may take 5-15 minutes."
        
        # Speed up compilation with parallel jobs
        MAKE_OPTS="-j$(nproc)" pyenv install 3.11.9
        
        if [ $? -eq 0 ]; then
            pyenv global 3.11.9
            pyenv rehash
            
            # Reload to get new Python
            reload_shell_env
            
            print_info "✓ Python 3.11.9 installed and set as global"
        else
            print_error "Failed to install Python 3.11.9"
            exit 1
        fi
    else
        print_info "Skipping Python 3.11.9 installation."
    fi
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

# Check pyenv
if command -v pyenv &> /dev/null; then
    print_info "  ✓ pyenv: $(pyenv --version | head -1)"
    print_info "    Location: $(which pyenv)"
else
    print_error "  ✗ pyenv not found"
    ALL_GOOD=false
fi

# Check Python
if command -v python &> /dev/null && python --version 2>&1 | grep -q "3.11.9"; then
    print_info "  ✓ Python: $(python --version)"
    print_info "    Location: $(which python)"
else
    if pyenv versions 2>/dev/null | grep -q "3.11.9"; then
        print_warning "  ! Python 3.11.9 installed but not active"
        print_info "    Run: pyenv global 3.11.9"
    else
        print_error "  ✗ Python 3.11.9 not installed"
    fi
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

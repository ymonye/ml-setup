#!/bin/bash
# Script: 00_init.sh
# Purpose: Initialize environment with Node.js and various coding CLIs

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Parse arguments
AUTO_YES=false
if [[ "$1" == "-y" ]] || [[ "$1" == "--auto" ]]; then
    AUTO_YES=true
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [-y|--auto]"
    echo "  -y, --auto    Automatically accept all prompts"
    echo "  -h, --help    Show this help message"
    exit 0
fi

print_info "Initialization Script for Development Environment"
echo ""

# Update Ubuntu
if [ "$AUTO_YES" = true ]; then
    UPDATE_SYSTEM="y"
else
    read -p "Update system packages (apt-get update)? (y/n): " UPDATE_SYSTEM
fi

if [[ "$UPDATE_SYSTEM" =~ ^[Yy]$ ]]; then
    print_info "Updating system packages..."
    sudo apt-get update
    if [ $? -ne 0 ]; then
        print_error "Failed to update packages"
        exit 1
    fi
    print_info "✓ System packages updated"
else
    print_info "Skipped system update"
fi

echo ""

# Upgrade Ubuntu
if [ "$AUTO_YES" = true ]; then
    UPGRADE_SYSTEM="y"
else
    read -p "Upgrade system packages (apt-get upgrade)? This may take a while. (y/n): " UPGRADE_SYSTEM
fi

if [[ "$UPGRADE_SYSTEM" =~ ^[Yy]$ ]]; then
    print_info "Upgrading system packages..."
    sudo apt-get upgrade -y
    if [ $? -ne 0 ]; then
        print_error "Failed to upgrade packages"
        exit 1
    fi
    print_info "✓ System packages upgraded"
else
    print_info "Skipped system upgrade"
fi

echo ""

# Install nvm (Node Version Manager)
if [ "$AUTO_YES" = true ]; then
    INSTALL_NVM="y"
else
    read -p "Install nvm (Node Version Manager)? (y/n): " INSTALL_NVM
fi

if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
    print_info "Checking for existing nvm installation..."
    if [ -d "$HOME/.nvm" ]; then
        print_info "✓ nvm is already installed"
    else
        print_info "Downloading and installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        if [ $? -ne 0 ]; then
            print_error "Failed to install nvm"
            exit 1
        fi
        print_info "✓ nvm installed"
    fi
    
    # Load nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
    print_info "Skipped nvm installation"
fi

echo ""

# Install Node.js 22
if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
    if [ "$AUTO_YES" = true ]; then
        INSTALL_NODE="y"
    else
        read -p "Install Node.js 22? (y/n): " INSTALL_NODE
    fi
    
    if [[ "$INSTALL_NODE" =~ ^[Yy]$ ]]; then
        print_info "Installing Node.js 22..."
        nvm install 22
        if [ $? -ne 0 ]; then
            print_error "Failed to install Node.js 22"
            exit 1
        fi
        nvm use 22
        print_info "✓ Node.js installed"
        
        # Verify installation
        NODE_VERSION=$(node -v 2>/dev/null)
        NPM_VERSION=$(npm -v 2>/dev/null)
        print_info "Node.js version: $NODE_VERSION"
        print_info "npm version: $NPM_VERSION"
    else
        print_info "Skipped Node.js installation"
    fi
fi

echo ""

# Install coding CLIs
if command -v npm &> /dev/null; then
    print_info "Available coding CLIs to install:"
    print_info "  1. Claude Code (@anthropic-ai/claude-code)"
    print_info "  2. Crush (@charmland/crush)"
    print_info "  3. Gemini CLI (@google/gemini-cli)"
    print_info "  4. OpenAI Codex (@openai/codex)"
    print_info "  5. Qwen Code (@qwen-code/qwen-code)"
    print_info "  6. OpenCode AI (opencode-ai)"
    print_info "  7. Cursor CLI"
    echo ""
    
    if [ "$AUTO_YES" = true ]; then
        INSTALL_CLIS="y"
    else
        read -p "Install coding CLIs? (y/n): " INSTALL_CLIS
    fi
    
    if [[ "$INSTALL_CLIS" =~ ^[Yy]$ ]]; then
        # Claude Code
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CLAUDE="y"
        else
            read -p "  Install Claude Code? (y/n): " INSTALL_CLAUDE
        fi
        if [[ "$INSTALL_CLAUDE" =~ ^[Yy]$ ]]; then
            print_info "Installing Claude Code..."
            npm install -g @anthropic-ai/claude-code
            [ $? -eq 0 ] && print_info "✓ Claude Code installed" || print_warning "Failed to install Claude Code"
        fi
        
        # Crush
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CRUSH="y"
        else
            read -p "  Install Crush? (y/n): " INSTALL_CRUSH
        fi
        if [[ "$INSTALL_CRUSH" =~ ^[Yy]$ ]]; then
            print_info "Installing Crush..."
            npm install -g @charmland/crush
            [ $? -eq 0 ] && print_info "✓ Crush installed" || print_warning "Failed to install Crush"
        fi
        
        # Gemini CLI
        if [ "$AUTO_YES" = true ]; then
            INSTALL_GEMINI="y"
        else
            read -p "  Install Gemini CLI? (y/n): " INSTALL_GEMINI
        fi
        if [[ "$INSTALL_GEMINI" =~ ^[Yy]$ ]]; then
            print_info "Installing Gemini CLI..."
            npm install -g @google/gemini-cli
            [ $? -eq 0 ] && print_info "✓ Gemini CLI installed" || print_warning "Failed to install Gemini CLI"
        fi
        
        # OpenAI Codex
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CODEX="y"
        else
            read -p "  Install OpenAI Codex? (y/n): " INSTALL_CODEX
        fi
        if [[ "$INSTALL_CODEX" =~ ^[Yy]$ ]]; then
            print_info "Installing OpenAI Codex..."
            npm install -g @openai/codex
            [ $? -eq 0 ] && print_info "✓ OpenAI Codex installed" || print_warning "Failed to install OpenAI Codex"
        fi
        
        # Qwen Code
        if [ "$AUTO_YES" = true ]; then
            INSTALL_QWEN="y"
        else
            read -p "  Install Qwen Code? (y/n): " INSTALL_QWEN
        fi
        if [[ "$INSTALL_QWEN" =~ ^[Yy]$ ]]; then
            print_info "Installing Qwen Code..."
            npm install -g @qwen-code/qwen-code
            [ $? -eq 0 ] && print_info "✓ Qwen Code installed" || print_warning "Failed to install Qwen Code"
        fi
        
        # OpenCode AI
        if [ "$AUTO_YES" = true ]; then
            INSTALL_OPENCODE="y"
        else
            read -p "  Install OpenCode AI? (y/n): " INSTALL_OPENCODE
        fi
        if [[ "$INSTALL_OPENCODE" =~ ^[Yy]$ ]]; then
            print_info "Installing OpenCode AI..."
            npm install -g opencode-ai@latest
            [ $? -eq 0 ] && print_info "✓ OpenCode AI installed" || print_warning "Failed to install OpenCode AI"
        fi
        
        # Cursor CLI
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CURSOR="y"
        else
            read -p "  Install Cursor CLI? (y/n): " INSTALL_CURSOR
        fi
        if [[ "$INSTALL_CURSOR" =~ ^[Yy]$ ]]; then
            print_info "Installing Cursor CLI..."
            curl https://cursor.com/install -fsS | bash
            [ $? -eq 0 ] && print_info "✓ Cursor CLI installed" || print_warning "Failed to install Cursor CLI"
        fi
    else
        print_info "Skipped CLI installations"
    fi
else
    print_warning "npm not found - skipping CLI installations"
    print_info "Install Node.js first to install coding CLIs"
fi

echo ""
print_info "✅ Initialization complete!"
print_info "If you installed nvm/Node.js, restart your shell or run: source ~/.bashrc"
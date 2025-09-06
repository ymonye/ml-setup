#!/bin/bash
# Script: 02_install_dependencies.sh
# Purpose: Check and install system dependencies for ML environment
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
# Track overall success
INSTALL_SUCCESS=true
# Parse arguments
AUTO_YES=false
if [[ "$1" == "-y" ]]; then
    AUTO_YES=true
fi
# Check OS version first
print_info "Checking OS version..."
if [ ! -f /etc/os-release ]; then
    print_error "Cannot determine OS version. /etc/os-release not found."
    exit 1
fi
source /etc/os-release
VERSION_MAJOR=$(echo $VERSION_ID | cut -d. -f1)

# Detect OS type and set package manager
OS_TYPE=""
PKG_MANAGER=""
PKG_INSTALL_CMD=""
PKG_UPDATE_CMD=""
PKG_QUERY_CMD=""

if [ "$ID" = "ubuntu" ]; then
    if [ "$VERSION_MAJOR" -lt 22 ]; then
        print_error "This script requires Ubuntu 22.04 or newer. Detected: $ID $VERSION_ID"
        exit 1
    fi
    OS_TYPE="ubuntu"
    PKG_MANAGER="apt"
    PKG_INSTALL_CMD="sudo NEEDRESTART_MODE=l apt install -y"
    PKG_UPDATE_CMD="sudo NEEDRESTART_MODE=l apt update"
    PKG_QUERY_CMD="dpkg -l"
    print_info "✓ Ubuntu $VERSION_ID detected"
elif [[ "$ID" =~ ^(rhel|rocky|almalinux)$ ]]; then
    if [ "$VERSION_MAJOR" -lt 9 ]; then
        print_error "This script requires RHEL/Rocky/AlmaLinux 9 or newer. Detected: $ID $VERSION_ID"
        exit 1
    fi
    OS_TYPE="rhel"
    PKG_MANAGER="dnf"
    PKG_INSTALL_CMD="sudo dnf install -y"
    PKG_UPDATE_CMD="sudo dnf makecache"
    PKG_QUERY_CMD="rpm -qa"
    print_info "✓ $NAME $VERSION_ID detected"
else
    print_error "Unsupported OS. This script supports Ubuntu 22.04+ and RHEL/Rocky/AlmaLinux 9+. Detected: $ID $VERSION_ID"
    exit 1
fi
echo ""
# Check disk space
print_info "Checking disk space..."
AVAILABLE_SPACE=$(df -BG /var | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 5 ]; then
    print_error "Low disk space: ${AVAILABLE_SPACE}GB available on /var"
    print_error "At least 5GB recommended for package installation"
    print_info "Free up space with: sudo apt clean"
    exit 1
else
    print_info "✓ Disk space: ${AVAILABLE_SPACE}GB available"
fi
echo ""
# System packages - define based on OS type
if [ "$OS_TYPE" = "ubuntu" ]; then
    SYSTEM_PACKAGES=(
        # Essential build tools
        "build-essential"
        "gcc"
        "g++"
        "make"
        "cmake"
        
        # NUMA optimization
        "numactl"
        "libnuma-dev"
        
        # Essential Python dependencies
        "libssl-dev"
        "libffi-dev"
        "liblzma-dev"
        "libbz2-dev"
        "libreadline-dev"
        "libsqlite3-dev"
        "libncurses-dev"
        "zlib1g-dev"
        
        # Tools
        "curl"
        "wget"
        "git"
        "htop"
	"nvtop"
        "tmux"
        "pkg-config"
    )
elif [ "$OS_TYPE" = "rhel" ]; then
    SYSTEM_PACKAGES=(
        # Essential build tools
        "gcc"
        "gcc-c++"
        "make"
        "cmake"
        
        # NUMA optimization
        "numactl"
        "numactl-devel"
        
        # Essential Python dependencies
        "openssl-devel"
        "libffi-devel"
        "zlib-devel"
        "xz-devel"
        "bzip2-devel"
        "readline-devel"
        "ncurses-devel"
        "sqlite-devel"
        
        # Tools
        "curl"
        "wget"
        "git"
        "htop"
	"nvtop"
        "tmux"
        "pkgconf-pkg-config"
    )
fi
# Check packages
print_info "Checking system dependencies..."
MISSING_PACKAGES=()
for pkg in "${SYSTEM_PACKAGES[@]}"; do
    if [ "$OS_TYPE" = "ubuntu" ]; then
        if dpkg -l 2>/dev/null | grep -q "^ii  $pkg"; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_PACKAGES+=($pkg)
        fi
    elif [ "$OS_TYPE" = "rhel" ]; then
        if rpm -qa | grep -q "^$pkg"; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_PACKAGES+=($pkg)
        fi
    fi
done
# Check CUDA driver and toolkit
echo ""
print_info "Checking CUDA driver and toolkit..."

# Check for NVIDIA driver and get supported CUDA version
DRIVER_CUDA_VERSION=""
if command -v nvidia-smi &> /dev/null; then
    # Extract CUDA version supported by driver from nvidia-smi output
    DRIVER_CUDA_VERSION=$(nvidia-smi | grep -oP 'CUDA Version:\s*\K[0-9]+\.[0-9]+' | head -1)
    if [ -n "$DRIVER_CUDA_VERSION" ]; then
        print_info "  ✓ NVIDIA driver detected - supports CUDA up to version $DRIVER_CUDA_VERSION"
    else
        print_warning "  ⚠ NVIDIA driver detected but couldn't determine CUDA version support"
    fi
else
    print_warning "  ⚠ No NVIDIA driver detected (nvidia-smi not found)"
    print_info "  Will default to CUDA 12.9 for H100/H200 compatibility"
fi

# Check for CUDA toolkit (nvcc)
CUDA_MISSING=false
CUDA_VERSION_OK=false
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
    print_info "  ✓ CUDA toolkit (nvcc) - version $CUDA_VERSION"
    
    # Check if installed CUDA version needs upgrade to 12.9
    CUDA_VERSION_MAJOR=$(echo $CUDA_VERSION | cut -d. -f1 | sed 's/V//')
    CUDA_VERSION_MINOR=$(echo $CUDA_VERSION | cut -d. -f2)
    
    if [ "$CUDA_VERSION_MAJOR" -gt 12 ] || ([ "$CUDA_VERSION_MAJOR" -eq 12 ] && [ "$CUDA_VERSION_MINOR" -ge 9 ]); then
        CUDA_VERSION_OK=true
        print_info "  ✓ CUDA version $CUDA_VERSION is 12.9 or newer"
    else
        print_warning "  ⚠ CUDA version $CUDA_VERSION is older than 12.9"
        print_warning "  Will upgrade to CUDA 12.9 for better compatibility"
        CUDA_MISSING=true  # Treat as missing to trigger upgrade
    fi
else
    print_error "  ✗ CUDA toolkit (nvcc)"
    CUDA_MISSING=true
fi
echo ""
# Report and install
if [ ${#MISSING_PACKAGES[@]} -eq 0 ] && [ "$CUDA_MISSING" = false ]; then
    print_info "✅ All system dependencies are installed!"
    exit 0
else
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        print_warning "Missing ${#MISSING_PACKAGES[@]} packages: ${MISSING_PACKAGES[*]}"
    fi
    if [ "$CUDA_MISSING" = true ]; then
        if command -v nvcc &> /dev/null; then
            print_warning "CUDA toolkit needs upgrade to version 12.9"
        else
            print_warning "CUDA toolkit (nvcc) not found - required for GPU-optimized packages"
        fi
    fi
    echo ""
    
    if [ "$AUTO_YES" = true ]; then
        INSTALL_NOW="y"
    else
        read -p "Do you want to install missing packages? (y/n): " INSTALL_NOW
    fi
    
    if [[ "$INSTALL_NOW" =~ ^[Yy]$ ]]; then
        # Install system packages first
        if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
            print_info "Installing missing packages..."
            echo ""
            
            # Clean apt cache first if low on space
            if [ "$AVAILABLE_SPACE" -lt 10 ]; then
                if [ "$AUTO_YES" = true ]; then
                    CLEAN_CACHE="y"
                else
                    print_warning "Low disk space (${AVAILABLE_SPACE}GB). Clean apt cache to free space?"
                    read -p "Clean apt cache? (y/n): " CLEAN_CACHE
                fi
                
                if [[ "$CLEAN_CACHE" =~ ^[Yy]$ ]]; then
                    print_info "Cleaning apt cache to free space..."
                    sudo apt clean
                else
                    print_warning "Proceeding without cleaning apt cache - installation may fail if space runs out"
                fi
            fi
            
            # Update package lists
            if [ "$OS_TYPE" = "ubuntu" ]; then
                print_info "Note: Using NEEDRESTART_MODE=l to prevent automatic service restarts"
                sudo NEEDRESTART_MODE=l apt update
            elif [ "$OS_TYPE" = "rhel" ]; then
                sudo dnf makecache
            fi
            
            if [ $? -ne 0 ]; then
                print_error "Package update failed - check your internet connection and disk space"
                INSTALL_SUCCESS=false
            else
                if [ "$OS_TYPE" = "ubuntu" ]; then
                    sudo NEEDRESTART_MODE=l apt install -y ${MISSING_PACKAGES[*]}
                elif [ "$OS_TYPE" = "rhel" ]; then
                    sudo dnf install -y ${MISSING_PACKAGES[*]}
                fi
                
                if [ $? -ne 0 ]; then
                    print_error "Failed to install some packages"
                    INSTALL_SUCCESS=false
                fi
            fi
        fi
        
        # Install ibtop - Network monitoring tool
        if [ "$INSTALL_SUCCESS" = true ]; then
            if ! command -v ibtop &> /dev/null; then
                if [ "$AUTO_YES" = true ]; then
                    INSTALL_IBTOP="y"
                else
                    read -p "Install ibtop (network monitoring tool)? (y/n): " INSTALL_IBTOP
                fi
                
                if [[ "$INSTALL_IBTOP" =~ ^[Yy]$ ]]; then
                    print_info "Installing ibtop network monitoring tool..."
                    if curl -fsSL https://raw.githubusercontent.com/JannikSt/ibtop/main/install.sh | bash; then
                        print_info "✓ ibtop installed successfully"
                    else
                        print_warning "Failed to install ibtop"
                    fi
                else
                    print_info "Skipped ibtop installation"
                fi
            else
                print_info "✓ ibtop already installed"
            fi
        fi
        
        # Install tmux configuration
        if [ "$INSTALL_SUCCESS" = true ]; then
            if [ ! -f ~/.tmux.conf ] || ! grep -q "set -g mouse on" ~/.tmux.conf 2>/dev/null; then
                if [ "$AUTO_YES" = true ]; then
                    SETUP_TMUX="y"
                else
                    read -p "Setup tmux mouse support in ~/.tmux.conf? (y/n): " SETUP_TMUX
                fi
                
                if [[ "$SETUP_TMUX" =~ ^[Yy]$ ]]; then
                    echo "set -g mouse on" >> ~/.tmux.conf
                    print_info "✓ Added mouse support to ~/.tmux.conf"
                else
                    print_info "Skipped tmux configuration"
                fi
            else
                print_info "✓ Mouse support already configured in ~/.tmux.conf"
            fi
        fi
        
        # Check and fix gcc/g++ version mismatch after package installation
        if [ "$INSTALL_SUCCESS" = true ]; then
            print_info "Checking gcc/g++ version compatibility..."
            
            # Get installed gcc version
            if command -v gcc &> /dev/null; then
                GCC_VERSION=$(gcc --version | head -1 | grep -oE '[0-9]+' | head -1)
                print_info "Detected gcc-$GCC_VERSION"
                
                # Check if matching g++ version exists
                if command -v g++-$GCC_VERSION &> /dev/null; then
                    print_info "✓ g++-$GCC_VERSION already available"
                else
                    if [ "$AUTO_YES" = true ]; then
                        INSTALL_GPP="y"
                    else
                        read -p "Install g++-$GCC_VERSION to match gcc-$GCC_VERSION? (y/n): " INSTALL_GPP
                    fi
                    
                    if [[ "$INSTALL_GPP" =~ ^[Yy]$ ]]; then
                        print_info "Installing g++-$GCC_VERSION to match gcc-$GCC_VERSION..."
                        if [ "$OS_TYPE" = "ubuntu" ]; then
                            if sudo NEEDRESTART_MODE=l apt install -y g++-$GCC_VERSION; then
                                print_info "✓ g++-$GCC_VERSION installed"
                                
                                # Ask about setting as default
                                if [ "$AUTO_YES" = true ]; then
                                    SET_DEFAULT="y"
                                else
                                    read -p "Set g++-$GCC_VERSION as default g++ compiler? (y/n): " SET_DEFAULT
                                fi
                                
                                if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
                                    if sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100; then
                                        print_info "✓ Set g++-$GCC_VERSION as default g++ compiler"
                                    else
                                        print_warning "Could not set g++-$GCC_VERSION as default"
                                    fi
                                else
                                    print_info "Skipped setting g++-$GCC_VERSION as default"
                                fi
                            else
                                print_warning "Could not install g++-$GCC_VERSION - CUDA compilation may fail"
                            fi
                        elif [ "$OS_TYPE" = "rhel" ]; then
                            # RHEL variants typically have matching gcc/g++ versions in the gcc-c++ package
                            print_info "✓ gcc-c++ package provides matching g++ version"
                        fi
                    else
                        print_warning "Skipped g++-$GCC_VERSION installation - CUDA compilation may fail"
                    fi
                fi
            fi
        fi
        
        # Install/Upgrade CUDA toolkit if missing or needs upgrade
        if [ "$CUDA_MISSING" = true ] && [ "$INSTALL_SUCCESS" = true ]; then
            echo ""
            
            # Always target CUDA 12.9 for upgrades/installs
            TARGET_CUDA_VERSION="12.9"
            
            # Check if driver supports CUDA 12.9
            if [ -n "$DRIVER_CUDA_VERSION" ]; then
                DRIVER_CUDA_MAJOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f1)
                DRIVER_CUDA_MINOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f2)
                
                print_info "Driver supports CUDA $DRIVER_CUDA_VERSION"
                
                if [ "$DRIVER_CUDA_MAJOR" -lt 12 ] || ([ "$DRIVER_CUDA_MAJOR" -eq 12 ] && [ "$DRIVER_CUDA_MINOR" -lt 9 ]); then
                    print_warning "Driver only supports CUDA $DRIVER_CUDA_VERSION, which is older than 12.9"
                    print_warning "CUDA 12.9 installation may fail. Consider updating your NVIDIA driver first."
                    # Still attempt to install 12.9 as it might work with newer runtime compatibility
                fi
            else
                print_info "No driver version detected, will attempt CUDA 12.9 installation"
            fi
            
            if command -v nvcc &> /dev/null; then
                print_info "Will upgrade from CUDA $CUDA_VERSION to $TARGET_CUDA_VERSION"
            else
                print_info "Will install CUDA toolkit version: $TARGET_CUDA_VERSION"
            fi
            
            if [ "$AUTO_YES" = true ]; then
                INSTALL_CUDA="y"
            else
                print_warning "CUDA toolkit $TARGET_CUDA_VERSION is large (~4GB). Install it?"
                read -p "Install CUDA toolkit $TARGET_CUDA_VERSION? (y/n): " INSTALL_CUDA
            fi
            
            if [[ "$INSTALL_CUDA" =~ ^[Yy]$ ]]; then
                print_info "Installing CUDA toolkit $TARGET_CUDA_VERSION..."
                
                if [ "$OS_TYPE" = "ubuntu" ]; then
                        
                    # Generate potential repo versions to try
                    # Format: ubuntu<YY><MM> where YY is year (last 2 digits) and MM is month
                    VERSION_YEAR=$(echo $VERSION_ID | cut -d. -f1)
                    VERSION_MONTH=$(echo $VERSION_ID | cut -d. -f2)
                    
                    # Build list of versions to try
                    CUDA_REPO_VERSIONS=()
                    
                    # First, try exact version match
                    CUDA_REPO_VERSIONS+=("ubuntu${VERSION_YEAR}${VERSION_MONTH}")
                    
                    # For future-proofing, try previous LTS versions in descending order
                    # Start from current version and go back to 22.04
                    for year in $(seq $VERSION_YEAR -2 22); do
                        if [ $year -eq $VERSION_YEAR ]; then
                            # For current year, try months from current back to 04
                            for month in $(seq $VERSION_MONTH -2 4); do
                                [ $month -lt 10 ] && month="0$month"
                                CUDA_REPO_VERSIONS+=("ubuntu${year}${month}")
                            done
                        else
                            # For previous years, only try LTS versions (04 and 10)
                            CUDA_REPO_VERSIONS+=("ubuntu${year}10")
                            CUDA_REPO_VERSIONS+=("ubuntu${year}04")
                        fi
                    done
                    
                    # Remove duplicates while preserving order
                    CUDA_REPO_VERSIONS=($(echo "${CUDA_REPO_VERSIONS[@]}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' '))
                    
                    print_info "Will try CUDA repositories in order: ${CUDA_REPO_VERSIONS[*]}"
                    
                elif [ "$OS_TYPE" = "rhel" ]; then
                    print_info "Detecting appropriate CUDA repository for $NAME $VERSION_ID..."
                    
                    # For RHEL variants, use rhel9 repository
                    CUDA_REPO_VERSIONS=("rhel9" "rhel8")
                    print_info "Will try CUDA repositories in order: ${CUDA_REPO_VERSIONS[*]}"
                fi
                
                # Use temp directory for downloads
                TEMP_DEB="/tmp/cuda-keyring_$$.deb"
                trap "rm -f $TEMP_DEB" EXIT  # Ensure cleanup on script exit
                
                # Try each repo version until one works
                CUDA_INSTALLED=false
                for REPO_VERSION in "${CUDA_REPO_VERSIONS[@]}"; do
                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/cuda-keyring_1.0-1_all.deb"
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/cuda-${REPO_VERSION}.repo"
                    fi
                    print_info "Trying CUDA repository: $REPO_VERSION"
                    
                    # Clean up any previous attempts
                    rm -f "$TEMP_DEB"
                    
                    # Download and install based on OS type
                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        if wget --timeout=30 --tries=2 -O "$TEMP_DEB" "$CUDA_KEYRING_URL" 2>/dev/null; then
                            # Verify it's actually a .deb file
                            if file "$TEMP_DEB" | grep -q "Debian binary package"; then
                                print_info "Valid CUDA keyring downloaded from $REPO_VERSION repository"
                                
                                sudo dpkg -i "$TEMP_DEB"
                                if [ $? -eq 0 ]; then
                                    rm -f "$TEMP_DEB"
                                    REPO_CONFIGURED=true
                                else
                                    print_warning "Failed to install CUDA keyring"
                                    REPO_CONFIGURED=false
                                fi
                            else
                                print_info "Downloaded file is not a valid .deb package"
                                REPO_CONFIGURED=false
                            fi
                        else
                            print_info "Repository $REPO_VERSION not available"
                            REPO_CONFIGURED=false
                        fi
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        # For RHEL variants, download and install the repo file
                        if wget --timeout=30 --tries=2 -O /tmp/cuda.repo "$CUDA_REPO_URL" 2>/dev/null; then
                            # Install the repo file
                            sudo cp /tmp/cuda.repo /etc/yum.repos.d/cuda.repo
                            rm -f /tmp/cuda.repo
                            REPO_CONFIGURED=true
                        else
                            print_info "Repository $REPO_VERSION not available"
                            REPO_CONFIGURED=false
                        fi
                    fi
                    
                    if [ "$REPO_CONFIGURED" = true ]; then
                                
                        # Update package lists
                        print_info "Updating package lists..."
                        if [ "$OS_TYPE" = "ubuntu" ]; then
                            sudo apt update
                        elif [ "$OS_TYPE" = "rhel" ]; then
                            sudo dnf makecache
                        fi
                        
                        if [ $? -eq 0 ]; then
                            # Try to install CUDA toolkit
                            print_info "Installing CUDA toolkit (this may take a while)..."
                            
                            # First check what CUDA packages are available
                            print_info "Checking available CUDA versions..."
                            if [ "$OS_TYPE" = "ubuntu" ]; then
                                AVAILABLE_CUDA=$(apt-cache search cuda-toolkit | grep -E "^cuda-toolkit" | head -5)
                            elif [ "$OS_TYPE" = "rhel" ]; then
                                AVAILABLE_CUDA=$(dnf search cuda-toolkit 2>/dev/null | grep -E "^cuda-toolkit" | head -5)
                            fi
                            if [ -n "$AVAILABLE_CUDA" ]; then
                                print_info "Available CUDA packages:"
                                echo "$AVAILABLE_CUDA"
                            fi
                                    
                            # Try to install the target CUDA version
                            # Convert TARGET_CUDA_VERSION (e.g., "12.3") to package format (e.g., "12-3")
                            CUDA_PKG_VERSION=$(echo $TARGET_CUDA_VERSION | sed 's/\./-/')
                            
                            print_info "Attempting to install cuda-toolkit-$CUDA_PKG_VERSION..."
                            
                            # First try the specific version we want
                            if [ "$OS_TYPE" = "ubuntu" ]; then
                                if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit-$CUDA_PKG_VERSION 2>/dev/null; then
                                    print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                                    CUDA_INSTALLED=true
                                else
                                    INSTALL_CMD="sudo NEEDRESTART_MODE=l apt install -y"
                                    CUDA_INSTALLED=false
                                fi
                            elif [ "$OS_TYPE" = "rhel" ]; then
                                if sudo dnf install -y cuda-toolkit-$CUDA_PKG_VERSION 2>/dev/null; then
                                    print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                                    CUDA_INSTALLED=true
                                else
                                    INSTALL_CMD="sudo dnf install -y"
                                    CUDA_INSTALLED=false
                                fi
                            fi
                            
                            if [ "$CUDA_INSTALLED" = false ]; then
                                print_warning "cuda-toolkit-$CUDA_PKG_VERSION not available, trying fallback versions..."
                                
                                # Fallback strategy based on target version
                                # Try versions close to target, working backwards
                                if [ "$TARGET_CUDA_VERSION" = "12.9" ]; then
                                    # Try 12.6, 12.3, 12.2 as fallbacks
                                    for fallback in "12-6" "12-3" "12-2"; do
                                        if $INSTALL_CMD cuda-toolkit-$fallback 2>/dev/null; then
                                            print_info "✓ CUDA toolkit $(echo $fallback | sed 's/-/./') installed successfully (fallback)"
                                            CUDA_INSTALLED=true
                                            break
                                        fi
                                    done
                                elif [ "$TARGET_CUDA_VERSION" = "12.6" ]; then
                                    # Try 12.3, 12.2 as fallbacks
                                    for fallback in "12-3" "12-2"; do
                                        if $INSTALL_CMD cuda-toolkit-$fallback 2>/dev/null; then
                                            print_info "✓ CUDA toolkit $(echo $fallback | sed 's/-/./') installed successfully (fallback)"
                                            CUDA_INSTALLED=true
                                            break
                                        fi
                                    done
                                elif [ "$TARGET_CUDA_VERSION" = "12.3" ]; then
                                    # Try 12.2, 12.1 as fallbacks
                                    for fallback in "12-2" "12-1"; do
                                        if $INSTALL_CMD cuda-toolkit-$fallback 2>/dev/null; then
                                            print_info "✓ CUDA toolkit $(echo $fallback | sed 's/-/./') installed successfully (fallback)"
                                            CUDA_INSTALLED=true
                                            break
                                        fi
                                    done
                                elif [ "$TARGET_CUDA_VERSION" = "12.2" ]; then
                                    # Try 12.1 as fallback
                                    if $INSTALL_CMD cuda-toolkit-12-1 2>/dev/null; then
                                        print_info "✓ CUDA toolkit 12.1 installed successfully (fallback)"
                                        CUDA_INSTALLED=true
                                    fi
                                elif [ "$TARGET_CUDA_VERSION" = "11.8" ]; then
                                    # No fallback for 11.8, it's already our minimum
                                    print_warning "Could not install CUDA toolkit 11.8"
                                fi
                                
                                # Last resort: try generic cuda-toolkit if nothing else worked
                                if [ "$CUDA_INSTALLED" = false ]; then
                                    print_info "Trying generic cuda-toolkit package as last resort..."
                                    if $INSTALL_CMD cuda-toolkit 2>/dev/null; then
                                        print_info "✓ CUDA toolkit installed successfully (generic version)"
                                        CUDA_INSTALLED=true
                                    fi
                                fi
                            fi
                                    
                            if [ "$CUDA_INSTALLED" = false ]; then
                                print_warning "Could not install CUDA toolkit from $REPO_VERSION repository"
                            fi
                            
                            if [ "$CUDA_INSTALLED" = true ]; then
                                # Add CUDA to PATH if not already there
                                if ! grep -q "/usr/local/cuda/bin" ~/.bashrc; then
                                    if [ "$AUTO_YES" = true ]; then
                                        ADD_CUDA_PATH="y"
                                    else
                                        read -p "Add CUDA to PATH in ~/.bashrc? (y/n): " ADD_CUDA_PATH
                                    fi
                                    
                                    if [[ "$ADD_CUDA_PATH" =~ ^[Yy]$ ]]; then
                                        echo '' >> ~/.bashrc
                                        echo '# CUDA toolkit' >> ~/.bashrc
                                        echo 'export PATH="/usr/local/cuda/bin:$PATH"' >> ~/.bashrc
                                        echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc
                                        print_info "Added CUDA to PATH in ~/.bashrc"
                                        print_info "Run 'source ~/.bashrc' or start a new terminal to use nvcc"
                                    else
                                        print_info "Skipped adding CUDA to PATH"
                                        print_info "You can manually add /usr/local/cuda/bin to your PATH later"
                                    fi
                                fi
                                break
                            fi
                        else
                            print_warning "Failed to update package lists after adding CUDA repo"
                        fi
                    fi
                done
                
                # Clean up temp file
                rm -f "$TEMP_DEB"
                
                if [ "$CUDA_INSTALLED" = false ]; then
                    print_error "Failed to install CUDA toolkit automatically"
                    print_info "You may need to install it manually from:"
                    print_info "https://developer.nvidia.com/cuda-downloads"
                    print_info ""
                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        print_info "Select: Linux > x86_64 > Ubuntu > $VERSION_MAJOR > deb (network)"
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        print_info "Select: Linux > x86_64 > RHEL > $VERSION_MAJOR > rpm (network)"
                    fi
                    INSTALL_SUCCESS=false
                fi
            fi
        fi
        
        echo ""
        if [ "$INSTALL_SUCCESS" = true ]; then
            print_info "✅ Installation complete!"
        else
            print_error "❌ Installation had errors - check messages above"
            exit 1
        fi
    else
        print_info "Skipping installation. Run with -y flag to auto-install."
    fi
fi

#!/bin/bash
# Script: check_dependencies.sh
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
# Check Ubuntu version first
print_info "Checking Ubuntu version..."
if [ ! -f /etc/os-release ]; then
    print_error "Cannot determine OS version. /etc/os-release not found."
    exit 1
fi
source /etc/os-release
VERSION_MAJOR=$(echo $VERSION_ID | cut -d. -f1)
if [ "$ID" != "ubuntu" ] || [ "$VERSION_MAJOR" -lt 22 ]; then
    print_error "This script requires Ubuntu 22.04 or newer. Detected: $ID $VERSION_ID"
    exit 1
fi
print_info "✓ Ubuntu $VERSION_ID detected"
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
# System packages
SYSTEM_PACKAGES=(
    # Essential build tools
    "build-essential"
    "gcc"
    "g++"
    "make"
    "cmake"
    
    # Linear algebra libraries
    "libopenblas-dev"
    "libblas-dev"
    "liblapack-dev"
    "libatlas-base-dev"
    "gfortran"
    
    # NUMA optimization
    "numactl"
    "libnuma-dev"
    
    # Image processing
    "libjpeg-dev"
    "libpng-dev"
    "libtiff-dev"
    "libavcodec-dev"
    "libavformat-dev"
    "libswscale-dev"
    
    # Other dependencies
    "libhdf5-dev"
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
    "tmux"
    "pkg-config"
)
# Check packages
print_info "Checking system dependencies..."
MISSING_PACKAGES=()
for pkg in "${SYSTEM_PACKAGES[@]}"; do
    if dpkg -l 2>/dev/null | grep -q "^ii  $pkg"; then
        print_info "  ✓ $pkg"
    else
        print_error "  ✗ $pkg"
        MISSING_PACKAGES+=($pkg)
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
    print_info "  Will default to CUDA 12.3 for H100/H200 compatibility"
fi

# Check for CUDA toolkit (nvcc)
CUDA_MISSING=false
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
    print_info "  ✓ CUDA toolkit (nvcc) - version $CUDA_VERSION"
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
        print_warning "CUDA toolkit (nvcc) not found - required for GPU-optimized packages"
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
                print_info "Cleaning apt cache to free space..."
                sudo apt clean
            fi
            
            # Prevent service restarts
            print_info "Note: Using NEEDRESTART_MODE=l to prevent automatic service restarts"
            sudo NEEDRESTART_MODE=l apt update
            
            if [ $? -ne 0 ]; then
                print_error "apt update failed - check your internet connection and disk space"
                INSTALL_SUCCESS=false
            else
                sudo NEEDRESTART_MODE=l apt install -y ${MISSING_PACKAGES[*]}
                
                if [ $? -ne 0 ]; then
                    print_error "Failed to install some packages"
                    INSTALL_SUCCESS=false
                fi
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
                    print_info "Installing g++-$GCC_VERSION to match gcc-$GCC_VERSION..."
                    if sudo NEEDRESTART_MODE=l apt install -y g++-$GCC_VERSION; then
                        print_info "✓ g++-$GCC_VERSION installed"
                        
                        # Set as default g++ compiler for CUDA compatibility
                        if sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100; then
                            print_info "✓ Set g++-$GCC_VERSION as default g++ compiler"
                        else
                            print_warning "Could not set g++-$GCC_VERSION as default"
                        fi
                    else
                        print_warning "Could not install g++-$GCC_VERSION - CUDA compilation may fail"
                    fi
                fi
            fi
        fi
        
        # Install CUDA toolkit if missing
        if [ "$CUDA_MISSING" = true ] && [ "$INSTALL_SUCCESS" = true ]; then
            echo ""
            
            # Determine which CUDA version to install based on driver
            TARGET_CUDA_VERSION=""
            if [ -n "$DRIVER_CUDA_VERSION" ]; then
                # Extract major.minor version from driver's supported CUDA
                DRIVER_CUDA_MAJOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f1)
                DRIVER_CUDA_MINOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f2)
                
                print_info "Driver supports CUDA $DRIVER_CUDA_VERSION"
                
                # Map driver CUDA version to available toolkit versions
                # We'll try to install the highest compatible version
                if [ "$DRIVER_CUDA_MAJOR" -ge 13 ]; then
                    TARGET_CUDA_VERSION="13.0"
                elif [ "$DRIVER_CUDA_MAJOR" -eq 12 ]; then
                    if [ "$DRIVER_CUDA_MINOR" -ge 9 ]; then
                        TARGET_CUDA_VERSION="12.9"
                    elif [ "$DRIVER_CUDA_MINOR" -ge 6 ]; then
                        TARGET_CUDA_VERSION="12.6"
                    elif [ "$DRIVER_CUDA_MINOR" -ge 3 ]; then
                        TARGET_CUDA_VERSION="12.3"
                    elif [ "$DRIVER_CUDA_MINOR" -ge 2 ]; then
                        TARGET_CUDA_VERSION="12.2"
                    elif [ "$DRIVER_CUDA_MINOR" -ge 1 ]; then
                        TARGET_CUDA_VERSION="12.1"
                    else
                        TARGET_CUDA_VERSION="12.0"
                    fi
                elif [ "$DRIVER_CUDA_MAJOR" -eq 11 ]; then
                    TARGET_CUDA_VERSION="11.8"
                else
                    print_warning "Driver CUDA version $DRIVER_CUDA_VERSION is very old"
                    TARGET_CUDA_VERSION="11.8"
                fi
            else
                # No driver detected or couldn't determine version
                # Default to CUDA 12.3 for modern GPUs like H100/H200
                print_info "No driver version detected, defaulting to CUDA 12.3 for H100/H200 compatibility"
                TARGET_CUDA_VERSION="12.3"
            fi
            
            print_info "Target CUDA toolkit version: $TARGET_CUDA_VERSION"
            
            if [ "$AUTO_YES" = true ]; then
                INSTALL_CUDA="y"
            else
                print_warning "CUDA toolkit $TARGET_CUDA_VERSION is large (~4GB). Install it?"
                read -p "Install CUDA toolkit $TARGET_CUDA_VERSION? (y/n): " INSTALL_CUDA
            fi
            
            if [[ "$INSTALL_CUDA" =~ ^[Yy]$ ]]; then
                print_info "Installing CUDA toolkit $TARGET_CUDA_VERSION..."
                print_info "Detecting appropriate CUDA repository for Ubuntu $VERSION_ID..."
                
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
                
                # Use temp directory for downloads
                TEMP_DEB="/tmp/cuda-keyring_$$.deb"
                trap "rm -f $TEMP_DEB" EXIT  # Ensure cleanup on script exit
                
                # Try each repo version until one works
                CUDA_INSTALLED=false
                for UBUNTU_VERSION in "${CUDA_REPO_VERSIONS[@]}"; do
                    CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${UBUNTU_VERSION}/x86_64/cuda-keyring_1.0-1_all.deb"
                    print_info "Trying CUDA repository: $UBUNTU_VERSION"
                    
                    # Clean up any previous attempts
                    rm -f "$TEMP_DEB"
                    
                    # Download with better error checking
                    if wget --timeout=30 --tries=2 -O "$TEMP_DEB" "$CUDA_KEYRING_URL" 2>/dev/null; then
                        # Verify it's actually a .deb file
                        if file "$TEMP_DEB" | grep -q "Debian binary package"; then
                            print_info "Valid CUDA keyring downloaded from $UBUNTU_VERSION repository"
                            
                            sudo dpkg -i "$TEMP_DEB"
                            if [ $? -eq 0 ]; then
                                rm -f "$TEMP_DEB"
                                
                                # Update package lists
                                print_info "Updating package lists..."
                                sudo apt update
                                if [ $? -eq 0 ]; then
                                    # Try to install CUDA toolkit
                                    print_info "Installing CUDA toolkit (this may take a while)..."
                                    
                                    # First check what CUDA packages are available
                                    print_info "Checking available CUDA versions..."
                                    AVAILABLE_CUDA=$(apt-cache search cuda-toolkit | grep -E "^cuda-toolkit" | head -5)
                                    if [ -n "$AVAILABLE_CUDA" ]; then
                                        print_info "Available CUDA packages:"
                                        echo "$AVAILABLE_CUDA"
                                    fi
                                    
                                    # Try to install the target CUDA version
                                    # Convert TARGET_CUDA_VERSION (e.g., "12.3") to package format (e.g., "12-3")
                                    CUDA_PKG_VERSION=$(echo $TARGET_CUDA_VERSION | sed 's/\./-/')
                                    
                                    print_info "Attempting to install cuda-toolkit-$CUDA_PKG_VERSION..."
                                    
                                    # First try the specific version we want
                                    if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit-$CUDA_PKG_VERSION 2>/dev/null; then
                                        print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                                        CUDA_INSTALLED=true
                                    else
                                        print_warning "cuda-toolkit-$CUDA_PKG_VERSION not available, trying fallback versions..."
                                        
                                        # Fallback strategy based on target version
                                        # Try versions close to target, working backwards
                                        if [ "$TARGET_CUDA_VERSION" = "12.9" ]; then
                                            # Try 12.6, 12.3, 12.2 as fallbacks
                                            for fallback in "12-6" "12-3" "12-2"; do
                                                if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit-$fallback 2>/dev/null; then
                                                    print_info "✓ CUDA toolkit $(echo $fallback | sed 's/-/./') installed successfully (fallback)"
                                                    CUDA_INSTALLED=true
                                                    break
                                                fi
                                            done
                                        elif [ "$TARGET_CUDA_VERSION" = "12.6" ]; then
                                            # Try 12.3, 12.2 as fallbacks
                                            for fallback in "12-3" "12-2"; do
                                                if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit-$fallback 2>/dev/null; then
                                                    print_info "✓ CUDA toolkit $(echo $fallback | sed 's/-/./') installed successfully (fallback)"
                                                    CUDA_INSTALLED=true
                                                    break
                                                fi
                                            done
                                        elif [ "$TARGET_CUDA_VERSION" = "12.3" ]; then
                                            # Try 12.2, 12.1 as fallbacks
                                            for fallback in "12-2" "12-1"; do
                                                if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit-$fallback 2>/dev/null; then
                                                    print_info "✓ CUDA toolkit $(echo $fallback | sed 's/-/./') installed successfully (fallback)"
                                                    CUDA_INSTALLED=true
                                                    break
                                                fi
                                            done
                                        elif [ "$TARGET_CUDA_VERSION" = "12.2" ]; then
                                            # Try 12.1 as fallback
                                            if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit-12-1 2>/dev/null; then
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
                                            if sudo NEEDRESTART_MODE=l apt install -y cuda-toolkit 2>/dev/null; then
                                                print_info "✓ CUDA toolkit installed successfully (generic version)"
                                                CUDA_INSTALLED=true
                                            fi
                                        fi
                                    fi
                                    
                                    if [ "$CUDA_INSTALLED" = false ]; then
                                        print_warning "Could not install CUDA toolkit from $UBUNTU_VERSION repository"
                                    fi
                                    
                                    if [ "$CUDA_INSTALLED" = true ]; then
                                        # Add CUDA to PATH if not already there
                                        if ! grep -q "/usr/local/cuda/bin" ~/.bashrc; then
                                            echo '' >> ~/.bashrc
                                            echo '# CUDA toolkit' >> ~/.bashrc
                                            echo 'export PATH="/usr/local/cuda/bin:$PATH"' >> ~/.bashrc
                                            echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc
                                            print_info "Added CUDA to PATH in ~/.bashrc"
                                            print_info "Run 'source ~/.bashrc' or start a new terminal to use nvcc"
                                        fi
                                        break
                                    fi
                                else
                                    print_warning "Failed to update apt after adding CUDA repo"
                                fi
                            else
                                print_warning "Failed to install CUDA keyring"
                            fi
                        else
                            print_info "Downloaded file is not a valid .deb package"
                        fi
                    else
                        print_info "Repository $UBUNTU_VERSION not available"
                    fi
                done
                
                # Clean up temp file
                rm -f "$TEMP_DEB"
                
                if [ "$CUDA_INSTALLED" = false ]; then
                    print_error "Failed to install CUDA toolkit automatically"
                    print_info "You may need to install it manually from:"
                    print_info "https://developer.nvidia.com/cuda-downloads"
                    print_info ""
                    print_info "Select: Linux > x86_64 > Ubuntu > $VERSION_MAJOR > deb (network)"
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

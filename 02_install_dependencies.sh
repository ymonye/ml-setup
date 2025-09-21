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

# Detect the highest CUDA toolkit version available in the provided repositories
detect_latest_cuda_version() {
    local repo_list=("$@")
    local version_candidates=""

    if ! command -v curl &> /dev/null; then
        echo ""
        return 1
    fi

    for repo in "${repo_list[@]}"; do
        if [ -z "$repo" ]; then
            continue
        fi

        if [ "$OS_TYPE" = "ubuntu" ]; then
            local packages_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/Packages"
            version_candidates=$(curl -fsSL "$packages_url" 2>/dev/null | \
                grep -oP '^Package: cuda-toolkit-\K[0-9]+-[0-9]+$' | \
                tr '-' '.' | \
                sort -V | uniq)
        elif [ "$OS_TYPE" = "rhel" ]; then
            local primary_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/repodata/primary.xml.gz"
            version_candidates=$(curl -fsSL "$primary_url" 2>/dev/null | \
                gzip -dc 2>/dev/null | \
                grep -oP '<name>cuda-toolkit-\K[0-9]+-[0-9]+' | \
                tr '-' '.' | \
                sort -V | uniq)
        fi

        if [ -n "$version_candidates" ]; then
            echo "$version_candidates" | tail -1
            return 0
        fi
    done

    echo ""
    return 1
}

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
    PKG_INSTALL_CMD="NEEDRESTART_MODE=l apt install -y"
    PKG_UPDATE_CMD="NEEDRESTART_MODE=l apt update"
    PKG_QUERY_CMD="dpkg -l"
    print_info "✓ Ubuntu $VERSION_ID detected"
elif [[ "$ID" =~ ^(rhel|rocky|almalinux)$ ]]; then
    if [ "$VERSION_MAJOR" -lt 9 ]; then
        print_error "This script requires RHEL/Rocky/AlmaLinux 9 or newer. Detected: $ID $VERSION_ID"
        exit 1
    fi
    OS_TYPE="rhel"
    PKG_MANAGER="dnf"
    PKG_INSTALL_CMD="dnf install -y"
    PKG_UPDATE_CMD="dnf makecache"
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
    print_info "Free up space with: apt clean"
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
        "pkg-config"

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
    )
elif [ "$OS_TYPE" = "rhel" ]; then
    SYSTEM_PACKAGES=(
        # Essential build tools
        "gcc"
        "gcc-c++"
        "make"
        "cmake"
        "pkgconf-pkg-config"

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
        print_info "  ✓ CUDA version $CUDA_VERSION meets the recommended baseline"
    else
        print_info "  CUDA version $CUDA_VERSION detected; upgrade options will be offered"
        CUDA_MISSING=true  # Treat as missing to trigger upgrade menu
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
            print_info "CUDA toolkit upgrade options available"
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
                    apt clean
                else
                    print_warning "Proceeding without cleaning apt cache - installation may fail if space runs out"
                fi
            fi
            
            # Update package lists
            if [ "$OS_TYPE" = "ubuntu" ]; then
                print_info "Note: Using NEEDRESTART_MODE=l to prevent automatic service restarts"
                NEEDRESTART_MODE=l apt update
            elif [ "$OS_TYPE" = "rhel" ]; then
                dnf makecache
            fi
            
            if [ $? -ne 0 ]; then
                print_error "Package update failed - check your internet connection and disk space"
                INSTALL_SUCCESS=false
            else
                if [ "$OS_TYPE" = "ubuntu" ]; then
                    NEEDRESTART_MODE=l apt install -y ${MISSING_PACKAGES[*]}
                elif [ "$OS_TYPE" = "rhel" ]; then
                    dnf install -y ${MISSING_PACKAGES[*]}
                fi
                
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
                    if [ "$AUTO_YES" = true ]; then
                        INSTALL_GPP="y"
                    else
                        read -p "Install g++-$GCC_VERSION to match gcc-$GCC_VERSION? (y/n): " INSTALL_GPP
                    fi
                    
                    if [[ "$INSTALL_GPP" =~ ^[Yy]$ ]]; then
                        print_info "Installing g++-$GCC_VERSION to match gcc-$GCC_VERSION..."
                        if [ "$OS_TYPE" = "ubuntu" ]; then
                            if NEEDRESTART_MODE=l apt install -y g++-$GCC_VERSION; then
                                print_info "✓ g++-$GCC_VERSION installed"
                                
                                # Ask about setting as default
                                if [ "$AUTO_YES" = true ]; then
                                    SET_DEFAULT="y"
                                else
                                    read -p "Set g++-$GCC_VERSION as default g++ compiler? (y/n): " SET_DEFAULT
                                fi
                                
                                if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
                                    if update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100; then
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

            TARGET_CUDA_VERSION_DEFAULT="12.9"
            TARGET_CUDA_VERSION=""
            CUDA_INSTALL_REQUESTED=false

            CURRENT_CUDA_DISPLAY="None"
            if command -v nvcc &> /dev/null; then
                CURRENT_CUDA_DISPLAY="$CUDA_VERSION"
            fi

            if [ -n "$DRIVER_CUDA_VERSION" ]; then
                print_info "Driver reports CUDA compatibility up to version $DRIVER_CUDA_VERSION"
            else
                print_info "No NVIDIA driver version detected; proceeding without driver compatibility data"
            fi

            if [ "$OS_TYPE" = "ubuntu" ]; then
                VERSION_YEAR=$(echo $VERSION_ID | cut -d. -f1)
                VERSION_MONTH=$(echo $VERSION_ID | cut -d. -f2)
                CUDA_REPO_VERSIONS=("ubuntu${VERSION_YEAR}${VERSION_MONTH}")
                for year in $(seq $VERSION_YEAR -2 22); do
                    if [ $year -eq $VERSION_YEAR ]; then
                        for month in $(seq $VERSION_MONTH -2 4); do
                            [ $month -lt 10 ] && month="0$month"
                            CUDA_REPO_VERSIONS+=("ubuntu${year}${month}")
                        done
                    else
                        CUDA_REPO_VERSIONS+=("ubuntu${year}10")
                        CUDA_REPO_VERSIONS+=("ubuntu${year}04")
                    fi
                done
            elif [ "$OS_TYPE" = "rhel" ]; then
                CUDA_REPO_VERSIONS=("rhel9" "rhel8")
            else
                CUDA_REPO_VERSIONS=()
            fi

            if [ ${#CUDA_REPO_VERSIONS[@]} -gt 0 ]; then
                CUDA_REPO_VERSIONS=($(printf "%s\n" "${CUDA_REPO_VERSIONS[@]}" | awk '!seen[$0]++'))
                print_info "Will try CUDA repositories in order: ${CUDA_REPO_VERSIONS[*]}"
            fi

            LATEST_CUDA_VERSION=$(detect_latest_cuda_version "${CUDA_REPO_VERSIONS[@]}")
            if [ -z "$LATEST_CUDA_VERSION" ]; then
                print_warning "Unable to determine the latest CUDA version automatically; defaulting to $TARGET_CUDA_VERSION_DEFAULT."
                LATEST_CUDA_VERSION="$TARGET_CUDA_VERSION_DEFAULT"
            else
                print_info "Latest CUDA version detected from repositories: $LATEST_CUDA_VERSION"
            fi

            if [ "$AUTO_YES" = true ]; then
                CUDA_INSTALL_REQUESTED=true
                TARGET_CUDA_VERSION="$LATEST_CUDA_VERSION"
                print_info "Automatic mode enabled (-y): selecting CUDA $TARGET_CUDA_VERSION for installation."
            else
                print_info "Current CUDA version: $CURRENT_CUDA_DISPLAY"
                echo "Choose CUDA installation option:"
                echo "  1) Keep current version"
                echo "  2) Install latest version ($LATEST_CUDA_VERSION)"
                echo "  3) Install custom version"
                read -p "Enter choice (1/2/3): " CUDA_CHOICE
                while [[ ! "$CUDA_CHOICE" =~ ^[123]$ ]]; do
                    read -p "Please enter 1, 2, or 3: " CUDA_CHOICE
                done
                case $CUDA_CHOICE in
                    1)
                        CUDA_INSTALL_REQUESTED=false
                        if [ "$CURRENT_CUDA_DISPLAY" = "None" ]; then
                            print_warning "CUDA toolkit remains uninstalled. GPU-accelerated workflows will not be available."
                        else
                            print_info "Keeping existing CUDA toolkit ($CURRENT_CUDA_DISPLAY)."
                        fi
                        ;;
                    2)
                        CUDA_INSTALL_REQUESTED=true
                        TARGET_CUDA_VERSION="$LATEST_CUDA_VERSION"
                        ;;
                    3)
                        while true; do
                            read -p "Enter desired CUDA version (e.g. 12.4): " CUSTOM_VERSION
                            if [[ "$CUSTOM_VERSION" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                                if [[ "$CUSTOM_VERSION" =~ ^[0-9]+$ ]]; then
                                    CUSTOM_VERSION="${CUSTOM_VERSION}.0"
                                fi
                                TARGET_CUDA_VERSION="$CUSTOM_VERSION"
                                CUDA_INSTALL_REQUESTED=true
                                break
                            else
                                print_error "Invalid version number. Please enter a numeric value like 12.4"
                            fi
                        done
                        ;;
                esac
            fi

            if [ "$CUDA_INSTALL_REQUESTED" = true ]; then
                if [ -z "$TARGET_CUDA_VERSION" ]; then
                    TARGET_CUDA_VERSION="$TARGET_CUDA_VERSION_DEFAULT"
                fi

                TARGET_CUDA_MAJOR=$(echo $TARGET_CUDA_VERSION | cut -d. -f1)
                TARGET_CUDA_MINOR=$(echo $TARGET_CUDA_VERSION | cut -d. -f2)
                TARGET_CUDA_MINOR=${TARGET_CUDA_MINOR:-0}

                if [ -n "$DRIVER_CUDA_VERSION" ]; then
                    DRIVER_CUDA_MAJOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f1)
                    DRIVER_CUDA_MINOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f2)
                    if [ "$TARGET_CUDA_MAJOR" -gt "$DRIVER_CUDA_MAJOR" ] || { [ "$TARGET_CUDA_MAJOR" -eq "$DRIVER_CUDA_MAJOR" ] && [ "$TARGET_CUDA_MINOR" -gt "$DRIVER_CUDA_MINOR" ]; }; then
                        print_warning "Selected CUDA version $TARGET_CUDA_VERSION may exceed driver support ($DRIVER_CUDA_VERSION). Installation may fail unless the driver is updated."
                    else
                        print_info "Driver support check passed for CUDA $TARGET_CUDA_VERSION."
                    fi
                else
                    print_warning "Driver capabilities unknown; proceeding with CUDA $TARGET_CUDA_VERSION."
                fi

                TEMP_DEB="/tmp/cuda-keyring_$$.deb"
                trap "rm -f $TEMP_DEB" EXIT

                CUDA_INSTALLED=false
                for REPO_VERSION in "${CUDA_REPO_VERSIONS[@]}"; do
                    [ -z "$REPO_VERSION" ] && continue
                    print_info "Trying CUDA repository: $REPO_VERSION"

                    rm -f "$TEMP_DEB"
                    REPO_CONFIGURED=false

                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/cuda-keyring_1.0-1_all.deb"
                        if wget --timeout=30 --tries=2 -O "$TEMP_DEB" "$CUDA_KEYRING_URL" 2>/dev/null; then
                            if file "$TEMP_DEB" | grep -q "Debian binary package"; then
                                if dpkg -i "$TEMP_DEB"; then
                                    REPO_CONFIGURED=true
                                else
                                    print_warning "Failed to install CUDA keyring from $REPO_VERSION"
                                fi
                            else
                                print_warning "Downloaded file from $REPO_VERSION is not a valid .deb package"
                            fi
                        else
                            print_info "Repository $REPO_VERSION not reachable"
                        fi
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/cuda-${REPO_VERSION}.repo"
                        if wget --timeout=30 --tries=2 -O /tmp/cuda.repo "$CUDA_REPO_URL" 2>/dev/null; then
                            if cp /tmp/cuda.repo /etc/yum.repos.d/cuda.repo; then
                                REPO_CONFIGURED=true
                            fi
                            rm -f /tmp/cuda.repo
                        else
                            print_info "Repository $REPO_VERSION not reachable"
                        fi
                    fi

                    if [ "$REPO_CONFIGURED" = true ]; then
                        print_info "Updating package lists..."
                        if [ "$OS_TYPE" = "ubuntu" ]; then
                            apt update
                        else
                            dnf makecache
                        fi

                        if [ $? -ne 0 ]; then
                            print_warning "Failed to update package lists for $REPO_VERSION"
                            continue
                        fi

                        print_info "Installing CUDA toolkit (this may take a while)..."
                        if [ "$OS_TYPE" = "ubuntu" ]; then
                            AVAILABLE_CUDA=$(apt-cache search cuda-toolkit | grep -E "^cuda-toolkit" | head -5)
                        else
                            AVAILABLE_CUDA=$(dnf search cuda-toolkit 2>/dev/null | grep -E "^cuda-toolkit" | head -5)
                        fi
                        if [ -n "$AVAILABLE_CUDA" ]; then
                            print_info "Available CUDA packages:"
                            echo "$AVAILABLE_CUDA"
                        fi

                        CUDA_PKG_VERSION=$(echo "$TARGET_CUDA_VERSION" | sed 's/\./-/g')
                        print_info "Attempting to install cuda-toolkit-$CUDA_PKG_VERSION"

                        if [ "$OS_TYPE" = "ubuntu" ]; then
                            if NEEDRESTART_MODE=l apt install -y cuda-toolkit-$CUDA_PKG_VERSION 2>/dev/null; then
                                print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                                CUDA_INSTALLED=true
                            else
                                print_warning "cuda-toolkit-$CUDA_PKG_VERSION not available from $REPO_VERSION"
                                if NEEDRESTART_MODE=l apt install -y cuda-toolkit 2>/dev/null; then
                                    print_info "✓ CUDA toolkit installed successfully (generic package)"
                                    CUDA_INSTALLED=true
                                fi
                            fi
                        else
                            if dnf install -y cuda-toolkit-$CUDA_PKG_VERSION 2>/dev/null; then
                                print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                                CUDA_INSTALLED=true
                            else
                                print_warning "cuda-toolkit-$CUDA_PKG_VERSION not available from $REPO_VERSION"
                                if dnf install -y cuda-toolkit 2>/dev/null; then
                                    print_info "✓ CUDA toolkit installed successfully (generic package)"
                                    CUDA_INSTALLED=true
                                fi
                            fi
                        fi

                        if [ "$CUDA_INSTALLED" = true ]; then
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
                            CUDA_MISSING=false
                            break
                        else
                            print_warning "Failed to install CUDA toolkit from $REPO_VERSION"
                        fi
                    fi
                done

                rm -f "$TEMP_DEB"
                trap - EXIT

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
            else
                print_info "Skipping CUDA toolkit installation per user selection."
                CUDA_MISSING=false
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

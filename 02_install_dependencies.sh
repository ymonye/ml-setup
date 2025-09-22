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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUDA_CACHE_DIR="$SCRIPT_DIR/tmp"
if ! mkdir -p "$CUDA_CACHE_DIR" 2>/dev/null; then
    print_warning "Could not create $CUDA_CACHE_DIR; falling back to /tmp/cuda-cache"
    CUDA_CACHE_DIR="/tmp/cuda-cache"
    mkdir -p "$CUDA_CACHE_DIR" 2>/dev/null
fi
CUDA_PACKAGE_DOWNLOADS=()
INSTALLED_CUDA_VERSIONS=()
INSTALLED_CUDA_VERSIONS_DISPLAY="None"

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

collect_installed_cuda_versions() {
    INSTALLED_CUDA_VERSIONS=()
    local packages=()

    if [ "$OS_TYPE" = "ubuntu" ]; then
        if command -v dpkg &> /dev/null; then
            mapfile -t packages < <(dpkg -l 'cuda-toolkit*' 2>/dev/null | awk '/^ii/ {print $2}')
        fi
    elif [ "$OS_TYPE" = "rhel" ]; then
        if command -v rpm &> /dev/null; then
            mapfile -t packages < <(rpm -qa 'cuda-toolkit*' 2>/dev/null)
        fi
    fi

    for pkg in "${packages[@]}"; do
        if [[ $pkg =~ ^cuda-toolkit- ]]; then
            local version_suffix=${pkg#cuda-toolkit-}
            version_suffix=${version_suffix%%.*}
            if [[ $version_suffix =~ ^[0-9]+(-[0-9]+){1,3}$ ]]; then
                local version=${version_suffix//-/.}
                INSTALLED_CUDA_VERSIONS+=("$version")
            fi
        elif [[ $pkg == cuda-toolkit ]]; then
            if [ -n "$CURRENT_CUDA_VERSION_NORMALIZED" ]; then
                INSTALLED_CUDA_VERSIONS+=("$CURRENT_CUDA_VERSION_NORMALIZED")
            fi
        fi
    done

    if [ ${#INSTALLED_CUDA_VERSIONS[@]} -gt 0 ]; then
        mapfile -t INSTALLED_CUDA_VERSIONS < <(printf "%s
" "${INSTALLED_CUDA_VERSIONS[@]}" | awk '!seen[$0]++' | sort -V)
        INSTALLED_CUDA_VERSIONS_DISPLAY=$(printf "%s" "${INSTALLED_CUDA_VERSIONS[0]}")
        for version in "${INSTALLED_CUDA_VERSIONS[@]:1}"; do
            INSTALLED_CUDA_VERSIONS_DISPLAY+=", $version"
        done
    else
        INSTALLED_CUDA_VERSIONS_DISPLAY="None"
    fi
}

# Track overall success
INSTALL_SUCCESS=true
CURRENT_CUDA_VERSION_NORMALIZED=""
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
    CUDA_VERSION_MINOR=${CUDA_VERSION_MINOR:-0}
    CURRENT_CUDA_VERSION_NORMALIZED="${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}"
    
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

collect_installed_cuda_versions

echo ""
# Report and install
SYSTEM_PACKAGES_MISSING_COUNT=${#MISSING_PACKAGES[@]}
if [ $SYSTEM_PACKAGES_MISSING_COUNT -gt 0 ]; then
    print_warning "Missing ${SYSTEM_PACKAGES_MISSING_COUNT} packages: ${MISSING_PACKAGES[*]}"
else
    print_info "All core system packages already installed."
fi

if command -v nvcc &> /dev/null; then
    print_info "CUDA toolkit detected - reinstall, upgrade, or downgrade options available."
else
    print_warning "CUDA toolkit (nvcc) not found - required for GPU-optimized packages"
    CUDA_MISSING=true
fi
echo ""

INSTALL_SYSTEM_PACKAGES="n"
if [ $SYSTEM_PACKAGES_MISSING_COUNT -gt 0 ]; then
    if [ "$AUTO_YES" = true ]; then
        INSTALL_SYSTEM_PACKAGES="y"
    else
        read -p "Do you want to install missing packages? (y/n): " INSTALL_SYSTEM_PACKAGES
    fi
fi

if [[ "$INSTALL_SYSTEM_PACKAGES" =~ ^[Yy]$ ]]; then
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
fi

if [ "$INSTALL_SUCCESS" != true ]; then
    print_error "❌ Installation had errors - check messages above"
    exit 1
fi

# Install/Upgrade CUDA toolkit
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

            print_info "Installed CUDA versions detected: $INSTALLED_CUDA_VERSIONS_DISPLAY"
            print_info "Current CUDA version: $CURRENT_CUDA_DISPLAY"
            echo "Choose CUDA installation option:"
            echo "  1) Keep current version"
            echo "  2) Install latest version ($LATEST_CUDA_VERSION)"
            echo "  3) Install custom version"
            echo "  4) Skip CUDA installation"
            CUDA_SELECTION=""
            CUDA_SKIP_REASON=""
            read -p "Enter choice (1/2/3/4): " CUDA_CHOICE
            while [[ ! "$CUDA_CHOICE" =~ ^[1234]$ ]]; do
                read -p "Please enter 1, 2, 3, or 4: " CUDA_CHOICE
            done
            case $CUDA_CHOICE in
                1)
                    CUDA_SELECTION="keep"
                    CUDA_INSTALL_REQUESTED=false
                    if [ "$CURRENT_CUDA_DISPLAY" = "None" ]; then
                        print_warning "CUDA toolkit remains uninstalled. GPU-accelerated workflows will not be available."
                    else
                        print_info "Keeping existing CUDA toolkit ($CURRENT_CUDA_DISPLAY)."
                    fi
                    ;;
                2)
                    CUDA_SELECTION="latest"
                    CUDA_INSTALL_REQUESTED=true
                    TARGET_CUDA_VERSION="$LATEST_CUDA_VERSION"
                    ;;
                3)
                    CUDA_SELECTION="custom"
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
                4)
                    CUDA_SELECTION="skip"
                    CUDA_INSTALL_REQUESTED=false
                    CUDA_SKIP_REASON="user_skip"
                    print_info "Skipping CUDA toolkit installation per user selection (option 4)."
                    ;;
            esac

            TARGET_CUDA_VERSION_MAJOR=""
            TARGET_CUDA_VERSION_MINOR=""
            TARGET_CUDA_VERSION_NORMALIZED=""
            if [ -n "$TARGET_CUDA_VERSION" ]; then
                TARGET_CUDA_VERSION_MAJOR=$(echo $TARGET_CUDA_VERSION | cut -d. -f1)
                TARGET_CUDA_VERSION_MINOR=$(echo $TARGET_CUDA_VERSION | cut -d. -f2)
                TARGET_CUDA_VERSION_MINOR=${TARGET_CUDA_VERSION_MINOR:-0}
                TARGET_CUDA_VERSION_NORMALIZED="${TARGET_CUDA_VERSION_MAJOR}.${TARGET_CUDA_VERSION_MINOR}"
            fi

            if [ "$CUDA_SELECTION" = "latest" ] && [ -n "$TARGET_CUDA_VERSION_NORMALIZED" ]; then
                LATEST_ALREADY_PRESENT=false
                for installed_version in "${INSTALLED_CUDA_VERSIONS[@]}"; do
                    if [ "$installed_version" = "$TARGET_CUDA_VERSION_NORMALIZED" ]; then
                        LATEST_ALREADY_PRESENT=true
                        break
                    fi
                done
                if [ "$LATEST_ALREADY_PRESENT" = true ]; then
                    print_info "Latest CUDA version $TARGET_CUDA_VERSION is already installed; no action needed."
                    CUDA_INSTALL_REQUESTED=false
                    CUDA_SKIP_REASON="already_up_to_date"
                    CUDA_MISSING=false
                fi
            fi

            if [ "$CUDA_INSTALL_REQUESTED" = true ]; then
                if [ -z "$TARGET_CUDA_VERSION" ]; then
                    TARGET_CUDA_VERSION="$TARGET_CUDA_VERSION_DEFAULT"
                    TARGET_CUDA_VERSION_MAJOR=$(echo $TARGET_CUDA_VERSION | cut -d. -f1)
                    TARGET_CUDA_VERSION_MINOR=$(echo $TARGET_CUDA_VERSION | cut -d. -f2)
                    TARGET_CUDA_VERSION_MINOR=${TARGET_CUDA_VERSION_MINOR:-0}
                    TARGET_CUDA_VERSION_NORMALIZED="${TARGET_CUDA_VERSION_MAJOR}.${TARGET_CUDA_VERSION_MINOR}"
                fi

                TARGET_CUDA_MAJOR=$TARGET_CUDA_VERSION_MAJOR
                TARGET_CUDA_MINOR=$TARGET_CUDA_VERSION_MINOR

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

                APT_UPDATED=false
                DNF_REFRESHED=false
                CUDA_INSTALLED=false
                for REPO_VERSION in "${CUDA_REPO_VERSIONS[@]}"; do
                    [ -z "$REPO_VERSION" ] && continue
                    print_info "Attempting CUDA download from NVIDIA repository: $REPO_VERSION"

                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        CUDA_PKG_VERSION=$(echo "$TARGET_CUDA_VERSION" | sed 's/\./-/g')
                        PACKAGES_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/Packages"
                        PACKAGE_VERSION=$(curl -fsSL "$PACKAGES_URL" 2>/dev/null | awk -v pkg="cuda-toolkit-${CUDA_PKG_VERSION}" '
                            $1 == "Package:" && $2 == pkg { pkgmatch=1; next }
                            pkgmatch && $1 == "Version:" { print $2; exit }
                            pkgmatch && $0 == "" { pkgmatch=0 }
                        ')
                        if [ -z "$PACKAGE_VERSION" ]; then
                            print_warning "Could not determine package version for cuda-toolkit-${CUDA_PKG_VERSION} from $REPO_VERSION"
                            continue
                        fi

                        CUDA_DEB_FILE="${CUDA_CACHE_DIR}/cuda-toolkit-${CUDA_PKG_VERSION}_${PACKAGE_VERSION}_amd64.deb"
                        CUDA_DEB_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/cuda-toolkit-${CUDA_PKG_VERSION}_${PACKAGE_VERSION}_amd64.deb"

                        if [ ! -f "$CUDA_DEB_FILE" ]; then
                            print_info "Downloading CUDA toolkit package from NVIDIA..."
                            if wget -O "$CUDA_DEB_FILE" "$CUDA_DEB_URL"; then
                                CUDA_PACKAGE_DOWNLOADS+=("$CUDA_DEB_FILE")
                            else
                                print_warning "Failed to download $CUDA_DEB_URL"
                                rm -f "$CUDA_DEB_FILE"
                                continue
                            fi
                        else
                            print_info "Using cached CUDA package: $CUDA_DEB_FILE"
                        fi

                        if [ "$APT_UPDATED" = false ]; then
                            print_info "Updating apt package index before CUDA installation..."
                            if ! sudo NEEDRESTART_MODE=l apt update; then
                                print_warning "apt update failed; CUDA installation may require manual dependency resolution"
                            fi
                            APT_UPDATED=true
                        fi

                        print_info "Installing CUDA toolkit package..."
                        if sudo NEEDRESTART_MODE=l apt install -y "$CUDA_DEB_FILE"; then
                            print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                            CUDA_INSTALLED=true
                        else
                            print_warning "Failed to install CUDA toolkit from $CUDA_DEB_FILE"
                        fi

                    elif [ "$OS_TYPE" = "rhel" ]; then
                        CUDA_PKG_VERSION=$(echo "$TARGET_CUDA_VERSION" | sed 's/\./-/g')
                        PRIMARY_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/repodata/primary.xml.gz"
                        RPM_RELATIVE_PATH=$(curl -fsSL "$PRIMARY_URL" 2>/dev/null | gzip -dc 2>/dev/null | awk -v pkg="cuda-toolkit-${CUDA_PKG_VERSION}" '
                            /<package/ { pkgmatch=0 }
                            /<name>/ && $0 ~ pkg { pkgmatch=1 }
                            pkgmatch && /<location href=/ {
                                match($0, /href="([^"]+)"/, arr)
                                if (arr[1] != "") { print arr[1]; exit }
                            }
                        ')
                        if [ -z "$RPM_RELATIVE_PATH" ]; then
                            print_warning "Could not locate CUDA toolkit package metadata for $REPO_VERSION"
                            continue
                        fi

                        RPM_FILE_BASENAME=$(basename "$RPM_RELATIVE_PATH")
                        CUDA_RPM_FILE="${CUDA_CACHE_DIR}/$RPM_FILE_BASENAME"
                        CUDA_RPM_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/$RPM_RELATIVE_PATH"

                        if [ ! -f "$CUDA_RPM_FILE" ]; then
                            print_info "Downloading CUDA toolkit package from NVIDIA..."
                            if wget -O "$CUDA_RPM_FILE" "$CUDA_RPM_URL"; then
                                CUDA_PACKAGE_DOWNLOADS+=("$CUDA_RPM_FILE")
                            else
                                print_warning "Failed to download $CUDA_RPM_URL"
                                rm -f "$CUDA_RPM_FILE"
                                continue
                            fi
                        else
                            print_info "Using cached CUDA package: $CUDA_RPM_FILE"
                        fi

                        if [ "$DNF_REFRESHED" = false ]; then
                            print_info "Refreshing dnf metadata before CUDA installation..."
                            if ! dnf makecache; then
                                print_warning "dnf makecache failed; CUDA installation may require manual dependency resolution"
                            fi
                            DNF_REFRESHED=true
                        fi

                        print_info "Installing CUDA toolkit package..."
                        if dnf install -y "$CUDA_RPM_FILE"; then
                            print_info "✓ CUDA toolkit $TARGET_CUDA_VERSION installed successfully"
                            CUDA_INSTALLED=true
                        else
                            print_warning "Failed to install CUDA toolkit from $CUDA_RPM_FILE"
                        fi
                    else
                        print_warning "Unsupported OS type $OS_TYPE for CUDA installation attempt"
                    fi

                    if [ "$CUDA_INSTALLED" = true ]; then
                        break
                    fi
                done
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
                else
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
                CUDA_MISSING=false
            fi
        
        echo ""
        if [ "$INSTALL_SUCCESS" = true ]; then
            if [ ${#CUDA_PACKAGE_DOWNLOADS[@]} -gt 0 ]; then
                echo ""
                print_info "CUDA support package(s) downloaded: ${CUDA_PACKAGE_DOWNLOADS[*]}"
                read -p "Delete downloaded package(s)? (y/n): " DELETE_CUDA_PKG
                if [[ "$DELETE_CUDA_PKG" =~ ^[Yy]$ ]]; then
                    for pkg_file in "${CUDA_PACKAGE_DOWNLOADS[@]}"; do
                        rm -f "$pkg_file"
                    done
                    print_info "Deleted cached CUDA package(s) from $CUDA_CACHE_DIR"
                else
                    print_info "Retained cached CUDA package(s) at $CUDA_CACHE_DIR"
                fi
            fi
            print_info "✅ Installation complete!"
        else
            print_error "❌ Installation had errors - check messages above"
            exit 1
        fi

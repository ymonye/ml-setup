#!/bin/bash
# Script: setup_ml_environment_ubuntu.sh
# Purpose: Complete ML environment setup for Ubuntu 22.04+
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

# First check: Ubuntu version
print_info "Checking Ubuntu version..."
if [ ! -f /etc/os-release ]; then
    print_error "Cannot determine OS version. /etc/os-release not found."
    exit 1
fi
source /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    print_error "This script is designed for Ubuntu. Detected: $ID"
    exit 1
fi

# Extract major and minor version
VERSION_MAJOR=$(echo $VERSION_ID | cut -d. -f1)
VERSION_MINOR=$(echo $VERSION_ID | cut -d. -f2)

# Check if version >= 22.04
if [ "$VERSION_MAJOR" -lt 22 ]; then
    print_error "Ubuntu version $VERSION_ID is not supported."
    print_error "This script requires Ubuntu 22.04 or newer."
    exit 1
fi

print_info "✓ Ubuntu $VERSION_ID detected - supported version"
echo ""

MISSING_DEPS=false

print_info "Complete ML Environment Setup"
echo "=============================================="

# 2. System Libraries
print_info "Checking system libraries..."

SYSTEM_PACKAGES=(
    # Essential build tools
    "build-essential"
    "gcc"
    "g++"
    "make"
    "cmake"
    
    # Linear algebra libraries (for PyTorch CPU)
    "libopenblas-dev"
    "libblas-dev"
    "liblapack-dev"
    "libatlas-base-dev"
    "gfortran"
    
    # NUMA optimization (for multi-CPU socket servers)
    "numactl"
    "libnuma-dev"
    
    # Image processing (for torchvision)
    "libjpeg-dev"
    "libpng-dev"
    "libtiff-dev"
    "libavcodec-dev"
    "libavformat-dev"
    "libswscale-dev"
    
    # Other ML dependencies
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

MISSING_SYSTEM_PACKAGES=()
print_info "Required system packages:"
for pkg in "${SYSTEM_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        print_info "  ✓ $pkg"
    else
        print_error "  ✗ $pkg"
        MISSING_SYSTEM_PACKAGES+=($pkg)
        MISSING_DEPS=true
    fi
done

if [ ${#MISSING_SYSTEM_PACKAGES[@]} -gt 0 ]; then
    print_warning "Missing system packages detected!"
    print_command "sudo apt update"
    print_command "sudo apt install -y ${MISSING_SYSTEM_PACKAGES[*]}"
    echo ""
fi

# Check CUDA toolkit (nvcc)
print_info "Checking CUDA toolkit..."
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
    print_info "✓ CUDA toolkit (nvcc) installed - version $CUDA_VERSION"
else
    print_error "✗ CUDA toolkit (nvcc) not installed"
    print_info "Required for GPU-optimized packages (flashinfer, etc.)"
    print_info "To install CUDA toolkit, run check_dependencies.sh"
    MISSING_DEPS=true
fi

# 3. Check pyenv
print_info "Checking pyenv installation..."
if command -v pyenv &> /dev/null; then
    print_info "✓ pyenv installed"
else
    print_error "✗ pyenv not installed"
    print_info "Install pyenv:"
    print_command "curl https://pyenv.run | bash"
    print_command "# Add to ~/.bashrc:"
    print_command 'export PYENV_ROOT="$HOME/.pyenv"'
    print_command 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
    print_command 'eval "$(pyenv init -)"'
    MISSING_DEPS=true
fi

# 4. Check Python 3.11.9
print_info "Checking Python 3.11.9..."
if pyenv versions 2>/dev/null | grep -q "3.11.9"; then
    print_info "✓ Python 3.11.9 installed via pyenv"
else
    print_error "✗ Python 3.11.9 not installed"
    print_command "pyenv install 3.11.9"
    print_command "pyenv global 3.11.9"
    MISSING_DEPS=true
fi

# 5. Check uv
print_info "Checking uv..."
if command -v uv &> /dev/null; then
    print_info "✓ uv installed ($(uv --version))"
else
    print_error "✗ uv not installed"
    print_command "curl -LsSf https://astral.sh/uv/install.sh | sh"
    print_command 'echo '\''export PATH="$HOME/.cargo/bin:$PATH"'\'' >> ~/.bashrc'
    print_command "source ~/.bashrc"
    MISSING_DEPS=true
fi

# 6. Virtual Environment Check - UPDATED TO ml_env
print_info "Checking virtual environment..."
if [ -z "$VIRTUAL_ENV" ]; then
    print_warning "No virtual environment activated"
    print_info "Create and activate virtual environment:"
    print_command "uv venv ~/ml_env --python 3.11.9"
    print_command "source ~/ml_env/bin/activate"
    MISSING_DEPS=true
else
    print_info "✓ Virtual environment: $VIRTUAL_ENV"
fi

# 7. Python Packages (if venv active)
if [ -n "$VIRTUAL_ENV" ]; then
    print_info "Checking Python packages..."
    
    # Check core packages with correct import names
    declare -A PACKAGES=(
        ["torch"]="torch"
        ["torchvision"]="torchvision"
        ["torchaudio"]="torchaudio"
        ["transformers"]="transformers"
        ["accelerate"]="accelerate"
        ["datasets"]="datasets"
        ["tokenizers"]="tokenizers"
        ["sentencepiece"]="sentencepiece"
        ["protobuf"]="google.protobuf"  # Fixed import name
        ["safetensors"]="safetensors"
        ["huggingface-hub"]="huggingface_hub"
        ["numpy"]="numpy"
        ["scipy"]="scipy"
        ["tqdm"]="tqdm"
        ["psutil"]="psutil"
        ["fastapi"]="fastapi"
        ["uvicorn"]="uvicorn"
        ["pydantic"]="pydantic"
        ["aiohttp"]="aiohttp"
        ["requests"]="requests"
        ["py-cpuinfo"]="cpuinfo"
        ["pandas"]="pandas"
    )
    
    # Check inference frameworks separately
    declare -A FRAMEWORKS=(
        ["sglang"]="sglang"
        ["vllm"]="vllm"
        ["llama-cpp-python"]="llama_cpp"
        ["intel-extension-for-pytorch"]="intel_extension_for_pytorch"
        ["onnxruntime"]="onnxruntime"
        ["optimum"]="optimum"
    )
    
    MISSING_PACKAGES=()
    print_info "Core packages:"
    for pkg in "${!PACKAGES[@]}"; do
        import_name="${PACKAGES[$pkg]}"
        if python -c "import $import_name" 2>/dev/null; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_PACKAGES+=($pkg)
        fi
    done
    
    print_info "Inference frameworks:"
    for pkg in "${!FRAMEWORKS[@]}"; do
        import_name="${FRAMEWORKS[$pkg]}"
        if python -c "import $import_name" 2>/dev/null; then
            print_info "  ✓ $pkg"
        else
            print_warning "  ✗ $pkg (optional)"
            MISSING_PACKAGES+=($pkg)
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        print_warning "Missing Python packages detected!"
        print_info "Install commands for missing packages:"
        
        # Check which groups need installation
        if [[ " ${MISSING_PACKAGES[@]} " =~ " torch " ]] || \
           [[ " ${MISSING_PACKAGES[@]} " =~ " torchvision " ]] || \
           [[ " ${MISSING_PACKAGES[@]} " =~ " torchaudio " ]]; then
            print_command "uv pip install torch torchvision torchaudio"
        fi
        
        # Check transformers ecosystem
        TRANSFORMERS_MISSING=()
        for pkg in transformers accelerate datasets tokenizers sentencepiece protobuf safetensors huggingface-hub; do
            if [[ " ${MISSING_PACKAGES[@]} " =~ " $pkg " ]]; then
                TRANSFORMERS_MISSING+=($pkg)
            fi
        done
        if [ ${#TRANSFORMERS_MISSING[@]} -gt 0 ]; then
            print_command "uv pip install ${TRANSFORMERS_MISSING[*]}"
        fi
        
        # Check SGLang
        if [[ " ${MISSING_PACKAGES[@]} " =~ " sglang " ]]; then
            if command -v nvcc &> /dev/null; then
                print_command 'uv pip install "sglang[all]"'
            else
                print_command 'uv pip install sglang  # Base version without CUDA dependencies'
            fi
        fi
        
        # Check vLLM
        if [[ " ${MISSING_PACKAGES[@]} " =~ " vllm " ]]; then
            print_command 'uv pip install vllm'
        fi
        
        # Check other dependencies
        OTHER_MISSING=()
        for pkg in fastapi uvicorn pydantic aiohttp requests numpy scipy pandas tqdm psutil py-cpuinfo; do
            if [[ " ${MISSING_PACKAGES[@]} " =~ " $pkg " ]]; then
                OTHER_MISSING+=($pkg)
            fi
        done
        if [ ${#OTHER_MISSING[@]} -gt 0 ]; then
            print_command "uv pip install ${OTHER_MISSING[*]}"
        fi
        
        # Check CPU optimizations
        CPU_OPT_MISSING=()
        for pkg in intel-extension-for-pytorch onnxruntime optimum; do
            if [[ " ${MISSING_PACKAGES[@]} " =~ " $pkg " ]]; then
                CPU_OPT_MISSING+=($pkg)
            fi
        done
        if [ ${#CPU_OPT_MISSING[@]} -gt 0 ]; then
            print_command "uv pip install ${CPU_OPT_MISSING[*]}"
        fi
        
        # Check llama.cpp
        if [[ " ${MISSING_PACKAGES[@]} " =~ " llama-cpp-python " ]]; then
            if command -v nvcc &> /dev/null; then
                print_command 'CMAKE_ARGS="-DLLAMA_CUDA=ON" uv pip install llama-cpp-python[server]'
            else
                print_command 'CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS" uv pip install llama-cpp-python[server]'
            fi
        fi
        
        MISSING_DEPS=true
    fi
fi

# 8. Environment Variables
print_info "Checking environment variables..."
ENV_VARS_NEEDED=false

if [ -z "$HF_HOME" ]; then
    print_warning "HF_HOME not set"
    ENV_VARS_NEEDED=true
fi

if ! echo $PATH | grep -q ".cargo/bin"; then
    print_warning "Cargo bin not in PATH (needed for uv)"
    ENV_VARS_NEEDED=true
fi

if ! echo $PATH | grep -q "/usr/local/cuda/bin" && command -v nvcc &> /dev/null; then
    print_warning "CUDA bin not in PATH"
    ENV_VARS_NEEDED=true
fi

if [ "$ENV_VARS_NEEDED" = true ]; then
    print_info "Add to ~/.bashrc:"
    print_command 'export HF_HOME="/data/ml/models/huggingface"'
    print_command 'export PATH="$HOME/.cargo/bin:$PATH"'
    if command -v nvcc &> /dev/null; then
        print_command 'export PATH="/usr/local/cuda/bin:$PATH"'
        print_command 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"'
    fi
    print_command ""
    print_command "# For NUMA-aware systems (multi-socket CPUs)"
    print_command 'export OMP_PROC_BIND=true'
    print_command 'export OMP_PLACES=cores'
fi

# 9. Directory Structure
print_info "Checking directory structure..."
DIRS=(
    "/data/ml"
    "/data/ml/models"
    "/data/ml/models/huggingface"
    "/data/ml/scripts"
    "/data/ml/logs"
)

MISSING_DIRS=()
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_info "  ✓ $dir exists"
    else
        print_warning "  ✗ $dir missing"
        MISSING_DIRS+=($dir)
    fi
done

if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
    print_command "mkdir -p ${MISSING_DIRS[*]}"
fi

# Summary
echo ""
echo "=============================================="
if [ "$MISSING_DEPS" = true ]; then
    print_error "Setup incomplete! Install missing dependencies above."
    echo ""
    if [ ${#MISSING_SYSTEM_PACKAGES[@]} -gt 0 ]; then
        print_info "Quick install command for missing system packages:"
        print_info "(Note: Python must be installed via pyenv as shown above)"
        echo ""
        echo "sudo apt update && sudo apt install -y ${MISSING_SYSTEM_PACKAGES[*]}"
    fi
    print_info ""
    print_info "For complete setup, run these scripts in order:"
    print_info "1. ./check_dependencies.sh    # System packages + CUDA"
    print_info "2. ./check_python.sh          # Python toolchain"
    print_info "3. ./create_ml_env.sh         # Virtual environment"
    print_info "4. ./check_ml_packages.sh     # ML packages"
else
    print_info "✅ All dependencies satisfied!"
    echo ""
    print_info "Next steps:"
    print_info "1. Run the model download script"
    print_info "2. Test your setup with a model"
fi

# What NUMA is for
echo ""
print_info "Note about NUMA (Non-Uniform Memory Access):"
print_info "- Important for servers with multiple CPU sockets"
print_info "- Optimizes memory access patterns across CPUs"
print_info "- numactl lets you bind processes to specific CPUs/memory"
print_info "- Check NUMA topology with: numactl --hardware"

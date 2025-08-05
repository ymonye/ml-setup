#!/bin/bash
# Script: activate_ml.sh
# Purpose: Activate ML environment with all optimizations
# Usage: source activate_ml.sh [env_name]
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    BEING_SOURCED=true
else
    BEING_SOURCED=false
    print_error "This script must be sourced, not executed!"
    print_info "Use: source $0"
    exit 1
fi

# Get environment name (default: ml)
ENV_NAME="${1:-ml}"
ENV_PATH="$HOME/${ENV_NAME}_env"

# Check if environment exists
if [ ! -d "$ENV_PATH" ]; then
    print_error "Environment '$ENV_NAME' not found at $ENV_PATH"
    print_info "Run create_ml_env.sh first to create it"
    return 1
fi

# Check if already in a virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    print_warning "Already in virtual environment: $VIRTUAL_ENV"
    read -p "Deactivate and switch to $ENV_NAME? (y/n): " SWITCH
    if [[ "$SWITCH" =~ ^[Yy]$ ]]; then
        deactivate
    else
        return 0
    fi
fi

# Activate virtual environment
print_info "Activating $ENV_NAME environment..."
source "$ENV_PATH/bin/activate"

# Set ML environment variables
export HF_HOME="/data/ml/models/huggingface"
export HUGGINGFACE_HUB_CACHE="/data/ml/models/huggingface"

# CPU optimization for 32 cores
export OMP_NUM_THREADS=32
export MKL_NUM_THREADS=32
export OPENBLAS_NUM_THREADS=32
export VECLIB_MAXIMUM_THREADS=32
export NUMEXPR_NUM_THREADS=32

# NUMA optimization
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# Memory optimization
export MALLOC_ARENA_MAX=2

# CUDA paths if nvcc is available
if command -v nvcc &> /dev/null; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
fi

# Display activation info
echo ""
print_info "✓ ML environment activated!"
echo "  - Virtual env: $ENV_PATH"
echo "  - Python: $(which python) ($(python --version 2>&1))"
echo "  - HF_HOME: $HF_HOME"
echo "  - CPU threads: $OMP_NUM_THREADS"
if command -v nvcc &> /dev/null; then
    echo "  - CUDA: $(nvcc --version | grep release | awk '{print $6}')"
fi

echo ""
print_info "To deactivate: deactivate"
print_info "To check packages: ./check_ml_packages.sh"

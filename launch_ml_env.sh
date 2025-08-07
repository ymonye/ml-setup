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

# Get environment type/name
ENV_TYPE="${1}"

# If no argument provided, prompt for environment type
if [ -z "$ENV_TYPE" ]; then
    echo ""
    print_info "Select ML environment type:"
    echo "1) Transformers"
    echo "2) vLLM" 
    echo "3) SGLang"
    echo ""
    while true; do
        read -p "Enter your choice (1-3): " choice
        case $choice in
            1)
                ENV_TYPE="transformers"
                break
                ;;
            2)
                ENV_TYPE="vllm"
                break
                ;;
            3)
                ENV_TYPE="sglang"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
fi

# Set environment name based on type
case $ENV_TYPE in
    transformers|1)
        ENV_NAME="transformers"
        ;;
    vllm|2)
        ENV_NAME="vllm"
        ;;
    sglang|3)
        ENV_NAME="sglang"
        ;;
    *)
        ENV_NAME="$ENV_TYPE"
        ;;
esac

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

# Function to detect GPU and set TORCH_CUDA_ARCH_LIST
detect_gpu_arch() {
    if ! command -v nvidia-smi &> /dev/null; then
        return 1
    fi
    
    local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    local arch_list=""
    
    # Clean up GPU name
    gpu_name=$(echo "$gpu_name" | tr '[:lower:]' '[:upper:]')
    
    # Determine architecture based on GPU model
    case "$gpu_name" in
        *"H100"*)
            arch_list="9.0"
            echo "  - GPU: H100 (Hopper, sm_90)"
            ;;
        *"H200"*)
            arch_list="9.0"
            echo "  - GPU: H200 (Hopper, sm_90)"
            ;;
        *"B200"*)
            arch_list="10.0"
            echo "  - GPU: B200 (Blackwell, sm_100)"
            ;;
        *"RTX 4090"*|*"4090"*)
            arch_list="8.9"
            echo "  - GPU: RTX 4090 (Ada Lovelace, sm_89)"
            ;;
        *"RTX 5090"*|*"5090"*)
            arch_list="12.0"
            echo "  - GPU: RTX 5090 (Blackwell, sm_120)"
            ;;
        *"RTX 6000"*|*"RTX A6000"*)
            # Need to distinguish between Ada and Blackwell versions
            if [[ "$gpu_name" == *"ADA"* ]]; then
                arch_list="8.9"
                echo "  - GPU: RTX 6000 Ada (Ada Lovelace, sm_89)"
            else
                # Check CUDA version to infer if it's Blackwell
                local cuda_version=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $6}' | cut -d',' -f1)
                if [[ "$cuda_version" == "12.8" ]] || [[ "$cuda_version" > "12.8" ]]; then
                    arch_list="12.0"
                    echo "  - GPU: RTX 6000 Pro (Blackwell, sm_120)"
                else
                    arch_list="8.9"
                    echo "  - GPU: RTX 6000 (Ada Lovelace, sm_89)"
                fi
            fi
            ;;
        *"A100"*)
            arch_list="8.0"
            echo "  - GPU: A100 (Ampere, sm_80)"
            ;;
        *"A10"*|*"A40"*)
            arch_list="8.6"
            echo "  - GPU: A10/A40 (Ampere, sm_86)"
            ;;
        *"V100"*)
            arch_list="7.0"
            echo "  - GPU: V100 (Volta, sm_70)"
            ;;
        *"T4"*)
            arch_list="7.5"
            echo "  - GPU: T4 (Turing, sm_75)"
            ;;
        *"RTX 3090"*|*"3090"*)
            arch_list="8.6"
            echo "  - GPU: RTX 3090 (Ampere, sm_86)"
            ;;
        *"RTX 3080"*|*"3080"*)
            arch_list="8.6"
            echo "  - GPU: RTX 3080 (Ampere, sm_86)"
            ;;
        *)
            echo "  - GPU: $gpu_name (Unknown architecture)"
            return 1
            ;;
    esac
    
    # Export the architecture list
    export TORCH_CUDA_ARCH_LIST="$arch_list"
    echo "  - TORCH_CUDA_ARCH_LIST: $arch_list"
    
    return 0
}

# CUDA paths if nvcc is available
if command -v nvcc &> /dev/null; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
    
    # Detect GPU and set architecture
    detect_gpu_arch
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

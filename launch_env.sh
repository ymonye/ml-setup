#!/bin/bash

# Script: launch_env.sh
# Purpose: Activate ML environment with all optimizations
# Usage: source launch_env.sh [--auto] [env_name]

# Source bashrc to ensure environment is properly loaded
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

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
    print_info "Use: source $0 [--auto] [env_name]"
    exit 1
fi

# Parse arguments
AUTO_MODE=false
ENV_TYPE=""

for arg in "$@"; do
    case $arg in
        --auto)
            AUTO_MODE=true
            ;;
        *)
            if [[ ! "$arg" =~ ^-- ]]; then
                ENV_TYPE="$arg"
            fi
            ;;
    esac
done

# Prompt for environment type if not provided and not in auto mode
if [ -z "$ENV_TYPE" ] && [ "$AUTO_MODE" = false ]; then
    echo ""
    print_info "Select ML environment type:"
    echo "1) vLLM (Regular)"
    echo "2) vLLM (GPT-OSS)"
    echo "3) SGLang"
    echo "4) Transformers"
    echo ""
    while true; do
        read -p "Enter your choice (1-4): " choice
        case $choice in
            1)
                ENV_TYPE="vllm"
                break
                ;;
            2)
                ENV_TYPE="vllm-gptoss"
                break
                ;;
            3)
                ENV_TYPE="sglang"
                break
                ;;
            4)
                ENV_TYPE="transformers"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, 3, or 4."
                ;;
        esac
    done
elif [ -z "$ENV_TYPE" ]; then
    # Default to vllm in auto mode
    ENV_TYPE="vllm"
fi

# Set environment name based on type
case $ENV_TYPE in
    vllm|1)
        ENV_NAME="vllm"
        ;;
    vllm-gptoss|2)
        ENV_NAME="vllm_gptoss"
        ;;
    sglang|3)
        ENV_NAME="sglang"
        ;;
    transformers|4)
        ENV_NAME="transformers"
        ;;
    *)
        ENV_NAME="$ENV_TYPE"
        ;;
esac

ENV_PATH="$HOME/${ENV_NAME}_env"

# Check if environment exists
if [ ! -d "$ENV_PATH" ]; then
    print_error "Environment '$ENV_NAME' not found at $ENV_PATH"
    print_info "Run 03_setup_env.sh first to create it"
    return 1
fi

# Check if already in a virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    print_warning "Already in virtual environment: $VIRTUAL_ENV"
    if [ "$AUTO_MODE" = false ]; then
        read -p "Deactivate and switch to $ENV_NAME? (y/n): " SWITCH
    else
        SWITCH="y"
        print_info "Auto mode: switching environment"
    fi
    if [[ "$SWITCH" =~ ^[Yy]$ ]]; then
        deactivate
    else
        return 0
    fi
fi

# Check if activate_ml script exists, use it if available
if [ -f "$ENV_PATH/activate_ml" ]; then
    print_info "Using activate_ml script..."
    source "$ENV_PATH/activate_ml"
else
    # Fallback to manual activation
    print_info "Activating $ENV_NAME environment..."
    source "$ENV_PATH/bin/activate"
    
    # Determine HF_PATH - check if already set, otherwise use default
    if [ -n "$HF_HOME" ]; then
        HF_PATH="$HF_HOME"
    else
        HF_PATH="/data/ml/models/huggingface"
    fi
    
    # Set ML environment variables
    export HF_HOME="$HF_PATH"
    export HUGGINGFACE_HUB_CACHE="$HF_PATH"

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

    # Detect GPU architecture
    print_info "Detecting GPU architecture..."
    TORCH_CUDA_ARCH_LIST=""
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')
        
        if [ -n "$GPU_NAME" ]; then
            print_info "Detected GPU: $GPU_NAME"
            
            # Determine architecture based on GPU model
            if [[ "$GPU_NAME" == *"V100"* ]]; then
                TORCH_CUDA_ARCH_LIST="7.0"
                print_info "  → $GPU_NAME (Volta) detected: sm_70"
                
            elif [[ "$GPU_NAME" == *"T4"* ]] || \
                 ([[ "$GPU_NAME" == *"RTX 5000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 4000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 6000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]); then
                TORCH_CUDA_ARCH_LIST="7.5"
                print_info "  → $GPU_NAME (Turing) detected: sm_75"
                
            elif [[ "$GPU_NAME" == *"A100"* ]] || [[ "$GPU_NAME" == *"A30"* ]]; then
                TORCH_CUDA_ARCH_LIST="8.0"
                print_info "  → $GPU_NAME (Ampere) detected: sm_80"
                
            elif [[ "$GPU_NAME" == *"RTX 3090"* ]] || [[ "$GPU_NAME" == *"3090"* ]] || \
                 [[ "$GPU_NAME" == *"RTX 3080"* ]] || [[ "$GPU_NAME" == *"3080"* ]] || \
                 [[ "$GPU_NAME" == *"RTX 3070"* ]] || [[ "$GPU_NAME" == *"3070"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A6000"* ]] || [[ "$GPU_NAME" == *"A6000"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A5000"* ]] || [[ "$GPU_NAME" == *"A5000"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A4500"* ]] || [[ "$GPU_NAME" == *"A4500"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A4000"* ]] || [[ "$GPU_NAME" == *"A4000"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A2000"* ]] || [[ "$GPU_NAME" == *"A2000"* ]] || \
                 [[ "$GPU_NAME" == *"A10"* ]] || [[ "$GPU_NAME" == *"A40"* ]]; then
                TORCH_CUDA_ARCH_LIST="8.6"
                print_info "  → $GPU_NAME (Ampere) detected: sm_86"
                
            elif [[ "$GPU_NAME" == *"RTX 4090"* ]] || [[ "$GPU_NAME" == *"4090"* ]] || \
                 [[ "$GPU_NAME" == *"RTX 4070 TI"* ]] || [[ "$GPU_NAME" == *"4070 TI"* ]] || \
                 [[ "$GPU_NAME" == *"L40S"* ]] || [[ "$GPU_NAME" == *"L40"* ]] || [[ "$GPU_NAME" == *"L4"* ]] || \
                 ([[ "$GPU_NAME" == *"RTX 6000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 5000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 4000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]); then
                TORCH_CUDA_ARCH_LIST="8.9"
                print_info "  → $GPU_NAME (Ada Lovelace) detected: sm_89"
                
            elif [[ "$GPU_NAME" == *"H100"* ]] || [[ "$GPU_NAME" == *"H200"* ]] || [[ "$GPU_NAME" == *"GH200"* ]]; then
                TORCH_CUDA_ARCH_LIST="9.0"
                print_info "  → $GPU_NAME (Hopper) detected: sm_90"
                
            elif [[ "$GPU_NAME" == *"B200"* ]]; then
                TORCH_CUDA_ARCH_LIST="10.0"
                print_info "  → $GPU_NAME (Blackwell) detected: sm_100"
                
            elif [[ "$GPU_NAME" == *"RTX 5090"* ]] || [[ "$GPU_NAME" == *"5090"* ]]; then
                TORCH_CUDA_ARCH_LIST="12.0"
                print_info "  → $GPU_NAME (Blackwell) detected: sm_120"
                
            else
                print_warning "  → Unknown GPU model, will use default PyTorch CUDA architectures"
            fi
            
            if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
                export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"
                print_info "  → Set TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
            fi
        else
            print_warning "Could not detect GPU name"
        fi
    else
        print_warning "nvidia-smi not found - no GPU detected"
    fi

    # CUDA paths if nvcc is available
    if command -v nvcc &> /dev/null; then
        export PATH="/usr/local/cuda/bin:$PATH"
        export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
    fi
fi

# Display activation info if not using activate_ml script
if [ ! -f "$ENV_PATH/activate_ml" ]; then
    echo ""
    print_info "✓ ML environment activated!"
    echo "  - Virtual env: $ENV_PATH"
    echo "  - Python: $(which python) ($(python --version 2>&1))"
    echo "  - HF_HOME: $HF_HOME"
    echo "  - CPU threads: $OMP_NUM_THREADS"
    if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
        echo "  - TORCH_CUDA_ARCH_LIST: $TORCH_CUDA_ARCH_LIST"
    fi
    if command -v nvcc &> /dev/null; then
        echo "  - CUDA: $(nvcc --version | grep release | awk '{print $6}')"
    fi
fi

echo ""
print_info "To deactivate: deactivate"
print_info "To check packages: ./04_check_ml_packages.sh"

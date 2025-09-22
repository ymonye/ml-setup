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
resolve_env_type() {
    case "$1" in
        1|deepseek_v3_lightllm|deepseek-v3-lightllm)
            echo "deepseek-v3-lightllm"
            ;;
        2|deepseek_v3_lmdeploy|deepseek-v3-lmdeploy)
            echo "deepseek-v3-lmdeploy"
            ;;
        3|deepseek_v3_sglang|deepseek-v3-sglang)
            echo "deepseek-v3-sglang"
            ;;
        4|deepseek_v3_tensorrt_llm|deepseek-v3-tensorrt-llm)
            echo "deepseek-v3-tensorrt-llm"
            ;;
        5|deepseek_v3_vllm|deepseek-v3-vllm)
            echo "deepseek-v3-vllm"
            ;;
        6|glm_4.5|glm45_sglang|glm-4.5-sglang)
            echo "glm-4.5-sglang"
            ;;
        7|glm_4.5_vllm|glm45_vllm|glm-4.5-vllm)
            echo "glm-4.5-vllm"
            ;;
        8|gptoss_tensorrt_llm|gpt-oss_tensorrt_llm|gptoss-tensorrt-llm|gpt-oss-tensorrt-llm)
            echo "gpt-oss-tensorrt-llm"
            ;;
        9|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        10|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        11|kimi_k2_sglang|kimi-k2-sglang)
            echo "kimi-k2-sglang"
            ;;
        12|kimi_k2_tensorrt_llm|kimi-k2-tensorrt-llm)
            echo "kimi-k2-tensorrt-llm"
            ;;
        13|kimi_k2_vllm|kimi-k2-vllm)
            echo "kimi-k2-vllm"
            ;;
        14|qwen3_sglang|qwen3-sglang)
            echo "qwen3-sglang"
            ;;
        15|qwen3_transformers|qwen3-transformers)
            echo "qwen3-transformers"
            ;;
        16|qwen3_vllm|qwen3-vllm)
            echo "qwen3-vllm"
            ;;
        17|custom)
            echo "custom"
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                return 1
            fi
            return 1
            ;;
    esac
}

resolve_env_name() {
    local env_type="$1"

    if [ -z "$env_type" ]; then
        echo "custom"
        return 0
    fi

    echo "$env_type"
}

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
    echo "1) DeepSeek-V3/V3.1/R1 (LightLLM)"
    echo "2) DeepSeek-V3/V3.1/R1 (LMDeploy)"
    echo "3) DeepSeek-V3/V3.1/R1 (SGLang)"
    echo "4) DeepSeek-V3/V3.1/R1 (TensorRT-LLM)"
    echo "5) DeepSeek-V3/V3.1/R1 (vLLM)"
    echo "6) GLM 4.5 (SGLang)"
    echo "7) GLM 4.5 (vLLM)"
    echo "8) gpt-oss (TensorRT-LLM)"
    echo "9) gpt-oss (Transformers)"
    echo "10) gpt-oss (vLLM)"
    echo "11) Kimi K2 (SGLang)"
    echo "12) Kimi K2 (TensorRT-LLM)"
    echo "13) Kimi K2 (vLLM)"
    echo "14) Qwen3 (SGLang)"
    echo "15) Qwen3 (Transformers)"
    echo "16) Qwen3 (vLLM)"
    echo "17) Custom"
    echo ""
    while true; do
        read -p "Enter your choice (1-17): " choice
        if ENV_TYPE=$(resolve_env_type "$choice"); then
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and 17."
        fi
    done
elif [ -z "$ENV_TYPE" ]; then
    # Default to DeepSeek-V3/V3.1/R1 (LightLLM) in auto mode
    ENV_TYPE="deepseek_v3_lightllm"
fi

# Normalize environment type when provided directly
if [ -n "$ENV_TYPE" ]; then
    if ENV_TYPE_MAPPED=$(resolve_env_type "$ENV_TYPE"); then
        ENV_TYPE="$ENV_TYPE_MAPPED"
    fi
fi

if [[ "$ENV_TYPE" =~ ^[0-9]+$ ]]; then
    print_error "Invalid environment selection: $ENV_TYPE"
    return 1
fi

# Set environment name based on type
ENV_NAME=$(resolve_env_name "$ENV_TYPE")

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
        HF_PATH="/workspace/models/huggingface"
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

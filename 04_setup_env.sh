#!/bin/bash

# Script: 04_setup_env.sh
# Purpose: Create ML virtual environment and set up environment variables
# Usage: source 04_setup_env.sh [--auto] [env_name]

# Source bashrc to ensure environment is properly loaded
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

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
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

# Set environment name based on type
ENV_NAME=$(resolve_env_name "$ENV_TYPE")

ENV_PATH="$HOME/${ENV_NAME}_env"

# Ask for HuggingFace model storage location
DEFAULT_HF_PATH="/workspace/models/huggingface"
if [ "$AUTO_MODE" = false ]; then
    echo ""
    print_info "Where would you like to store HuggingFace models?"
    print_info "Default: $DEFAULT_HF_PATH"
    read -p "Enter path (press Enter for default): " HF_PATH_INPUT
    
    if [ -z "$HF_PATH_INPUT" ]; then
        HF_PATH="$DEFAULT_HF_PATH"
        print_info "Using default path: $HF_PATH"
    else
        # Expand tilde if present
        HF_PATH="${HF_PATH_INPUT/#\~/$HOME}"
        print_info "Using custom path: $HF_PATH"
    fi
else
    HF_PATH="$DEFAULT_HF_PATH"
    print_info "Using default HuggingFace path: $HF_PATH"
fi

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v python &> /dev/null; then
    print_error "Python is not available on PATH. Please ensure Python is installed and accessible before running this script."
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

PYTHON_BIN=$(command -v python)
PYTHON_VERSION=$($PYTHON_BIN --version 2>&1)
print_info "Using Python from: $PYTHON_BIN ($PYTHON_VERSION)"

if ! command -v uv &> /dev/null; then
    print_error "uv is not installed. Please run check_python.sh first."
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

# Check if environment exists and handle rebuild
if [ -d "$ENV_PATH" ]; then
    print_warning "⚠️  Environment $ENV_NAME already exists at $ENV_PATH"
    
    if [ "$AUTO_MODE" = false ]; then
        echo ""
        print_info "Do you want to rebuild it? This will:"
        print_info "  • Delete the existing environment directory"
        print_info "  • Remove all installed packages"
        print_info "  • Create a fresh environment"
        echo ""
        
        while true; do
            read -p "Rebuild environment? (y/n): " RECREATE
            case ${RECREATE,,} in
                y|yes)
                    print_info "Destroying existing environment..."
                    print_command "rm -rf $ENV_PATH"
                    rm -rf "$ENV_PATH"
                    print_info "✓ Environment destroyed"
                    break
                    ;;
                n|no)
                    print_info "Keeping existing environment"
                    break
                    ;;
                *)
                    print_error "Please answer 'y' for yes or 'n' for no"
                    ;;
            esac
        done
    else
        RECREATE="n"
        print_info "Using existing environment (use without --auto to be prompted)"
    fi
fi

if [ ! -d "$ENV_PATH" ]; then
    print_info "Creating virtual environment at $ENV_PATH using $PYTHON_BIN..."
    uv venv "$ENV_PATH" --python "$PYTHON_BIN"
    
    if [ $? -eq 0 ]; then
        print_info "✓ Virtual environment created successfully"
    else
        print_error "Failed to create virtual environment"
        if [ "$BEING_SOURCED" = false ]; then
            exit 1
        else
            return 1
        fi
    fi
fi

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
            print_info "  → Set TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
        fi
    else
        print_warning "Could not detect GPU name"
    fi
else
    print_warning "nvidia-smi not found - no GPU detected"
fi

echo ""

# Create activation script with environment variables
print_info "Creating activation script with ML environment variables..."

cat > "$ENV_PATH/activate_ml" << EOF
#!/bin/bash
# Activate virtual environment
source "$ENV_PATH/bin/activate"

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

# GPU architecture for PyTorch
${TORCH_CUDA_ARCH_LIST:+export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"}

echo "ML environment activated with:"
echo "  - Virtual env: $ENV_PATH"
echo "  - HF_HOME: $HF_PATH"
echo "  - CPU threads: 32"
${TORCH_CUDA_ARCH_LIST:+echo "  - TORCH_CUDA_ARCH_LIST: $TORCH_CUDA_ARCH_LIST"}
echo "  - Python: \$(python --version)"
EOF

chmod +x "$ENV_PATH/activate_ml"

# Add environment variables to .bashrc if not present
print_info "Updating ~/.bashrc with environment variables..."

if ! grep -q "HF_HOME=" ~/.bashrc; then
    cat >> ~/.bashrc << EOF

# ML Environment Variables
export HF_HOME="$HF_PATH"
export HUGGINGFACE_HUB_CACHE="$HF_PATH"
${TORCH_CUDA_ARCH_LIST:+export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"}
EOF
    print_info "Added HF_HOME to ~/.bashrc"
    if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
        print_info "Added TORCH_CUDA_ARCH_LIST to ~/.bashrc"
    fi
fi


# Create directory structure
print_info "Creating directory structure..."
# Get parent directories from HF_PATH
HF_PARENT=$(dirname "$HF_PATH")
HF_GRANDPARENT=$(dirname "$HF_PARENT")

DIRS=(
    "$HF_GRANDPARENT"
    "$HF_PARENT"
    "$HF_PATH"
    "/workspace/scripts"
    "/workspace/logs"
)

for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            print_warning "Could not create $dir - you may need to create it manually"
        }
    else
        print_info "✓ $dir exists"
    fi
done

echo ""
print_info "✅ ML environment setup complete!"
echo ""

# ACTIVATE IF BEING SOURCED
if [ "$BEING_SOURCED" = true ]; then
    print_info "Activating ML environment..."
    source "$ENV_PATH/bin/activate"
    
    # Set environment variables
    export HF_HOME="$HF_PATH"
    export HUGGINGFACE_HUB_CACHE="$HF_PATH"
    export OMP_NUM_THREADS=32
    export MKL_NUM_THREADS=32
    export OPENBLAS_NUM_THREADS=32
    export VECLIB_MAXIMUM_THREADS=32
    export NUMEXPR_NUM_THREADS=32
    export OMP_PROC_BIND=true
    export OMP_PLACES=cores
    export MALLOC_ARENA_MAX=2
    
    # Set GPU architecture if detected
    if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
        export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"
        print_info "  TORCH_CUDA_ARCH_LIST: $TORCH_CUDA_ARCH_LIST"
    fi
    
    echo ""
    print_info "✓ Environment activated!"
    print_info "  Python: $(which python)"
    print_info "  Version: $(python --version)"
else
    # Show activation instructions when run as script
    print_info "To activate the environment:"
    echo ""
    print_command "source $ENV_PATH/activate_ml"
    echo ""
    print_info "Or use the alias (after reloading shell):"
    print_command "source ~/.bashrc"
    print_command "$ENV_NAME"
    echo ""
    print_info "Or source this script to create and activate:"
    print_command "source $0"
fi

#!/bin/bash

# Script: create_ml_env.sh
# Purpose: Create ML virtual environment and set up environment variables
# Usage: source create_ml_env.sh [--auto] [env_name]

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
elif [ -z "$ENV_TYPE" ]; then
    # Default to transformers in auto mode
    ENV_TYPE="transformers"
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

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v python &> /dev/null || ! python --version 2>&1 | grep -q "3.12"; then
    print_error "Python 3.12 is not active. Please run check_python.sh first."
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

if ! command -v uv &> /dev/null; then
    print_error "uv is not installed. Please run check_python.sh first."
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

# Create virtual environment
if [ -d "$ENV_PATH" ]; then
    print_warning "Environment $ENV_PATH already exists."
    if [ "$AUTO_MODE" = false ] && [ "$BEING_SOURCED" = false ]; then
        read -p "Do you want to recreate it? (y/n): " RECREATE
    else
        RECREATE="n"
        print_info "Using existing environment (use --auto to skip prompts)"
    fi
    
    if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
        print_info "Removing existing environment..."
        rm -rf "$ENV_PATH"
    fi
fi

if [ ! -d "$ENV_PATH" ]; then
    print_info "Creating virtual environment at $ENV_PATH..."
    uv venv "$ENV_PATH" --python 3.12
    
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

# Create activation script with environment variables
print_info "Creating activation script with ML environment variables..."

cat > "$ENV_PATH/activate_ml" << EOF
#!/bin/bash
# Activate virtual environment
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

echo "ML environment activated with:"
echo "  - Virtual env: $ENV_PATH"
echo "  - HF_HOME: \$HF_HOME"
echo "  - CPU threads: 32"
echo "  - Python: \$(python --version)"
EOF

chmod +x "$ENV_PATH/activate_ml"

# Add environment variables to .bashrc if not present
print_info "Updating ~/.bashrc with environment variables..."

if ! grep -q "HF_HOME=" ~/.bashrc; then
    cat >> ~/.bashrc << 'EOF'

# ML Environment Variables
export HF_HOME="/data/ml/models/huggingface"
export HUGGINGFACE_HUB_CACHE="/data/ml/models/huggingface"
EOF
    print_info "Added HF_HOME to ~/.bashrc"
fi

# Add alias if not present
if ! grep -q "alias $ENV_NAME=" ~/.bashrc; then
    echo "alias $ENV_NAME='source $ENV_PATH/activate_ml'" >> ~/.bashrc
    print_info "Added alias '$ENV_NAME' to ~/.bashrc"
fi

# Create directory structure
print_info "Creating directory structure..."
DIRS=(
    "/data/ml"
    "/data/ml/models"
    "/data/ml/models/huggingface"
    "/data/ml/scripts"
    "/data/ml/logs"
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
    export HF_HOME="/data/ml/models/huggingface"
    export HUGGINGFACE_HUB_CACHE="/data/ml/models/huggingface"
    export OMP_NUM_THREADS=32
    export MKL_NUM_THREADS=32
    export OPENBLAS_NUM_THREADS=32
    export VECLIB_MAXIMUM_THREADS=32
    export NUMEXPR_NUM_THREADS=32
    export OMP_PROC_BIND=true
    export OMP_PLACES=cores
    export MALLOC_ARENA_MAX=2
    
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

#!/bin/bash
# Script: install_models.sh
# Purpose: Download Hugging Face models to a custom location with easy replication
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_MODEL_PATH="/data/ml/models"
DEFAULT_MODEL="openai/gpt-oss-120b"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check and create directory
setup_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        print_info "Creating directory: $dir"
        mkdir -p "$dir"
        if [ $? -eq 0 ]; then
            print_info "Directory created successfully"
        else
            print_error "Failed to create directory"
            exit 1
        fi
    else
        print_info "Directory already exists: $dir"
    fi
}

# Parse command line arguments
MODEL_NAME=""
MODEL_PATH="$DEFAULT_MODEL_PATH"
QUANTIZATION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL_NAME="$2"
            shift 2
            ;;
        -p|--path)
            MODEL_PATH="$2"
            shift 2
            ;;
        -q|--quantization)
            QUANTIZATION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -m, --model MODEL_NAME     Model to download (e.g., 'openai/gpt-oss-120b')"
            echo "  -p, --path PATH           Custom path for models (default: $DEFAULT_MODEL_PATH)"
            echo "  -q, --quantization TYPE   Download quantized version (e.g., 'GGUF', 'GPTQ')"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 -m 'openai/gpt-oss-20b'"
            echo "  $0 -m 'Qwen/Qwen3-30B-A3B-Instruct-2507' -q GGUF"
            echo "  $0 -m 'deepseek-ai/DeepSeek-V3' -p /mnt/storage/models"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if required tools are installed
print_info "Checking required tools..."

# Check Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    print_info "Please install Python 3.11 with pyenv first"
    exit 1
fi

# Check uv
if ! command -v uv &> /dev/null; then
    print_error "uv is not installed"
    print_info "Please install uv with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Check if virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    print_warning "No virtual environment activated"
    print_info "Please activate your virtual environment first:"
    print_info "  source ~/ml_env/bin/activate"
    exit 1
fi

# Check if required packages are installed
python3 -c "import transformers, torch, huggingface_hub" 2>/dev/null
if [ $? -ne 0 ]; then
    print_error "Required Python packages not installed"
    print_info "Please install with:"
    print_info "  uv pip install transformers torch huggingface-hub"
    exit 1
fi

# Interactive mode if no model specified
if [ -z "$MODEL_NAME" ]; then
    echo "----------------------------------------"
    echo "Hugging Face Model Downloader"
    echo "----------------------------------------"
    echo ""
    echo "Popular models:"
    echo "1) openai/gpt-oss-120b (OpenAI GPT OSS 120B) - DEFAULT"
    echo "2) openai/gpt-oss-20b (OpenAI GPT OSS 20B)"
    echo "3) Qwen/Qwen3-Coder-480B-A35B-Instruct (Qwen3 480B Coder)"
    echo "4) Qwen/Qwen3-Coder-30B-A3B-Instruct (Qwen3 30B Coder)"
    echo "5) Qwen/Qwen3-235B-A22B-Instruct-2507 (Qwen3 235B Instruct)"
    echo "6) Qwen/Qwen3-30B-A3B-Instruct-2507 (Qwen3 30B Instruct)"
    echo "7) Qwen/Qwen3-235B-A22B-Thinking-2507 (Qwen3 235B Thinking)"
    echo "8) moonshotai/Kimi-K2-Instruct (Kimi K2 Instruct)"
    echo "9) moonshotai/Kimi-K2-Base (Kimi K2 Base)"
    echo "10) deepseek-ai/DeepSeek-R1-0528 (DeepSeek R1)"
    echo "11) deepseek-ai/DeepSeek-V3 (DeepSeek V3)"
    echo "12) zai-org/GLM-4.5 (GLM 4.5)"
    echo "13) zai-org/GLM-4.1V-9B-Thinking (GLM 4.1V 9B Thinking)"
    echo "14) zai-org/GLM-4.5-Air (GLM 4.5 Air)"
    echo "15) zai-org/GLM-4.5-FP8 (GLM 4.5 FP8)"
    echo "16) zai-org/GLM-4.5-Air-FP8 (GLM 4.5 Air FP8)"
    echo "17) zai-org/GLM-4.5-Base (GLM 4.5 Base)"
    echo "18) Custom (enter your own)"
    echo ""
    read -p "Select model (1-18) or press Enter for default [openai/gpt-oss-120b]: " choice
    
    case $choice in
        1|"") MODEL_NAME="openai/gpt-oss-120b" ;;
        2) MODEL_NAME="openai/gpt-oss-20b" ;;
        3) MODEL_NAME="Qwen/Qwen3-Coder-480B-A35B-Instruct" ;;
        4) MODEL_NAME="Qwen/Qwen3-Coder-30B-A3B-Instruct" ;;
        5) MODEL_NAME="Qwen/Qwen3-235B-A22B-Instruct-2507" ;;
        6) MODEL_NAME="Qwen/Qwen3-30B-A3B-Instruct-2507" ;;
        7) MODEL_NAME="Qwen/Qwen3-235B-A22B-Thinking-2507" ;;
        8) MODEL_NAME="moonshotai/Kimi-K2-Instruct" ;;
        9) MODEL_NAME="moonshotai/Kimi-K2-Base" ;;
        10) MODEL_NAME="deepseek-ai/DeepSeek-R1-0528" ;;
        11) MODEL_NAME="deepseek-ai/DeepSeek-V3" ;;
        12) MODEL_NAME="zai-org/GLM-4.5" ;;
        13) MODEL_NAME="zai-org/GLM-4.1V-9B-Thinking" ;;
        14) MODEL_NAME="zai-org/GLM-4.5-Air" ;;
        15) MODEL_NAME="zai-org/GLM-4.5-FP8" ;;
        16) MODEL_NAME="zai-org/GLM-4.5-Air-FP8" ;;
        17) MODEL_NAME="zai-org/GLM-4.5-Base" ;;
        18) 
            read -p "Enter model name (e.g., organization/model-name): " MODEL_NAME
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

# Check for quantization suffix
if [ -n "$QUANTIZATION" ]; then
    case $QUANTIZATION in
        GGUF|gguf)
            # Append -GGUF to model name if not already there
            if [[ ! "$MODEL_NAME" == *"-GGUF" ]]; then
                MODEL_NAME="${MODEL_NAME}-GGUF"
            fi
            ;;
        GPTQ|gptq)
            # Append -GPTQ to model name if not already there
            if [[ ! "$MODEL_NAME" == *"-GPTQ"* ]]; then
                MODEL_NAME="${MODEL_NAME}-GPTQ"
            fi
            ;;
    esac
fi

# Setup directories
print_info "Setting up model directory..."
setup_directory "$MODEL_PATH"
setup_directory "$MODEL_PATH/huggingface"
setup_directory "$MODEL_PATH/huggingface/hub"

# Export environment variables (use only HF_HOME to avoid deprecation warning)
export HF_HOME="$MODEL_PATH/huggingface"
export HUGGINGFACE_HUB_CACHE="$MODEL_PATH/huggingface"

print_info "Environment variables set:"
print_info "  HF_HOME=$HF_HOME"

# Create Python download script
PYTHON_SCRIPT=$(mktemp /tmp/download_model_XXXXXX.py)
cat > "$PYTHON_SCRIPT" << EOF
#!/usr/bin/env python3
import os
import sys
import json
from pathlib import Path

# Set environment variables before imports
os.environ['HF_HOME'] = '$MODEL_PATH/huggingface'

try:
    from huggingface_hub import snapshot_download, HfApi
    from transformers import AutoConfig
    import torch
except ImportError as e:
    print(f"Error: Missing required package: {e}")
    print("Please install with: uv pip install transformers torch huggingface-hub")
    sys.exit(1)

model_name = "$MODEL_NAME"

print(f"\\n{'='*60}")
print(f"Model: {model_name}")
print(f"Download location: {os.environ['HF_HOME']}")
print(f"{'='*60}\\n")

try:
    # Check if model exists and get info
    api = HfApi()
    try:
        model_info = api.model_info(model_name)
        
        # Calculate total size properly
        total_size = 0
        for sibling in model_info.siblings:
            if hasattr(sibling, 'size') and sibling.size is not None:
                total_size += sibling.size
        
        if total_size > 0:
            print(f"Total model size: {total_size / 1e9:.1f} GB")
    except Exception as e:
        print(f"Could not fetch model info: {e}")
    
    # Download model (without deprecated resume_download parameter)
    print(f"\\nDownloading {model_name}...")
    local_path = snapshot_download(
        repo_id=model_name,
        cache_dir=os.environ['HF_HOME'],
        max_workers=4
    )
    
    print(f"\\n✓ Model downloaded to: {local_path}")
    
    # Test loading config - with better error handling
    print("\\nTesting model configuration...")
    try:
        config = AutoConfig.from_pretrained(model_name, cache_dir=os.environ['HF_HOME'], trust_remote_code=True)
        print(f"✓ Model type: {config.model_type}")
        print(f"✓ Hidden size: {getattr(config, 'hidden_size', 'N/A')}")
        print(f"✓ Number of layers: {getattr(config, 'num_hidden_layers', 'N/A')}")
    except KeyError as e:
        print(f"⚠️  Model uses custom architecture '{e.args[0]}' - may require custom code to load")
        print("✓ Model files downloaded successfully anyway!")
    except Exception as e:
        print(f"⚠️  Could not load config: {e}")
        print("✓ Model files downloaded successfully anyway!")
    
    # Save model info
    info_file = Path("$MODEL_PATH") / "downloaded_models.json"
    model_info_data = {
        "model_name": model_name,
        "local_path": local_path,
        "cache_dir": os.environ['HF_HOME']
    }
    
    # Append to existing file
    existing_data = []
    if info_file.exists():
        with open(info_file, 'r') as f:
            try:
                existing_data = json.load(f)
            except:
                existing_data = []
    
    # Add new entry (avoid duplicates)
    if not any(m['model_name'] == model_name for m in existing_data):
        existing_data.append(model_info_data)
    
    with open(info_file, 'w') as f:
        json.dump(existing_data, f, indent=2)
    
    print(f"\\n✓ Model info saved to: {info_file}")
    print("\\n✅ Download completed successfully!")
    
except Exception as e:
    print(f"\\n❌ Error downloading model: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

# Run the download script
print_info "Starting model download..."
python3 "$PYTHON_SCRIPT"
RESULT=$?

# Cleanup
rm -f "$PYTHON_SCRIPT"

if [ $RESULT -eq 0 ]; then
    print_info "Model downloaded successfully!"
    
    # Create a reference script for this model
    MODEL_SAFE_NAME=$(echo "$MODEL_NAME" | sed 's/[^a-zA-Z0-9-]/_/g')
    LOAD_SCRIPT="$MODEL_PATH/load_${MODEL_SAFE_NAME}.sh"
    
    cat > "$LOAD_SCRIPT" << EOF
#!/bin/bash
# Auto-generated script to load $MODEL_NAME
export HF_HOME="$MODEL_PATH/huggingface"
echo "Environment set for $MODEL_NAME"
echo "Model location: \$HF_HOME"
echo ""
echo "To use in Python:"
echo "from transformers import AutoModelForCausalLM, AutoTokenizer"
echo "model = AutoModelForCausalLM.from_pretrained('$MODEL_NAME', trust_remote_code=True)"
echo "tokenizer = AutoTokenizer.from_pretrained('$MODEL_NAME', trust_remote_code=True)"
echo ""
echo "To serve with vLLM:"
echo "vllm serve $MODEL_NAME --trust-remote-code"
echo ""
echo "To serve with SGLang:"
echo "python -m sglang.launch_server --model-path $MODEL_NAME --trust-remote-code"
EOF
    
    chmod +x "$LOAD_SCRIPT"
    print_info "Created load script: $LOAD_SCRIPT"
    
    echo ""
    echo "=========================================="
    echo "✅ Setup Complete!"
    echo "=========================================="
    echo "Model: $MODEL_NAME"
    echo "Location: $MODEL_PATH/huggingface"
    echo ""
    echo "To use this model in the future:"
    echo "1. Set environment variable:"
    echo "   export HF_HOME='$MODEL_PATH/huggingface'"
    echo ""
    echo "2. Or source the load script:"
    echo "   source $LOAD_SCRIPT"
    echo ""
    echo "Note: If using custom architecture models, use --trust-remote-code flag"
    echo "=========================================="
else
    print_error "Model download failed!"
    exit 1
fi

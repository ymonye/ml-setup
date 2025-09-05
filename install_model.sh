#!/bin/bash
# Script: install_models.sh
# Purpose: Download Hugging Face models to a custom location with easy replication
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_HF_PATH="/data/ml/models/huggingface"
DEFAULT_MODEL="PrimeIntellect/INTELLECT-2"

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
HF_PATH=""
QUANTIZATION=""
AUTO_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL_NAME="$2"
            shift 2
            ;;
        -p|--path)
            HF_PATH="$2"
            shift 2
            ;;
        -q|--quantization)
            QUANTIZATION="$2"
            shift 2
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -m, --model MODEL_NAME     Model to download (e.g., 'openai/gpt-oss-120b')"
            echo "  -p, --path PATH           Custom path for models (default: $DEFAULT_HF_PATH or \$HF_HOME)"
            echo "  -q, --quantization TYPE   Download quantized version (e.g., 'GGUF', 'GPTQ')"
            echo "  --auto                    Use default settings without prompting"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 -m 'PrimeIntellect/INTELLECT-2'"
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

# Determine HuggingFace path
# Priority: 1) Command line arg, 2) HF_HOME env var, 3) HUGGINGFACE_HUB_CACHE env var, 4) Interactive prompt/default
if [ -n "$HF_PATH" ]; then
    # Use command line argument
    print_info "Using HuggingFace path from command line: $HF_PATH"
elif [ -n "$HF_HOME" ]; then
    # Use existing HF_HOME environment variable
    HF_PATH="$HF_HOME"
    print_info "Using existing HF_HOME environment variable: $HF_PATH"
elif [ -n "$HUGGINGFACE_HUB_CACHE" ]; then
    # Use existing HUGGINGFACE_HUB_CACHE environment variable
    HF_PATH="$HUGGINGFACE_HUB_CACHE"
    print_info "Using existing HUGGINGFACE_HUB_CACHE environment variable: $HF_PATH"
else
    # No environment variable set, ask user (same logic as 03_setup_env.sh)
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
fi

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
python3 -c "import huggingface_hub" 2>/dev/null
if [ $? -ne 0 ]; then
    print_error "Required Python package not installed"
    print_info "Please install with:"
    print_info "  uv pip install huggingface-hub"
    exit 1
fi

# Interactive mode if no model specified
if [ -z "$MODEL_NAME" ]; then
    echo "----------------------------------------"
    echo "Hugging Face Model Downloader"
    echo "----------------------------------------"
    echo ""
    echo "Popular models:"
    echo ""
    echo "Prime Intellect Models:"
    echo "1) PrimeIntellect/INTELLECT-2 (INTELLECT-2 32B) - DEFAULT"
    echo ""
    echo "OpenAI Models:"
    echo "2) openai/gpt-oss-20b (OpenAI GPT OSS 20B)"
    echo "3) openai/gpt-oss-120b (OpenAI GPT OSS 120B)"
    echo ""
    echo "DeepSeek Models:"
    echo "4) deepseek-ai/DeepSeek-V3 (DeepSeek V3)"
    echo "5) deepseek-ai/DeepSeek-R1-0528 (DeepSeek R1)"
    echo ""
    echo "Moonshot AI Models:"
    echo "6) moonshotai/Kimi-K2-Base (Kimi K2 Base)"
    echo "7) moonshotai/Kimi-K2-Instruct (Kimi K2 Instruct)"
    echo ""
    echo "Qwen Models:"
    echo "8) Qwen/Qwen3-30B-A3B-Instruct-2507 (Qwen3 30B Instruct)"
    echo "9) Qwen/Qwen3-30B-A3B-Instruct-2507-FP8 (Qwen3 30B Instruct FP8)"
    echo "10) Qwen/Qwen3-30B-A3B-Thinking-2507 (Qwen3 30B Thinking)"
    echo "11) Qwen/Qwen3-30B-A3B-Thinking-2507-FP8 (Qwen3 30B Thinking FP8)"
    echo "12) Qwen/Qwen3-235B-A22B-Instruct-2507 (Qwen3 235B Instruct)"
    echo "13) Qwen/Qwen3-235B-A22B-Instruct-2507-FP8 (Qwen3 235B Instruct FP8)"
    echo "14) Qwen/Qwen3-235B-A22B-Thinking-2507 (Qwen3 235B Thinking)"
    echo "15) Qwen/Qwen3-235B-A22B-Thinking-2507-FP8 (Qwen3 235B Thinking FP8)"
    echo "16) Qwen/Qwen3-Coder-30B-A3B-Instruct (Qwen3 30B Coder)"
    echo "17) Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8 (Qwen3 30B Coder FP8)"
    echo "18) Qwen/Qwen3-Coder-480B-A35B-Instruct (Qwen3 480B Coder)"
    echo "19) Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8 (Qwen3 480B Coder FP8)"
    echo ""
    echo "GLM Models:"
    echo "20) zai-org/GLM-4.1V-9B-Thinking (GLM 4.1V 9B Thinking)"
    echo "21) zai-org/GLM-4.5 (GLM 4.5)"
    echo "22) zai-org/GLM-4.5-FP8 (GLM 4.5 FP8)"
    echo "23) zai-org/GLM-4.5-Air (GLM 4.5 Air)"
    echo "24) zai-org/GLM-4.5-Air-FP8 (GLM 4.5 Air FP8)"
    echo "25) zai-org/GLM-4.5-Base (GLM 4.5 Base)"
    echo ""
    echo "Hermes Models:"
    echo "26) NousResearch/Hermes-4-14B (Hermes 4 14B)"
    echo "27) NousResearch/Hermes-4-14B-FP8 (Hermes 4 14B FP8)"
    echo "28) NousResearch/Hermes-4-70B (Hermes 4 70B)"
    echo "29) NousResearch/Hermes-4-70B-FP8 (Hermes 4 70B FP8)"
    echo "30) NousResearch/Hermes-4-405B (Hermes 4 405B)"
    echo "31) NousResearch/Hermes-4-405B-FP8 (Hermes 4 405B FP8)"
    echo ""
    echo "32) Custom (enter your own)"
    echo ""
    read -p "Select model (1-32) or press Enter for default [PrimeIntellect/INTELLECT-2]: " choice
    
    case $choice in
        1|"") MODEL_NAME="PrimeIntellect/INTELLECT-2" ;;
        2) MODEL_NAME="openai/gpt-oss-20b" ;;
        3) MODEL_NAME="openai/gpt-oss-120b" ;;
        4) MODEL_NAME="deepseek-ai/DeepSeek-V3" ;;
        5) MODEL_NAME="deepseek-ai/DeepSeek-R1-0528" ;;
        6) MODEL_NAME="moonshotai/Kimi-K2-Base" ;;
        7) MODEL_NAME="moonshotai/Kimi-K2-Instruct" ;;
        8) MODEL_NAME="Qwen/Qwen3-30B-A3B-Instruct-2507" ;;
        9) MODEL_NAME="Qwen/Qwen3-30B-A3B-Instruct-2507-FP8" ;;
        10) MODEL_NAME="Qwen/Qwen3-30B-A3B-Thinking-2507" ;;
        11) MODEL_NAME="Qwen/Qwen3-30B-A3B-Thinking-2507-FP8" ;;
        12) MODEL_NAME="Qwen/Qwen3-235B-A22B-Instruct-2507" ;;
        13) MODEL_NAME="Qwen/Qwen3-235B-A22B-Instruct-2507-FP8" ;;
        14) MODEL_NAME="Qwen/Qwen3-235B-A22B-Thinking-2507" ;;
        15) MODEL_NAME="Qwen/Qwen3-235B-A22B-Thinking-2507-FP8" ;;
        16) MODEL_NAME="Qwen/Qwen3-Coder-30B-A3B-Instruct" ;;
        17) MODEL_NAME="Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8" ;;
        18) MODEL_NAME="Qwen/Qwen3-Coder-480B-A35B-Instruct" ;;
        19) MODEL_NAME="Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8" ;;
        20) MODEL_NAME="zai-org/GLM-4.1V-9B-Thinking" ;;
        21) MODEL_NAME="zai-org/GLM-4.5" ;;
        22) MODEL_NAME="zai-org/GLM-4.5-FP8" ;;
        23) MODEL_NAME="zai-org/GLM-4.5-Air" ;;
        24) MODEL_NAME="zai-org/GLM-4.5-Air-FP8" ;;
        25) MODEL_NAME="zai-org/GLM-4.5-Base" ;;
        26) MODEL_NAME="NousResearch/Hermes-4-14B" ;;
        27) MODEL_NAME="NousResearch/Hermes-4-14B-FP8" ;;
        28) MODEL_NAME="NousResearch/Hermes-4-70B" ;;
        29) MODEL_NAME="NousResearch/Hermes-4-70B-FP8" ;;
        30) MODEL_NAME="NousResearch/Hermes-4-405B" ;;
        31) MODEL_NAME="NousResearch/Hermes-4-405B-FP8" ;;
        32) 
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
setup_directory "$HF_PATH"
setup_directory "$HF_PATH/hub"

# Export environment variables (use only HF_HOME to avoid deprecation warning)
export HF_HOME="$HF_PATH"
export HUGGINGFACE_HUB_CACHE="$HF_PATH"

print_info "Environment variables set:"
print_info "  HF_HOME=$HF_HOME"

# Create Python download script
PYTHON_SCRIPT=$(mktemp /tmp/download_model_XXXXXX.py)
cat > "$PYTHON_SCRIPT" << EOF
#!/usr/bin/env python3
import os
import sys
import json
import hashlib
from pathlib import Path
from datetime import datetime

# Set environment variables before imports
os.environ['HF_HOME'] = '$HF_PATH'

try:
    from huggingface_hub import snapshot_download, HfApi, scan_cache_dir
    from huggingface_hub.utils import LocalEntryNotFoundError
except ImportError as e:
    print(f"Error: Missing required package: {e}")
    print("Please install with: uv pip install huggingface-hub")
    sys.exit(1)

model_name = "$MODEL_NAME"

print(f"\\n{'='*60}")
print(f"Model: {model_name}")
print(f"Download location: {os.environ['HF_HOME']}")
print(f"{'='*60}\\n")

def check_model_completeness(model_name, cache_dir):
    """
    Check if model is already fully downloaded and verify integrity
    """
    try:
        api = HfApi()
        
        # Get expected files from remote
        print("Checking remote repository...")
        remote_info = api.model_info(model_name)
        expected_files = {}
        total_size = 0
        
        for sibling in remote_info.siblings:
            if hasattr(sibling, 'rfilename') and hasattr(sibling, 'size'):
                expected_files[sibling.rfilename] = {
                    'size': sibling.size,
                    'lfs': getattr(sibling, 'lfs', None)
                }
                if sibling.size:
                    total_size += sibling.size
        
        print(f"Expected model size: {total_size / 1e9:.1f} GB")
        print(f"Number of files expected: {len(expected_files)}")
        
        # Check local cache
        print("\\nChecking local cache...")
        cache_info = scan_cache_dir(cache_dir)
        
        # Find our model in cache
        local_model = None
        for repo in cache_info.repos:
            if repo.repo_id == model_name:
                local_model = repo
                break
        
        if not local_model:
            print("Model not found in local cache")
            return False, expected_files, 0
        
        # Check each expected file
        missing_files = []
        corrupted_files = []
        local_size = 0
        
        for filename, file_info in expected_files.items():
            file_found = False
            for revision in local_model.revisions:
                for cached_file in revision.files:
                    # Match by file path
                    if cached_file.file_path.name == filename.split('/')[-1]:
                        file_found = True
                        local_size += cached_file.size_on_disk
                        
                        # Check file size
                        if file_info['size'] and cached_file.size_on_disk != file_info['size']:
                            corrupted_files.append(filename)
                            print(f"  ❌ Size mismatch: {filename}")
                            print(f"     Expected: {file_info['size']}, Got: {cached_file.size_on_disk}")
                        break
                if file_found:
                    break
            
            if not file_found:
                missing_files.append(filename)
                print(f"  ❌ Missing: {filename}")
        
        # Summary
        print(f"\\nLocal cache summary:")
        print(f"  Total size on disk: {local_size / 1e9:.1f} GB")
        print(f"  Files found: {len(expected_files) - len(missing_files)}/{len(expected_files)}")
        
        if missing_files:
            print(f"  Missing files: {len(missing_files)}")
            for f in missing_files[:5]:  # Show first 5 missing
                print(f"    - {f}")
            if len(missing_files) > 5:
                print(f"    ... and {len(missing_files) - 5} more")
        
        if corrupted_files:
            print(f"  Corrupted files: {len(corrupted_files)}")
            for f in corrupted_files[:5]:
                print(f"    - {f}")
        
        is_complete = len(missing_files) == 0 and len(corrupted_files) == 0
        
        if is_complete:
            print("\\n✅ Model is fully downloaded and verified!")
            # Get the local path
            try:
                from huggingface_hub import model_info
                local_path = snapshot_download(
                    repo_id=model_name,
                    cache_dir=cache_dir,
                    local_files_only=True
                )
                return True, expected_files, local_size, local_path
            except:
                return True, expected_files, local_size, None
        else:
            print("\\n⚠️  Model is incomplete or has corrupted files")
            return False, expected_files, local_size
    
    except Exception as e:
        print(f"Error checking model completeness: {e}")
        return False, {}, 0

# Check if model is already downloaded
result = check_model_completeness(model_name, os.environ['HF_HOME'])

if len(result) == 4 and result[0]:  # Model is complete
    is_complete, expected_files, local_size, local_path = result
    print("\\n" + "="*60)
    print("MODEL ALREADY FULLY DOWNLOADED")
    print("="*60)
    print(f"Model: {model_name}")
    if local_path:
        print(f"Location: {local_path}")
    print(f"Size: {local_size / 1e9:.1f} GB")
    print("\\nNo download needed - model is ready to use!")
    
    # Save to downloaded_models.json
    info_file = Path("$HF_PATH").parent / "downloaded_models.json"
    model_info_data = {
        "model_name": model_name,
        "local_path": local_path if local_path else "cached",
        "cache_dir": os.environ['HF_HOME'],
        "size_gb": local_size / 1e9,
        "verified_at": datetime.now().isoformat()
    }
    
    existing_data = []
    if info_file.exists():
        with open(info_file, 'r') as f:
            try:
                existing_data = json.load(f)
            except:
                existing_data = []
    
    # Update or add entry
    model_found = False
    for i, m in enumerate(existing_data):
        if m['model_name'] == model_name:
            existing_data[i] = model_info_data
            model_found = True
            break
    
    if not model_found:
        existing_data.append(model_info_data)
    
    with open(info_file, 'w') as f:
        json.dump(existing_data, f, indent=2)
    
    sys.exit(0)

# Model is not complete, proceed with download
print("\\n" + "="*60)
print("STARTING DOWNLOAD")
print("="*60)

# Create a progress file to track download
progress_file = Path("$HF_PATH").parent / f".download_progress_{model_name.replace('/', '_')}.json"

try:
    # Save download start info
    progress_data = {
        "model_name": model_name,
        "started_at": datetime.now().isoformat(),
        "status": "downloading"
    }
    with open(progress_file, 'w') as f:
        json.dump(progress_data, f, indent=2)
    
    print(f"\\nDownloading {model_name}...")
    print("Note: Download will resume automatically if interrupted")
    
    # Download with resume capability
    local_path = snapshot_download(
        repo_id=model_name,
        cache_dir=os.environ['HF_HOME'],
        max_workers=4,
        force_download=False,  # This allows resuming
        local_files_only=False
    )
    
    print(f"\\n✓ Model downloaded to: {local_path}")
    
    # Verify completeness after download
    print("\\nVerifying download...")
    final_check = check_model_completeness(model_name, os.environ['HF_HOME'])
    
    if final_check[0]:
        print("\\n✅ Download completed and verified successfully!")
        
        # Update progress file
        progress_data['status'] = 'completed'
        progress_data['completed_at'] = datetime.now().isoformat()
        progress_data['local_path'] = local_path
        with open(progress_file, 'w') as f:
            json.dump(progress_data, f, indent=2)
        
        # Save model info
        info_file = Path("$HF_PATH").parent / "downloaded_models.json"
        model_info_data = {
            "model_name": model_name,
            "local_path": local_path,
            "cache_dir": os.environ['HF_HOME'],
            "downloaded_at": datetime.now().isoformat()
        }
        
        # Append to existing file
        existing_data = []
        if info_file.exists():
            with open(info_file, 'r') as f:
                try:
                    existing_data = json.load(f)
                except:
                    existing_data = []
        
        # Update or add entry
        model_found = False
        for i, m in enumerate(existing_data):
            if m['model_name'] == model_name:
                existing_data[i] = model_info_data
                model_found = True
                break
        
        if not model_found:
            existing_data.append(model_info_data)
        
        with open(info_file, 'w') as f:
            json.dump(existing_data, f, indent=2)
        
        print(f"\\n✓ Model info saved to: {info_file}")
        
        # Clean up progress file
        if progress_file.exists():
            progress_file.unlink()
    else:
        print("\\n⚠️  Download may be incomplete. Run this script again to resume.")
        progress_data['status'] = 'incomplete'
        with open(progress_file, 'w') as f:
            json.dump(progress_data, f, indent=2)
    
except KeyboardInterrupt:
    print("\\n⚠️  Download interrupted by user")
    print("Run this script again to resume the download")
    if progress_file.exists():
        progress_data['status'] = 'interrupted'
        progress_data['interrupted_at'] = datetime.now().isoformat()
        with open(progress_file, 'w') as f:
            json.dump(progress_data, f, indent=2)
    sys.exit(130)
    
except Exception as e:
    print(f"\\n❌ Error downloading model: {e}")
    import traceback
    traceback.print_exc()
    
    if progress_file.exists():
        progress_data['status'] = 'error'
        progress_data['error'] = str(e)
        progress_data['error_at'] = datetime.now().isoformat()
        with open(progress_file, 'w') as f:
            json.dump(progress_data, f, indent=2)
    
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
    # Store the load script in the parent directory of HF_PATH
    LOAD_SCRIPT="$(dirname "$HF_PATH")/load_${MODEL_SAFE_NAME}.sh"
    
    cat > "$LOAD_SCRIPT" << EOF
#!/bin/bash
# Auto-generated script to load $MODEL_NAME
export HF_HOME="$HF_PATH"
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
    echo "Location: $HF_PATH"
    echo ""
    echo "To use this model in the future:"
    echo "1. Set environment variable:"
    echo "   export HF_HOME='$HF_PATH'"
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

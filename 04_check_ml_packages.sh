#!/bin/bash
# Script: check_ml_packages.sh
# Purpose: Check and install ML packages (PyTorch, SGLang, vLLM, etc.)
# Usage: ./check_ml_packages.sh [-y]
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
# Parse arguments
AUTO_YES=false
if [[ "$1" == "-y" ]]; then
    AUTO_YES=true
fi
# Check if in virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    print_error "No virtual environment activated!"
    print_info "Please activate your ML environment first:"
    print_command "source ~/ml_env/activate_ml"
    exit 1
fi
print_info "Virtual environment: $VIRTUAL_ENV"
echo ""
# Function to check Python package
check_package() {
    local pkg=$1
    local import_name=${2:-$pkg}
    import_name=$(echo "$import_name" | sed 's/-/_/g')
    
    if python -c "import $import_name" 2>/dev/null; then
        echo "installed"
    else
        echo "missing"
    fi
}
# Ask for installation
ask_install() {
    local prompt=$1
    if [ "$AUTO_YES" = true ]; then
        return 0
    else
        read -p "$prompt (y/n): " response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}
# Run installation command
run_install() {
    local cmd=$1
    print_info "Running: $cmd"
    eval "$cmd"
    if [ $? -eq 0 ]; then
        print_info "✓ Installation successful"
        return 0
    else
        print_error "✗ Installation failed"
        return 1
    fi
}
# Check packages
print_info "Checking ML packages..."
# Core packages - Fixed import names
declare -A PACKAGES=(
    ["torch"]="torch"
    ["torchvision"]="torchvision"
    ["torchaudio"]="torchaudio"
    ["transformers"]="transformers"
    ["accelerate"]="accelerate"
    ["datasets"]="datasets"
    ["tokenizers"]="tokenizers"
    ["sentencepiece"]="sentencepiece"
    ["protobuf"]="google.protobuf"  # Fixed: protobuf imports as google.protobuf
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
    ["openai-harmony"]="openai_harmony"
)
# Check core packages
MISSING_CORE=()
print_info "Core packages:"
for pkg in "${!PACKAGES[@]}"; do
    status=$(check_package "$pkg" "${PACKAGES[$pkg]}")
    if [ "$status" = "installed" ]; then
        print_info "  ✓ $pkg"
    else
        print_error "  ✗ $pkg"
        MISSING_CORE+=($pkg)
    fi
done
echo ""
# Install missing core packages
if [ ${#MISSING_CORE[@]} -gt 0 ]; then
    print_warning "Missing ${#MISSING_CORE[@]} core packages"
    
    # PyTorch group
    TORCH_MISSING=()
    for pkg in torch torchvision torchaudio; do
        if [[ " ${MISSING_CORE[@]} " =~ " $pkg " ]]; then
            TORCH_MISSING+=($pkg)
        fi
    done
    
    if [ ${#TORCH_MISSING[@]} -gt 0 ]; then
        print_info "PyTorch packages missing: ${TORCH_MISSING[*]}"
        if ask_install "Install PyTorch packages (GPU version)?"; then
            run_install "uv pip install torch==2.7.0 torchvision==0.20.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu124"
        fi
        echo ""
    fi
    
    # Other core packages
    OTHER_MISSING=()
    for pkg in "${MISSING_CORE[@]}"; do
        if [[ ! "$pkg" =~ ^(torch|torchvision|torchaudio)$ ]]; then
            OTHER_MISSING+=($pkg)
        fi
    done
    
    if [ ${#OTHER_MISSING[@]} -gt 0 ]; then
        print_info "Other core packages missing: ${OTHER_MISSING[*]}"
        if ask_install "Install core ML packages?"; then
            run_install "uv pip install ${OTHER_MISSING[*]}"
        fi
        echo ""
    fi
else
    print_info "✓ All core packages installed"
fi
# Check inference frameworks
echo ""
print_info "Checking inference frameworks..."
# Check if nvcc is available for optimized builds
HAS_NVCC=false
if command -v nvcc &> /dev/null; then
    HAS_NVCC=true
    print_info "✓ CUDA toolkit (nvcc) available"
else
    print_warning "✗ CUDA toolkit (nvcc) not found - some packages will use fallback versions"
fi
echo ""
# SGLang
print_info "Checking SGLang..."
SGLANG_STATUS=$(check_package "sglang" "sglang")
if [ "$SGLANG_STATUS" = "installed" ]; then
    print_info "  ✓ SGLang installed"
else
    print_warning "  ✗ SGLang not installed"
    if ask_install "Install SGLang?"; then
        if [ "$HAS_NVCC" = true ]; then
            print_info "CUDA toolkit detected, installing SGLang with all features..."
            if ! run_install 'uv pip install "sglang[all]"'; then
                print_warning "Full installation failed, trying base SGLang..."
                run_install "uv pip install sglang"
            fi
        else
            print_info "No CUDA toolkit, installing base SGLang..."
            run_install "uv pip install sglang"
        fi
    fi
fi
# vLLM (GPT-OSS enabled version only)
print_info "Checking vLLM (GPT-OSS enabled)..."
VLLM_STATUS=$(check_package "vllm" "vllm")
if [ "$VLLM_STATUS" = "installed" ]; then
    VLLM_VERSION=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "unknown")
    print_info "  ✓ vLLM installed (version: $VLLM_VERSION)"
else
    print_warning "  ✗ vLLM not installed"
    if ask_install "Install GPT-OSS enabled vLLM?"; then
        print_info "Installing GPT-OSS enabled vLLM..."
        run_install "uv pip install --pre vllm==0.10.1+gptoss --extra-index-url https://wheels.vllm.ai/gpt-oss/ --extra-index-url https://download.pytorch.org/whl/nightly/cu128 --index-strategy unsafe-best-match"
    fi
fi
# llama.cpp
print_info "Checking llama.cpp..."
LLAMA_STATUS=$(check_package "llama-cpp-python" "llama_cpp")
if [ "$LLAMA_STATUS" = "installed" ]; then
    print_info "  ✓ llama.cpp installed"
else
    print_warning "  ✗ llama.cpp not installed"
    if ask_install "Install llama.cpp Python bindings?"; then
        if [ "$HAS_NVCC" = true ]; then
            print_info "Building with CUDA support..."
            run_install 'CMAKE_ARGS="-DLLAMA_CUDA=ON" uv pip install llama-cpp-python[server]'
        else
            print_info "Building with CPU optimizations..."
            run_install 'CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS" uv pip install llama-cpp-python[server]'
        fi
    fi
fi
# Optional optimization packages
echo ""
print_info "Checking optional optimization packages..."
# ONNX Runtime
ONNX_STATUS=$(check_package "onnxruntime" "onnxruntime")
if [ "$ONNX_STATUS" = "installed" ]; then
    print_info "  ✓ ONNX Runtime"
else
    print_warning "  ✗ ONNX Runtime (optional - alternative inference engine)"
    if ask_install "Install ONNX Runtime (GPU version)?"; then
        run_install "uv pip install onnxruntime-gpu"
    fi
fi
# Optimum (Hugging Face optimization library)
OPTIMUM_STATUS=$(check_package "optimum" "optimum")
if [ "$OPTIMUM_STATUS" = "installed" ]; then
    print_info "  ✓ Optimum"
else
    print_warning "  ✗ Optimum (optional - Hugging Face optimization library)"
    if ask_install "Install Optimum?"; then
        run_install "uv pip install optimum"
    fi
fi
# Summary
echo ""
echo "=============================================="
print_info "Installation Summary:"
echo ""
# Quick check of key packages
print_info "Core ML Stack:"
for pkg in torch transformers; do
    if python -c "import $pkg" 2>/dev/null; then
        version=$(python -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "unknown")
        print_info "  ✓ $pkg ($version)"
    else
        print_error "  ✗ $pkg"
    fi
done
echo ""
print_info "Inference Frameworks:"
# Check each framework with proper import names
echo -n "  "
if python -c "import sglang" 2>/dev/null; then
    version=$(python -c "import sglang; print(sglang.__version__)" 2>/dev/null || echo "installed")
    print_info "✓ SGLang ($version)"
else
    print_warning "✗ SGLang (optional)"
fi
echo -n "  "
if python -c "import vllm" 2>/dev/null; then
    version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "installed")
    if [[ "$version" == *"gptoss"* ]]; then
        print_info "✓ vLLM ($version) - GPT-OSS enabled"
    else
        print_info "✓ vLLM ($version)"
    fi
else
    print_warning "✗ vLLM (optional)"
fi
echo -n "  "
if python -c "import llama_cpp" 2>/dev/null; then
    print_info "✓ llama-cpp-python"
else
    print_warning "✗ llama-cpp-python (optional)"
fi
echo ""
print_info "Optional Optimizations:"
# Check optimization packages
echo -n "  "
if python -c "import onnxruntime" 2>/dev/null; then
    print_info "✓ ONNX Runtime"
else
    print_warning "✗ ONNX Runtime"
fi
echo -n "  "
if python -c "import optimum" 2>/dev/null; then
    print_info "✓ Optimum"
else
    print_warning "✗ Optimum"
fi
echo ""
print_info "Environment Details:"
print_info "- Python: $(python --version 2>&1)"
print_info "- Virtual environment: $VIRTUAL_ENV"
if [ "$HAS_NVCC" = true ]; then
    print_info "- CUDA toolkit: $(nvcc --version | grep release | awk '{print $6}')"
else
    print_info "- CUDA toolkit: Not installed"
fi
echo ""
print_info "To verify GPU availability:"
print_command "python -c 'import torch; print(f\"CUDA available: {torch.cuda.is_available()}\")'"

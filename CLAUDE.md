# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a machine learning environment setup collection for Ubuntu 22.04+. It contains a suite of shell scripts designed to systematically install and configure a complete ML development environment with Python, PyTorch, and various inference frameworks.

## Key Scripts and Commands

### Environment Setup (Run in Order)
1. `./01_check_dependencies.sh [-y]` - Install system packages and CUDA toolkit
2. `./02_check_python.sh [-y]` - Install Python 3.12 via pyenv and uv package manager
3. `./03_check_ml_env.sh [--auto] [env_name]` - Create ML virtual environment (default: ml_env)
4. `./04_check_ml_packages.sh [-y]` - Install ML packages (PyTorch, SGLang, vLLM, etc.)
5. `./05_check_final.sh` - Final verification of complete setup

### Model Management
- `./install_model.sh [-m model_name] [-p path] [-q quantization]` - Download HuggingFace models
- `source ./launch_ml_env.sh [env_name]` - Activate ML environment with optimizations

### Script Arguments
- `-y` or `--auto`: Auto-accept all prompts (non-interactive mode)
- All scripts support `-h` or `--help` for detailed usage

## Architecture and Design Patterns

### Sequential Setup Design
Scripts are numbered and designed to run in sequence, with each step building on the previous:
- Dependencies → Python toolchain → Virtual environment → ML packages → Verification

### Error Handling Pattern
All scripts follow consistent patterns:
- Colored output functions (print_info, print_error, print_warning)
- Prerequisite checking before major operations
- Exit codes and status tracking (INSTALL_SUCCESS variables)
- Cleanup on failure (temp files, partial installations)

### Environment Management
- Uses pyenv for Python version management (3.12 specifically)
- Uses uv for fast Python package installation
- Virtual environments stored as `~/ml_env` (or custom name)
- Environment variables set for ML optimizations (NUMA, CPU threads, HuggingFace cache)

### Model Storage Architecture
- Models stored in `/data/ml/models/huggingface/`
- Environment variables: HF_HOME and HUGGINGFACE_HUB_CACHE
- Auto-generated load scripts for each downloaded model
- JSON tracking of downloaded models in `downloaded_models.json`

## Important Technical Details

### CPU Optimizations
Scripts configure for 32-core systems:
- OMP_NUM_THREADS=32, MKL_NUM_THREADS=32, etc.
- NUMA optimization with OMP_PROC_BIND=true
- Memory optimization with MALLOC_ARENA_MAX=2

### CUDA Support
- Automatically detects nvcc availability
- Falls back to CPU-only versions when CUDA unavailable
- Adds CUDA paths to environment when detected
- Builds packages with CUDA support when possible (llama-cpp-python, SGLang)

### Package Management Strategy
- Uses uv for faster installs than pip
- Groups related packages (PyTorch ecosystem, Transformers ecosystem)
- Handles complex builds (llama-cpp-python with CMAKE_ARGS)
- Optional vs required package distinction

## Common Workflow
```bash
# Complete setup from scratch
./01_check_dependencies.sh -y
./02_check_python.sh -y  
./03_check_ml_env.sh --auto
source ~/ml_env/bin/activate  # or use the created alias
./04_check_ml_packages.sh -y
./05_check_final.sh

# Download a model
./install_model.sh -m "Qwen/Qwen3-30B-A3B-Instruct-2507"

# Daily usage
source ./launch_ml_env.sh  # Activates with optimizations
```

## Error Recovery
- Scripts can be re-run safely (idempotent design)
- Check scripts verify existing installations before reinstalling
- Failed CUDA installations fall back to CPU versions
- Environment reload functions handle PATH updates
#!/usr/bin/env python3
"""
Script: 04_install_packages.py
Purpose: Install ML packages based on detected Python environment
Usage: python 04_install_packages.py [-y]
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_info(msg):
    print(f"{Colors.GREEN}[INFO]{Colors.NC} {msg}")

def print_error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")

def print_warning(msg):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {msg}")

def print_command(msg):
    print(f"{Colors.BLUE}[RUN]{Colors.NC} {msg}")

def detect_environment():
    """Detect which ML environment is active"""
    virtual_env = os.environ.get('VIRTUAL_ENV', '')
    
    if not virtual_env:
        return None
    
    env_path = Path(virtual_env)
    env_name = env_path.name
    
    # Check if it's one of our expected environments (from 03_setup_env.sh)
    if 'vllm_env' in str(env_path):
        return 'vllm'
    elif 'glm_4.5_env' in str(env_path):
        return 'glm_4.5'
    elif 'vllm_gptoss_env' in str(env_path):
        return 'vllm_gptoss'
    elif 'sglang_env' in str(env_path):
        return 'sglang'
    elif 'transformers_env' in str(env_path):
        return 'transformers'
    
    # Also check by exact name match
    if env_name == 'vllm_env':
        return 'vllm'
    elif env_name == 'glm_4.5_env':
        return 'glm_4.5'
    elif env_name == 'vllm_gptoss_env':
        return 'vllm_gptoss'
    elif env_name == 'sglang_env':
        return 'sglang'
    elif env_name == 'transformers_env':
        return 'transformers'
    
    return None

def run_command(cmd, description=""):
    """Run a shell command and return success status"""
    if description:
        print_info(description)
    print_command(cmd)
    
    try:
        # Stream output directly to terminal so dependencies are visible
        result = subprocess.run(cmd, shell=True, check=True)
        print_info("✓ Installation successful")
        return True
    except subprocess.CalledProcessError as e:
        print_error("✗ Installation failed")
        return False

def ask_install(prompt, auto_yes=False):
    """Ask user for installation confirmation"""
    if auto_yes:
        return True
    
    response = input(f"{prompt} (y/n): ").strip().lower()
    return response in ['y', 'yes']


def check_nvcc():
    """Check if nvcc is available"""
    try:
        result = subprocess.run(['nvcc', '--version'], 
                              capture_output=True, text=True, check=True)
        print_info("✓ CUDA toolkit (nvcc) available")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print_warning("✗ CUDA toolkit (nvcc) not found")
        return False

def install_vllm_packages(auto_yes=False):
    """Install packages for regular vllm environment"""
    print_info("Installing packages for vllm_env...")
    
    if ask_install("Install vLLM?", auto_yes):
        cmd = "uv pip install vllm --torch-backend=auto"
        if not run_command(cmd, "Installing vLLM"):
            return False
    
    return True

def install_glm_4_5_packages(auto_yes=False):
    """Install packages for GLM 4.5 environment"""
    print_info("Installing packages for glm_4.5_env...")
    
    # Install main requirements
    requirements = [
        "transformers>=4.55.3",
        "pre-commit>=4.2.0",
        "accelerate>=1.10.0",
        "sglang>=0.5.1",
        "vllm>=0.10.1.1",
	"orjson",
	"sgl_kernel",
	"nvidia-ml-py",
	"torchao"
    ]
    
    if ask_install("Install GLM 4.5 environment packages?", auto_yes):
        # Properly quote requirements for shell - each requirement must be quoted
        quoted_reqs = ' '.join(f"'{req}'" for req in requirements)
        cmd = f"uv pip install {quoted_reqs}"
        if not run_command(cmd, "Installing GLM 4.5 requirements"):
            return False
    
    # Install vLLM with streaming tool call support
    if ask_install("Install vLLM nightly for streaming tool call support?", auto_yes):
        cmd = "uv pip install -U vllm --pre --extra-index-url https://wheels.vllm.ai/nightly"
        if not run_command(cmd, "Installing vLLM nightly for streaming tool call support"):
            print_warning("vLLM nightly installation failed, but continuing...")
    
    return True

def install_vllm_gptoss_packages(auto_yes=False):
    """Install packages for vllm GPT-OSS environment"""
    print_info("Installing packages for vllm_gptoss_env...")
    
    if ask_install("Install GPT-OSS enabled vLLM?", auto_yes):
        cmd = ("uv pip install --pre vllm==0.10.1+gptoss "
               "--extra-index-url https://wheels.vllm.ai/gpt-oss/ "
               "--extra-index-url https://download.pytorch.org/whl/nightly/cu128 "
               "--index-strategy unsafe-best-match")
        if not run_command(cmd, "Installing GPT-OSS enabled vLLM"):
            return False
    
    return True

def install_sglang_packages(auto_yes=False):
    """Install packages for sglang environment"""
    print_info("Installing packages for sglang_env...")
    
    if ask_install("Install SGLang?", auto_yes):
        cmd = "uv pip install sglang[all]"
        if not run_command(cmd, "Installing SGLang"):
            return False
    
    return True

def install_transformers_packages(auto_yes=False):
    """Install packages for transformers environment"""
    print_info("Installing packages for transformers_env...")
    
    # Main transformers packages
    if ask_install("Install transformers ecosystem packages?", auto_yes):
        cmd = "uv pip install -U transformers accelerate torch triton kernels"
        if not run_command(cmd, "Installing transformers ecosystem"):
            return False
    
    # Triton kernels from git
    if ask_install("Install Triton kernels for MXFP4 compatibility?", auto_yes):
        cmd = "uv pip install git+https://github.com/triton-lang/triton.git@main#subdirectory=python/triton_kernels"
        if not run_command(cmd, "Installing Triton kernels"):
            print_warning("Triton kernels installation failed, but continuing...")
    
    return True

def main():
    parser = argparse.ArgumentParser(description='Install ML packages based on environment')
    parser.add_argument('-y', '--yes', action='store_true', 
                       help='Auto-accept all prompts')
    args = parser.parse_args()
    
    # Check if in virtual environment
    if not os.environ.get('VIRTUAL_ENV'):
        print_error("No virtual environment activated!")
        print_info("Please activate one of the following environments:")
        print_command("source ~/vllm_env/bin/activate")
        print_command("source ~/vllm_gptoss_env/bin/activate")
        print_command("source ~/sglang_env/bin/activate")
        print_command("source ~/transformers_env/bin/activate")
        print_command("source ~/glm_4.5_env/bin/activate")
        return 1
    
    print_info(f"Virtual environment: {os.environ['VIRTUAL_ENV']}")
    print()
    
    # Detect environment type
    env_type = detect_environment()
    
    if not env_type:
        print_error("Current environment is not one of the expected ML environments!")
        print_info("Expected one of: vllm_env, vllm_gptoss_env, sglang_env, transformers_env, glm_4.5_env")
        print_info(f"Current environment: {os.environ.get('VIRTUAL_ENV', 'None')}")
        return 1
    
    print_info(f"Detected environment type: {env_type}")
    print()
    
    # Check for CUDA
    has_nvcc = check_nvcc()
    print()
    
    # Check if TORCH_CUDA_ARCH_LIST is set
    arch_list = os.environ.get('TORCH_CUDA_ARCH_LIST')
    if arch_list:
        print_info(f"Using TORCH_CUDA_ARCH_LIST={arch_list} from environment")
    else:
        print_info("TORCH_CUDA_ARCH_LIST not set - PyTorch will use default architectures")
    print()
    
    # Install packages based on environment
    success = False
    
    if env_type == 'vllm':
        success = install_vllm_packages(args.yes)
    elif env_type == 'glm_4.5':
        success = install_glm_4_5_packages(args.yes)
    elif env_type == 'vllm_gptoss':
        success = install_vllm_gptoss_packages(args.yes)
    elif env_type == 'sglang':
        success = install_sglang_packages(args.yes)
    elif env_type == 'transformers':
        success = install_transformers_packages(args.yes)
    
    # Summary
    print()
    print("=" * 50)
    if success:
        print_info("Installation complete!")
        print_info(f"Environment: {env_type}")
        
        # Verify GPU availability
        print()
        print_info("To verify GPU availability:")
        print_command("python -c 'import torch; print(f\"CUDA available: {torch.cuda.is_available()}\")'")
    else:
        print_error("Some installations failed. Please check the errors above.")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

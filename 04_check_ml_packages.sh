#!/usr/bin/env python3
"""
Script: 04.py
Purpose: Install ML packages based on detected Python environment
Usage: python 04.py [-y]
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
    
    # Check if it's one of our expected environments
    if 'transformers_env' in str(env_path):
        return 'transformers_env'
    elif 'vllm_env' in str(env_path):
        return 'vllm_env'
    elif 'sglang_env' in str(env_path):
        return 'sglang_env'
    
    # Also check by exact name match
    if env_name == 'transformers_env':
        return 'transformers_env'
    elif env_name == 'vllm_env':
        return 'vllm_env'
    elif env_name == 'sglang_env':
        return 'sglang_env'
    
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

def detect_gpu_arch():
    """Detect GPU architecture and set TORCH_CUDA_ARCH_LIST"""
    try:
        # Check if nvidia-smi is available
        result = subprocess.run(['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'],
                              capture_output=True, text=True, check=True)
        gpu_name = result.stdout.strip().split('\n')[0].upper()
        
        print_info(f"Detected GPU: {gpu_name}")
        
        arch_list = ""
        
        # Determine architecture based on GPU model (ordered by compute capability)
        
        # sm_70 (7.0) - Volta Architecture
        if "V100" in gpu_name:
            arch_list = "7.0"
            print_info(f"  → {gpu_name} (Volta) detected: sm_70")
        
        # sm_75 (7.5) - Turing Architecture
        elif "T4" in gpu_name or \
             ("RTX 5000" in gpu_name and "ADA" not in gpu_name) or \
             ("RTX 4000" in gpu_name and "ADA" not in gpu_name) or \
             ("RTX 6000" in gpu_name and "ADA" not in gpu_name):
            arch_list = "7.5"
            print_info(f"  → {gpu_name} (Turing) detected: sm_75")
        
        # sm_80 (8.0) - Ampere Architecture (Data Center)
        elif any(x in gpu_name for x in ["A100", "A30"]):
            arch_list = "8.0"
            print_info(f"  → {gpu_name} (Ampere) detected: sm_80")
        
        # sm_86 (8.6) - Ampere Architecture (Consumer & Professional)
        elif any(x in gpu_name for x in ["RTX 3090", "3090", "RTX 3080", "3080", "RTX 3070", "3070",
                                          "RTX A6000", "A6000", "RTX A5000", "A5000", "RTX A4500", "A4500",
                                          "RTX A4000", "A4000", "RTX A2000", "A2000", "A10", "A40"]):
            arch_list = "8.6"
            print_info(f"  → {gpu_name} (Ampere) detected: sm_86")
        
        # sm_89 (8.9) - Ada Lovelace Architecture
        elif any(x in gpu_name for x in ["RTX 4090", "4090", "RTX 4070 TI", "4070 TI", "L40S", "L40", "L4"]) or \
             ("RTX 6000" in gpu_name and "ADA" in gpu_name) or \
             ("RTX 5000" in gpu_name and "ADA" in gpu_name) or \
             ("RTX 4000" in gpu_name and "ADA" in gpu_name):
            arch_list = "8.9"
            print_info(f"  → {gpu_name} (Ada Lovelace) detected: sm_89")
        
        # sm_90 (9.0) - Hopper Architecture
        elif any(x in gpu_name for x in ["H100", "H200", "GH200"]):
            arch_list = "9.0"
            print_info(f"  → {gpu_name} (Hopper) detected: sm_90")
        
        # sm_100 (10.0) - Blackwell Architecture
        elif "B200" in gpu_name:
            arch_list = "10.0"
            print_info(f"  → {gpu_name} (Blackwell) detected: sm_100")
        
        # sm_120 (12.0) - Blackwell Architecture (RTX 50 series)
        elif any(x in gpu_name for x in ["RTX 5090", "5090"]):
            arch_list = "12.0"
            print_info(f"  → {gpu_name} (Blackwell) detected: sm_120")
        else:
            print_warning("  → Unknown GPU model, will use default PyTorch CUDA architectures")
            return None
        
        # Set environment variable
        os.environ['TORCH_CUDA_ARCH_LIST'] = arch_list
        print_info(f"  → Set TORCH_CUDA_ARCH_LIST={arch_list}")
        return arch_list
        
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

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

def install_vllm_packages(auto_yes=False):
    """Install packages for vllm environment"""
    print_info("Installing packages for vllm_env...")
    
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
    print_info("SGLang environment detected - no specific packages to install at this time")
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
        print_command("source ~/transformers_env/bin/activate")
        print_command("source ~/vllm_env/bin/activate")
        print_command("source ~/sglang_env/bin/activate")
        return 1
    
    print_info(f"Virtual environment: {os.environ['VIRTUAL_ENV']}")
    print()
    
    # Detect environment type
    env_type = detect_environment()
    
    if not env_type:
        print_error("Current environment is not one of the expected ML environments!")
        print_info("Expected one of: transformers_env, vllm_env, sglang_env")
        print_info(f"Current environment: {os.environ.get('VIRTUAL_ENV', 'None')}")
        return 1
    
    print_info(f"Detected environment type: {env_type}")
    print()
    
    # Check for CUDA and set architecture if available
    has_nvcc = check_nvcc()
    if has_nvcc:
        detect_gpu_arch()
    print()
    
    # Install packages based on environment
    success = False
    
    if env_type == 'transformers_env':
        success = install_transformers_packages(args.yes)
    elif env_type == 'vllm_env':
        success = install_vllm_packages(args.yes)
    elif env_type == 'sglang_env':
        success = install_sglang_packages(args.yes)
    
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
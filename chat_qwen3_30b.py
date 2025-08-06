#!/usr/bin/env python3
"""
Simple chat interface for Qwen3-30B-A3B-Instruct-2507 using SGLang
Built for beginners who want to chat with their local model easily!

Usage:
    python chat_qwen3_30b.py --gpu    # Run on GPU (default if available)
    python chat_qwen3_30b.py --cpu    # Force CPU mode
    python chat_qwen3_30b.py --help   # Show help

Requirements:
    - SGLang installed (should be in your ml_env)
    - Model downloaded to /data/ml/models/huggingface/
"""

import argparse
import os
import sys
import json
import subprocess
import time
import requests
import threading
from pathlib import Path

# Colors for pretty output
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_info(msg):
    print(f"{Colors.GREEN}[INFO]{Colors.END} {msg}")

def print_warning(msg):
    print(f"{Colors.YELLOW}[WARNING]{Colors.END} {msg}")

def print_error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.END} {msg}")

def print_user(msg):
    print(f"{Colors.BLUE}[YOU]{Colors.END} {msg}")

def print_assistant(msg):
    print(f"{Colors.PURPLE}[QWEN3]{Colors.END} {msg}")

def check_cuda_available():
    """Check if CUDA is available for GPU inference"""
    try:
        import torch
        return torch.cuda.is_available()
    except ImportError:
        print_warning("PyTorch not found, cannot check CUDA availability")
        return False

def check_sglang_installed():
    """Check if SGLang is properly installed"""
    try:
        import sglang
        return True
    except ImportError:
        print_error("SGLang not found! Make sure you're in the ml_env virtual environment.")
        print_info("Activate with: source ~/ml_env/bin/activate")
        return False

def find_model_path():
    """Find the Qwen3-30B-A3B-Instruct-2507 model path"""
    # Standard HuggingFace cache location
    model_paths = [
        "/data/ml/models/huggingface/models--Qwen--Qwen3-30B-A3B-Instruct-2507",
        os.path.expanduser("~/.cache/huggingface/hub/models--Qwen--Qwen3-30B-A3B-Instruct-2507"),
        "/data/ml/models/Qwen/Qwen3-30B-A3B-Instruct-2507"
    ]
    
    for path in model_paths:
        if os.path.exists(path):
            # Find the actual model files in snapshots directory
            snapshots_dir = os.path.join(path, "snapshots")
            if os.path.exists(snapshots_dir):
                # Get the latest snapshot
                snapshots = [d for d in os.listdir(snapshots_dir) if os.path.isdir(os.path.join(snapshots_dir, d))]
                if snapshots:
                    latest_snapshot = sorted(snapshots)[-1]  # Get the latest
                    model_path = os.path.join(snapshots_dir, latest_snapshot)
                    if os.path.exists(os.path.join(model_path, "config.json")):
                        return model_path
    
    return None

def get_system_info():
    """Get system information for optimal settings"""
    info = {}
    
    # Get CPU info
    try:
        import psutil
        info['cpu_count'] = psutil.cpu_count()
        info['memory_gb'] = round(psutil.virtual_memory().total / (1024**3))
    except ImportError:
        info['cpu_count'] = os.cpu_count() or 4
        info['memory_gb'] = 16  # reasonable default
    
    # Get GPU info if available
    info['has_cuda'] = check_cuda_available()
    if info['has_cuda']:
        try:
            import torch
            info['gpu_count'] = torch.cuda.device_count()
            info['gpu_name'] = torch.cuda.get_device_name(0) if info['gpu_count'] > 0 else "Unknown"
            info['gpu_memory_gb'] = round(torch.cuda.get_device_properties(0).total_memory / (1024**3))
        except:
            info['gpu_count'] = 0
            info['gpu_name'] = "Unknown"
            info['gpu_memory_gb'] = 0
    else:
        info['gpu_count'] = 0
        info['gpu_name'] = "None"
        info['gpu_memory_gb'] = 0
    
    return info

def start_sglang_server(model_path, use_gpu=True, port=30002):
    """Start SGLang server with the model"""
    print_info("Starting SGLang server...")
    
    # Build command
    cmd = [
        "python", "-m", "sglang.launch_server",
        "--model-path", model_path,
        "--port", str(port),
        "--host", "127.0.0.1"
    ]
    
    if use_gpu:
        cmd.extend(["--device", "cuda"])
        # Optimize for 30B model - more conservative memory usage
        cmd.extend(["--mem-fraction-static", "0.85"])
        # Add tensor parallel if needed for large models
        # cmd.extend(["--tp-size", "2"])  # Uncomment if you have multiple GPUs
    else:
        cmd.extend(["--device", "cpu"])
    
    # Set environment variables
    env = os.environ.copy()
    env["CUDA_VISIBLE_DEVICES"] = "0" if use_gpu else ""
    
    print_info(f"Running: {' '.join(cmd)}")
    print_info("This may take a few minutes to load the 30B model...")
    
    # Start server in background
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            text=True
        )
        return process, port
    except Exception as e:
        print_error(f"Failed to start SGLang server: {e}")
        return None, None

def wait_for_server(port, timeout=300):
    """Wait for SGLang server to be ready"""
    print_info("Waiting for server to be ready...")
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"http://127.0.0.1:{port}/health", timeout=5)
            if response.status_code == 200:
                print_info("✓ Server is ready!")
                return True
        except requests.RequestException:
            pass
        
        print(".", end="", flush=True)
        time.sleep(2)
    
    print()
    print_error("Server failed to start within timeout")
    return False

def chat_with_model(port):
    """Simple chat interface"""
    print_info("🎉 Ready to chat! Type 'quit' or 'exit' to stop.")
    print_info("💡 Tip: Qwen3-30B is great for reasoning, coding, and complex tasks!")
    print_info("💡 Try asking for code, math problems, or detailed explanations.")
    print("-" * 60)
    
    conversation_history = []
    
    while True:
        try:
            # Get user input
            user_input = input(f"\n{Colors.BLUE}[YOU]{Colors.END} ").strip()
            
            if user_input.lower() in ['quit', 'exit', 'bye']:
                print_info("Goodbye! 👋")
                break
            
            if not user_input:
                continue
            
            # Add to conversation history
            conversation_history.append({"role": "user", "content": user_input})
            
            # Prepare request with Qwen-specific settings
            payload = {
                "model": "default",
                "messages": conversation_history,
                "max_tokens": 1024,  # Qwen can handle longer responses well
                "temperature": 0.7,
                "top_p": 0.8,
                "stream": False
            }
            
            print_assistant("Thinking...")
            
            # Send request to SGLang
            try:
                response = requests.post(
                    f"http://127.0.0.1:{port}/v1/chat/completions",
                    json=payload,
                    timeout=90  # Longer timeout for 30B model
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if 'choices' in result and len(result['choices']) > 0:
                        assistant_response = result['choices'][0]['message']['content']
                        print_assistant(assistant_response)
                        
                        # Add to conversation history
                        conversation_history.append({
                            "role": "assistant", 
                            "content": assistant_response
                        })
                        
                        # Keep conversation history manageable (last 10 exchanges)
                        if len(conversation_history) > 20:
                            conversation_history = conversation_history[-20:]
                    else:
                        print_error("No response generated")
                else:
                    print_error(f"Server error: {response.status_code}")
                    print_error(f"Response: {response.text}")
                    
            except requests.exceptions.Timeout:
                print_error("Request timed out - the model might be overloaded")
            except requests.exceptions.RequestException as e:
                print_error(f"Request failed: {e}")
                
        except KeyboardInterrupt:
            print_info("\nGoodbye! 👋")
            break
        except Exception as e:
            print_error(f"Unexpected error: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="Chat with Qwen3-30B-A3B-Instruct-2507 using SGLang",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python chat_qwen3_30b.py              # Auto-detect GPU/CPU
    python chat_qwen3_30b.py --gpu        # Force GPU mode
    python chat_qwen3_30b.py --cpu        # Force CPU mode
    python chat_qwen3_30b.py --port 8080  # Use custom port

About Qwen3-30B-A3B-Instruct-2507:
    - 30B parameter model optimized for instruction following
    - Excellent at reasoning, coding, and complex tasks
    - Supports multiple languages
    - Great balance of capability and efficiency
        """
    )
    parser.add_argument("--gpu", action="store_true", help="Force GPU mode")
    parser.add_argument("--cpu", action="store_true", help="Force CPU mode")
    parser.add_argument("--port", type=int, default=30002, help="Server port (default: 30002)")
    
    args = parser.parse_args()
    
    # Check dependencies
    if not check_sglang_installed():
        return 1
    
    # Find model
    model_path = find_model_path()
    if not model_path:
        print_error("Qwen3-30B-A3B-Instruct-2507 model not found!")
        print_info("Expected locations:")
        print_info("  - /data/ml/models/huggingface/models--Qwen--Qwen3-30B-A3B-Instruct-2507")
        print_info("  - ~/.cache/huggingface/hub/models--Qwen--Qwen3-30B-A3B-Instruct-2507")
        print_info("")
        print_info("Download with: huggingface-cli download Qwen/Qwen3-30B-A3B-Instruct-2507")
        return 1
    
    print_info(f"Found model at: {model_path}")
    
    # Get system info
    system_info = get_system_info()
    print_info(f"System: {system_info['cpu_count']} CPUs, {system_info['memory_gb']}GB RAM")
    
    # Determine GPU/CPU usage
    use_gpu = False
    if args.cpu:
        use_gpu = False
        print_info("🖥️  Using CPU mode (forced)")
    elif args.gpu:
        if system_info['has_cuda']:
            use_gpu = True
            print_info(f"🚀 Using GPU mode: {system_info['gpu_name']} ({system_info['gpu_memory_gb']}GB)")
        else:
            print_warning("GPU requested but CUDA not available, falling back to CPU")
            use_gpu = False
    else:
        # Auto-detect - 30B needs ~40GB+ VRAM for comfortable inference
        if system_info['has_cuda'] and system_info['gpu_memory_gb'] >= 40:
            use_gpu = True
            print_info(f"🚀 Auto-selected GPU mode: {system_info['gpu_name']} ({system_info['gpu_memory_gb']}GB)")
        elif system_info['has_cuda'] and system_info['gpu_memory_gb'] >= 24:
            use_gpu = True
            print_warning(f"GPU has {system_info['gpu_memory_gb']}GB VRAM - might be tight for 30B model")
            print_info("💡 Will use aggressive memory optimization")
        else:
            use_gpu = False
            if system_info['has_cuda']:
                print_warning(f"GPU has only {system_info['gpu_memory_gb']}GB VRAM, using CPU mode")
                print_info("💡 30B models typically need 40GB+ VRAM for comfortable GPU inference")
            else:
                print_info("🖥️  Using CPU mode (no CUDA detected)")
    
    # Warning for CPU mode with large model
    if not use_gpu:
        print_warning("⚠️  Running 30B model on CPU will be quite slow!")
        print_info("💡 Each response may take 1-3 minutes")
        print_info("💡 Consider using a smaller model for CPU inference")
        
        response = input("Continue? [Y/n]: ").strip().lower()
        if response in ['n', 'no']:
            print_info("Cancelled. Consider running with --gpu if you have 40GB+ VRAM.")
            return 0
    
    # Start server
    server_process, port = start_sglang_server(model_path, use_gpu, args.port)
    if not server_process:
        return 1
    
    try:
        # Wait for server to be ready
        if not wait_for_server(port):
            return 1
        
        # Start chatting
        chat_with_model(port)
        
    finally:
        # Clean up
        print_info("Shutting down server...")
        if server_process:
            server_process.terminate()
            server_process.wait(timeout=10)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
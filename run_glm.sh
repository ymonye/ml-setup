#!/usr/bin/env bash

# GLM 4.5 Inference Server Launcher

echo ""
echo "🚀 GLM 4.5 Inference Server Launcher"

# Function to select inference engine
select_inference_engine() {
    echo ""
    echo "============================================================"
    echo "Inference Engine Selection"
    echo "============================================================"
    echo ""
    echo "Available inference engines:"
    echo ""
    echo "1) vLLM"
    echo "   High-performance inference engine"
    echo ""
    echo "2) SGLang"
    echo "   Structured generation with speculative decoding"
    echo ""
    
    while true; do
        read -p "Select inference engine (1-2): " choice
        
        case $choice in
            1)
                INFERENCE_ENGINE="vllm"
                ENGINE_DESC="vLLM"
                break
                ;;
            2)
                INFERENCE_ENGINE="sglang"
                ENGINE_DESC="SGLang"
                break
                ;;
            *)
                echo "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done
    
    echo ""
    echo "✓ Selected: $ENGINE_DESC"
}

# Function to select GLM model
select_glm_model() {
    echo ""
    echo "============================================================"
    echo "GLM 4.5 Model Selection"
    echo "============================================================"
    echo ""
    echo "Available GLM 4.5 models:"
    echo ""
    echo "1) GLM 4.5 (Base precision)"
    echo "   Repository: zai-org/GLM-4.5"
    echo ""
    echo "2) GLM 4.5 FP8 (8-bit quantized)"
    echo "   Repository: zai-org/GLM-4.5-FP8"
    echo ""
    echo "3) GLM 4.5 Air (Lightweight version)"
    echo "   Repository: zai-org/GLM-4.5-Air"
    echo ""
    echo "4) GLM 4.5 Air FP8 (Lightweight 8-bit)"
    echo "   Repository: zai-org/GLM-4.5-Air-FP8"
    echo ""
    echo "5) GLM 4.5 Base (Foundation model)"
    echo "   Repository: zai-org/GLM-4.5-Base"
    echo ""
    
    while true; do
        read -p "Select model (1-5): " choice
        
        case $choice in
            1)
                MODEL_REPO="zai-org/GLM-4.5"
                MODEL_NAME="glm-4.5"
                MODEL_DESC="GLM 4.5 (Base precision)"
                break
                ;;
            2)
                MODEL_REPO="zai-org/GLM-4.5-FP8"
                MODEL_NAME="glm-4.5-fp8"
                MODEL_DESC="GLM 4.5 FP8 (8-bit quantized)"
                break
                ;;
            3)
                MODEL_REPO="zai-org/GLM-4.5-Air"
                MODEL_NAME="glm-4.5-air"
                MODEL_DESC="GLM 4.5 Air (Lightweight version)"
                break
                ;;
            4)
                MODEL_REPO="zai-org/GLM-4.5-Air-FP8"
                MODEL_NAME="glm-4.5-air-fp8"
                MODEL_DESC="GLM 4.5 Air FP8 (Lightweight 8-bit)"
                break
                ;;
            5)
                MODEL_REPO="zai-org/GLM-4.5-Base"
                MODEL_NAME="glm-4.5-base"
                MODEL_DESC="GLM 4.5 Base (Foundation model)"
                break
                ;;
            *)
                echo "Invalid choice. Please select a number from 1-5."
                ;;
        esac
    done
    
    echo ""
    echo "✓ Selected: $MODEL_DESC"
}

# Function to get tensor parallel size
get_tensor_parallel_size() {
    echo ""
    echo "============================================================"
    echo "Tensor Parallel Configuration"
    echo "============================================================"
    echo ""
    echo "Tensor parallel size determines how many GPUs to use:"
    echo "  1 = Single GPU"
    echo "  2 = 2 GPUs"
    echo "  4 = 4 GPUs"
    echo "  8 = 8 GPUs (default)"
    echo ""
    
    read -p "Enter tensor parallel size (1/2/4/8) [default: 8]: " size
    
    if [ -z "$size" ]; then
        TENSOR_PARALLEL_SIZE=8
    elif [[ "$size" =~ ^(1|2|4|8)$ ]]; then
        TENSOR_PARALLEL_SIZE=$size
    else
        echo "Invalid choice. Using default: 8"
        TENSOR_PARALLEL_SIZE=8
    fi
}

# Function to run vLLM server
run_vllm_server() {
    echo ""
    echo "============================================================"
    echo "Starting vLLM Server"
    echo "============================================================"
    echo "Model: $MODEL_REPO"
    echo "Served as: $MODEL_NAME"
    echo "Tensor parallel size: $TENSOR_PARALLEL_SIZE"
    echo ""
    echo "Command: vllm serve $MODEL_REPO --tensor-parallel-size $TENSOR_PARALLEL_SIZE --tool-call-parser glm45 --reasoning-parser glm45 --enable-auto-tool-choice --served-model-name $MODEL_NAME"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo "============================================================"
    echo ""
    
    vllm serve "$MODEL_REPO" \
        --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
        --tool-call-parser glm45 \
        --reasoning-parser glm45 \
        --enable-auto-tool-choice \
        --served-model-name "$MODEL_NAME" \
	--api-key YOUR_API_KEY
}

# Function to run SGLang server
run_sglang_server() {
    echo ""
    echo "============================================================"
    echo "Starting SGLang Server"
    echo "============================================================"
    echo "Model: $MODEL_REPO"
    echo "Served as: $MODEL_NAME"
    echo "Tensor parallel size: $TENSOR_PARALLEL_SIZE"
    echo ""
    echo "Command: python3 -m sglang.launch_server --model-path $MODEL_REPO --tp-size $TENSOR_PARALLEL_SIZE --tool-call-parser glm45 --reasoning-parser glm45 --speculative-algorithm EAGLE --speculative-num-steps 3 --speculative-eagle-topk 1 --speculative-num-draft-tokens 4 --mem-fraction-static 0.7 --disable-shared-experts-fusion --served-model-name $MODEL_NAME --host 0.0.0.0 --port 8000"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo "============================================================"
    echo ""
    
    python3 -m sglang.launch_server \
        --model-path "$MODEL_REPO" \
        --tp-size "$TENSOR_PARALLEL_SIZE" \
        --tool-call-parser glm45 \
        --reasoning-parser glm45 \
        --speculative-algorithm EAGLE \
        --speculative-num-steps 3 \
        --speculative-eagle-topk 1 \
        --speculative-num-draft-tokens 4 \
        --mem-fraction-static 0.7 \
        --disable-shared-experts-fusion \
        --served-model-name "$MODEL_NAME" \
        --host 0.0.0.0 \
        --port 8000 \
	--api-key YOUR_API_KEY
}

# Main execution
trap 'echo -e "\n\nServer stopped by user."; exit 0' INT

select_inference_engine
select_glm_model
get_tensor_parallel_size

# Run the selected inference engine
if [ "$INFERENCE_ENGINE" = "vllm" ]; then
    run_vllm_server
else
    run_sglang_server
fi

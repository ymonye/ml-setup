#!/bin/bash

# Script: 05_install_packages.sh
# Purpose: Provide environment placeholders without installing packages.
# Usage: ./05_install_packages.sh [--env ENV_NAME]

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_command() { echo -e "${BLUE}[RUN]${NC} $1"; }

ACTION_TAKEN=false

ENV_TYPES=(
  "deepseek-v3-lmdeploy"
  "deepseek-v3-sglang"
  "deepseek-v3-vllm"
  "glm-4.5-sglang"
  "glm-4.5-vllm"
  "gpt-oss-transformers"
  "gpt-oss-vllm"
  "kimi-k2-sglang"
  "kimi-k2-vllm"
  "qwen3-sglang"
  "qwen3-transformers"
  "qwen3-vllm"
)

declare -A ENV_DESCRIPTIONS=(
  ["deepseek-v3-lmdeploy"]="DeepSeek-V3/V3.1/R1 (LMDeploy)"
  ["deepseek-v3-sglang"]="DeepSeek-V3/V3.1/R1 (SGLang)"
  ["deepseek-v3-vllm"]="DeepSeek-V3/V3.1/R1 (vLLM)"
  ["glm-4.5-sglang"]="GLM 4.5 (SGLang)"
  ["glm-4.5-vllm"]="GLM 4.5 (vLLM)"
  ["gpt-oss-transformers"]="gpt-oss (Transformers)"
  ["gpt-oss-vllm"]="gpt-oss (vLLM)"
  ["kimi-k2-sglang"]="Kimi K2 (SGLang)"
  ["kimi-k2-vllm"]="Kimi K2 (vLLM)"
  ["qwen3-sglang"]="Qwen3 (SGLang)"
  ["qwen3-transformers"]="Qwen3 (Transformers)"
  ["qwen3-vllm"]="Qwen3 (vLLM)"
)

resolve_env_type() {
    case "$1" in
        1|deepseek_v3_lmdeploy|deepseek-v3-lmdeploy)
            echo "deepseek-v3-lmdeploy"
            ;;
        2|deepseek_v3_sglang|deepseek-v3-sglang)
            echo "deepseek-v3-sglang"
            ;;
        3|deepseek_v3_vllm|deepseek-v3-vllm)
            echo "deepseek-v3-vllm"
            ;;
        4|glm_4.5|glm45_sglang|glm-4.5-sglang)
            echo "glm-4.5-sglang"
            ;;
        5|glm_4.5_vllm|glm45_vllm|glm-4.5-vllm)
            echo "glm-4.5-vllm"
            ;;
        6|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        7|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        8|kimi_k2_sglang|kimi-k2-sglang)
            echo "kimi-k2-sglang"
            ;;
        9|kimi_k2_vllm|kimi-k2-vllm)
            echo "kimi-k2-vllm"
            ;;
        10|qwen3_sglang|qwen3-sglang)
            echo "qwen3-sglang"
            ;;
        11|qwen3_transformers|qwen3-transformers)
            echo "qwen3-transformers"
            ;;
        12|qwen3_vllm|qwen3-vllm)
            echo "qwen3-vllm"
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                return 1
            fi
            return 1
            ;;
    esac
}

print_env_options() {
    print_info "Available environments from 04_setup_env.sh:"
    local index=1
    for key in "${ENV_TYPES[@]}"; do
        printf "  %2d) %s (%s)\n" "$index" "${ENV_DESCRIPTIONS[$key]}" "$key"
        index=$((index + 1))
    done
}

normalize_env_name() {
    local raw="$1"
    raw="${raw%/}"
    raw=$(basename "$raw")
    raw="${raw%_env}"
    echo "$raw"
}

detect_environment() {
    local virtual_env="${VIRTUAL_ENV:-}"
    if [ -z "$virtual_env" ]; then
        return 1
    fi

    local base
    base=$(normalize_env_name "$virtual_env")

    if resolved=$(resolve_env_type "$base"); then
        echo "$resolved"
        return 0
    fi

    for key in "${ENV_TYPES[@]}"; do
        if [[ "$virtual_env" == *"/${key}_env"* ]] || [[ "$virtual_env" == *"/$key"* ]]; then
            echo "$key"
            return 0
        fi
    done

    return 1
}

handle_environment() {
    local env="$1"
    local desc="${ENV_DESCRIPTIONS[$env]}"

    if [ -z "$desc" ]; then
        desc="$env"
    fi

    print_info "Environment: $desc"
}

run_command() {
    local cmd=("$@")
    print_command "$(printf '%q ' "${cmd[@]}")"
    if "${cmd[@]}"; then
        return 0
    fi
    return 1
}

run_uv_install() {
    if ! command -v uv >/dev/null 2>&1; then
        print_error "uv is not available on PATH."
        return 1
    fi

    local cmd=(uv pip install)
    cmd+=("$@")

    if run_command "${cmd[@]}"; then
        print_info "Packages installed successfully."
        return 0
    fi

    print_error "Package installation failed."
    return 1
}

install_glm_sglang() {
    print_info "Installing packages for GLM 4.5 (SGLang)..."
    local packages=(
        "transformers>=4.56.1"
        "pre-commit>=4.2.0"
        "accelerate>=1.10.0"
        "sglang>=0.5.2"
        "pybase64"
        "pydantic"
        "orjson"
        "uvicorn"
        "uvloop"
        "fastapi"
        "zmq"
        "Pillow"
        "openai"
        "partial_json_parser"
        "sentencepiece"
        "sgl_kernel"
        "dill"
        "compressed_tensors"
        "einops"
        "msgspec"
        "python-multipart"
    )

    run_uv_install "${packages[@]}"
}

install_glm_vllm() {
    print_info "Installing packages for GLM 4.5 (vLLM)..."
    local packages=(
        "transformers>=4.56.1"
        "pre-commit>=4.2.0"
        "accelerate>=1.10.0"
        "vllm>=0.10.2"
    )

    run_uv_install "${packages[@]}"
}

install_deepseek_lmdeploy() {
    print_info "Installing LMDeploy for DeepSeek..."
    local target_dir="${LMDEPLOY_DIR:-$HOME/lmdeploy}"

    if [ -d "$target_dir/.git" ]; then
        print_info "Updating existing repository at $target_dir"
        run_command git -C "$target_dir" fetch origin || return 1
        run_command git -C "$target_dir" checkout support-dsv3 || return 1
        run_command git -C "$target_dir" pull --ff-only || return 1
    else
        run_command git clone -b support-dsv3 https://github.com/InternLM/lmdeploy.git "$target_dir" || return 1
    fi

    run_uv_install -e "$target_dir"
}

install_deepseek_sglang() {
    print_info "Installing SGLang for DeepSeek..."
    run_uv_install "sglang[all]>=0.5.3rc0"
}

install_deepseek_vllm() {
    print_info "Installing vLLM for DeepSeek..."
    run_uv_install vllm
}

install_gptoss_transformers() {
    print_info "Installing Transformers stack for gpt-oss..."
    run_uv_install -U transformers accelerate torch triton==3.4 kernels
}

install_gptoss_vllm() {
    print_info "Installing vLLM GPT-OSS build..."
    run_uv_install --pre vllm==0.10.1+gptoss \
        --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
        --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
        --index-strategy unsafe-best-match
}

install_kimi_sglang() {
    print_info "Installing SGLang for Kimi K2..."
    run_uv_install sglang
}

install_kimi_vllm() {
    print_info "Installing vLLM for Kimi K2..."
    run_uv_install "vllm>=0.10.0rc1"
}

install_qwen3_sglang() {
    print_info "Installing SGLang for Qwen3..."
    run_uv_install "sglang[all]>=0.4.6.post1"
}

install_qwen3_transformers() {
    print_info "Installing Transformers stack for Qwen3..."
    run_uv_install "transformers>=4.51.0" "torch>=2.6"
}

install_qwen3_vllm() {
    print_info "Installing vLLM for Qwen3..."
    run_uv_install "vllm>=0.8.5"
}

perform_environment_action() {
    ACTION_TAKEN=false

    case "$1" in
        deepseek-v3-lmdeploy)
            install_deepseek_lmdeploy || return 1
            ACTION_TAKEN=true
            ;;
        deepseek-v3-sglang)
            install_deepseek_sglang || return 1
            ACTION_TAKEN=true
            ;;
        deepseek-v3-vllm)
            install_deepseek_vllm || return 1
            ACTION_TAKEN=true
            ;;
        glm-4.5-sglang)
            install_glm_sglang || return 1
            ACTION_TAKEN=true
            ;;
        glm-4.5-vllm)
            install_glm_vllm || return 1
            ACTION_TAKEN=true
            ;;
        gpt-oss-transformers)
            install_gptoss_transformers || return 1
            ACTION_TAKEN=true
            ;;
        gpt-oss-vllm)
            install_gptoss_vllm || return 1
            ACTION_TAKEN=true
            ;;
        kimi-k2-sglang)
            install_kimi_sglang || return 1
            ACTION_TAKEN=true
            ;;
        kimi-k2-vllm)
            install_kimi_vllm || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-sglang)
            install_qwen3_sglang || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-transformers)
            install_qwen3_transformers || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-vllm)
            install_qwen3_vllm || return 1
            ACTION_TAKEN=true
            ;;
        *)
            print_info "No automated package actions configured for this environment."
            ;;
    esac

    return 0
}

main() {
    local override=""
    local show_help=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                if [[ $# -lt 2 ]]; then
                    print_error "Missing value for --env"
                    return 1
                fi
                override="$2"
                shift 2
                ;;
            -y|--yes|--auto)
                print_warning "Flag '$1' has no effect; no installations occur in this script."
                shift
                ;;
            -h|--help)
                show_help=true
                shift
                ;;
            *)
                print_warning "Ignoring unknown argument: $1"
                shift
                ;;
        esac
    done

    if [ "$show_help" = true ]; then
        echo "Usage: ./05_install_packages.sh [--env ENV_NAME]"
        echo
        print_env_options
        return 0
    fi

    local env_type=""

    if [ -n "$override" ]; then
        if env_type=$(resolve_env_type "$override"); then
            print_info "Environment override provided: $env_type"
        else
            print_warning "Environment override '$override' is not managed by this script."
            print_info "Nothing to configure in 05_install_packages.sh."
            return 0
        fi
    else
        if ! env_type=$(detect_environment); then
            if [ -n "${VIRTUAL_ENV:-}" ]; then
                print_warning "Active virtual environment '$VIRTUAL_ENV' is not managed by this script."
            else
                print_info "No active virtual environment detected."
            fi
            print_info "Nothing to configure in 05_install_packages.sh."
            return 0
        fi
    fi

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        print_info "Virtual environment: $VIRTUAL_ENV"
    fi

    echo
    handle_environment "$env_type"
    echo

    if ! perform_environment_action "$env_type"; then
        print_error "Environment handling failed."
        return 1
    fi

    if [ "$ACTION_TAKEN" = false ]; then
        print_info "Nothing to install. Customize this script if you need per-environment actions."
    fi
}

main "$@"
exit $?

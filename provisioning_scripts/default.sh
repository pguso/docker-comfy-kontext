#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

APT_PACKAGES=(
    # Add APT packages here if needed
)

PIP_PACKAGES=(
    # Add PIP packages here if needed
)

NODES=(
    # Add custom nodes here if needed
)

WORKFLOWS=(
    "https://raw.githubusercontent.com/pguso/docker-comfy-kontext/refs/heads/main/flux_1_kontext_dev_basic.json"
)

CHECKPOINT_MODELS=(
    "https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors"
)

TEXT_ENCODERS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors"
)

### CORE FUNCTIONS BELOW ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages
    provisioning_get_nodes
    provisioning_get_files "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODERS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/output" "${WORKFLOWS[@]}"
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                echo "Updating node: $repo"
                ( cd "$path" && git pull )
                [[ -f $requirements ]] && pip install --no-cache-dir -r "$requirements"
            fi
        else
            echo "Cloning node: $repo"
            git clone "$repo" "$path" --recursive
            [[ -f $requirements ]] && pip install --no-cache-dir -r "$requirements"
        fi
    done
}

function provisioning_get_files() {
    local target_dir="$1"
    shift
    local urls=("$@")

    mkdir -p "$target_dir"
    for url in "${urls[@]}"; do
        echo "Downloading: $url"
        provisioning_download "$url" "$target_dir"
    done
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local token_header=""

    if [[ $url == *"huggingface.co"* && -n "$HF_TOKEN" ]]; then
        token_header="Authorization: Bearer $HF_TOKEN"
    fi

    wget -qnc --content-disposition --show-progress -e dotbytes=4M \
        ${token_header:+--header="$token_header"} \
        -P "$dir" "$url"
}

function provisioning_print_header() {
    echo ""
    echo "##############################################"
    echo "#         Provisioning ComfyUI               #"
    echo "#     with Flux 1 Kontext Workflow           #"
    echo "#    This may take a few minutes...          #"
    echo "##############################################"
    echo ""
}

function provisioning_print_end() {
    echo ""
    echo "✅ Provisioning complete!"
    echo "🚀 ComfyUI with Flux 1 Kontext is ready."
    echo ""
}

# Run provisioning unless disabled
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi

#!/usr/bin/env bash
set -Eeuo pipefail

echo ""
echo "============================================================"
echo "       NVIDIA CUDA RUNPOD CONTAINER STARTUP"
echo "============================================================"

# ============================================================
# 1. GPU INFORMATION
# ============================================================

echo ""
echo "[1/7] NVIDIA GPU INFORMATION"
echo "------------------------------------------------------------"

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
else
    echo "[WARNING] nvidia-smi unavailable"
fi

# ============================================================
# 2. CUDA INFORMATION
# ============================================================

echo ""
echo "[2/7] CUDA INFORMATION"
echo "------------------------------------------------------------"

if command -v nvcc >/dev/null 2>&1; then
    nvcc --version
else
    echo "[INFO] nvcc unavailable (runtime image)"
fi

if [ -f /usr/local/cuda/version.json ]; then
    cat /usr/local/cuda/version.json
elif [ -f /usr/local/cuda/version.txt ]; then
    cat /usr/local/cuda/version.txt
fi

echo ""
echo "--- CUDA Libraries ---"

for lib in libcudart.so libcublas.so libcudnn.so; do
    if ldconfig -p 2>/dev/null | grep -q "$lib"; then
        echo "[OK] $lib available"
    else
        echo "[INFO] $lib not found in ldconfig cache"
    fi
done

# ============================================================
# 3. PYTHON INFORMATION
# ============================================================

echo ""
echo "[3/7] PYTHON INFORMATION"
echo "------------------------------------------------------------"

python --version
pip --version
uv --version || true

# ============================================================
# 4. PYTHON PACKAGE DIAGNOSTICS
# ============================================================

echo ""
echo "[4/7] PYTHON PACKAGE AVAILABILITY"
echo "------------------------------------------------------------"

python - <<'PY'
import importlib.util
import importlib.metadata as metadata

packages = {
    "torch": "PyTorch",
    "torchvision": "TorchVision",
    "torchaudio": "TorchAudio",
    "transformers": "Transformers",
    "tokenizers": "Tokenizers",
    "accelerate": "Accelerate",
    "triton": "Triton",
    "numpy": "NumPy",
    "scipy": "SciPy",
    "pandas": "Pandas",
    "sklearn": "Scikit-learn",
    "cv2": "OpenCV",
    "PIL": "Pillow",
    "jupyterlab": "JupyterLab",
    "notebook": "Notebook",
    "ipywidgets": "IPyWidgets",
    "huggingface_hub": "HuggingFace Hub",
    "hf_xet": "HF Xet",
    "requests": "Requests",
    "httpx": "HTTPX",
    "aiohttp": "AIOHTTP",
    "fastapi": "FastAPI",
    "uvicorn": "Uvicorn",
    "yaml": "PyYAML",
    "orjson": "Orjson",
    "psutil": "PSUtil",
    "safetensors": "SafeTensors",
    "cryptography": "Cryptography",
}

distribution_names = {
    "cv2": "opencv-python",
    "sklearn": "scikit-learn",
    "PIL": "Pillow",
    "yaml": "PyYAML",
    "jupyterlab": "jupyterlab",
    "huggingface_hub": "huggingface-hub",
    "hf_xet": "hf-xet",
}

for module, name in packages.items():
    try:
        if importlib.util.find_spec(module) is None:
            print(f"[MISSING] {name}")
            continue

        package = distribution_names.get(module, module)

        try:
            version = metadata.version(package)
        except metadata.PackageNotFoundError:
            version = "installed"

        print(f"[OK] {name}: {version}")

    except Exception as exc:
        print(f"[ERROR] {name}: {exc}")

try:
    import torch

    print("\n--- PyTorch CUDA Diagnostics ---")
    print("PyTorch:", torch.__version__)
    print("CUDA compiled version:", torch.version.cuda)
    print("CUDA available:", torch.cuda.is_available())

    if torch.cuda.is_available():
        print("GPU count:", torch.cuda.device_count())

        for i in range(torch.cuda.device_count()):
            print("GPU:", torch.cuda.get_device_name(i))
            print("Capability:", torch.cuda.get_device_capability(i))

        print("cuDNN:", torch.backends.cudnn.version())

except ImportError:
    print("[INFO] PyTorch not installed")

PY

# ============================================================
# 5. SYSTEM TOOLS
# ============================================================

echo ""
echo "[5/7] SYSTEM TOOLS"
echo "------------------------------------------------------------"

for cmd in \
    git curl wget sshd nginx tmux htop tree \
    unzip rsync jq ss lsof rpweld runpod-uploader; do

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK] $cmd: $(command -v "$cmd")"
    else
        echo "[MISSING] $cmd"
    fi
done

# ============================================================
# 6. START SERVICES
# ============================================================

echo ""
echo "[6/7] STARTING SERVICES"
echo "------------------------------------------------------------"

mkdir -p /var/run/sshd /workspace /root/.ssh
chmod 700 /root/.ssh
chown root:root /root /root/.ssh

# ------------------------------------------------------------
# SSH PUBLIC KEY CONFIGURATION (RUNPOD)
# ------------------------------------------------------------

echo ""
echo "--- Configuring RunPod SSH Public Key ---"

touch /root/.ssh/authorized_keys

# RunPod uses RUNPOD_PUBLIC_KEY (and sometimes PUBLIC_KEY)
COMBINED_KEYS="${RUNPOD_PUBLIC_KEY:-}"
if [ -n "${PUBLIC_KEY:-}" ]; then
    COMBINED_KEYS="${COMBINED_KEYS}"$'\n'"${PUBLIC_KEY}"
fi

if [ -n "${COMBINED_KEYS//[[:space:]]/}" ]; then
    printf '%s\n' "$COMBINED_KEYS" | awk 'NF' >> /root/.ssh/authorized_keys
    sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
    echo "[OK] RunPod SSH public key(s) installed ($(wc -l < /root/.ssh/authorized_keys) key(s))"
else
    echo "[WARNING] Neither RUNPOD_PUBLIC_KEY nor PUBLIC_KEY is set"
fi

chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

# Export container environment variables so SSH sessions inherit them
env | grep -E '^(RUNPOD_|CUDA|NVIDIA|HF_|PATH=|LD_LIBRARY_PATH=)' > /etc/environment || true

# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------

echo ""
echo "--- Starting SSH ---"

ssh-keygen -A

# Allow custom SSH_PASSWORD override, otherwise keep default 'runpod' from Dockerfile
if [ -n "${SSH_PASSWORD:-}" ]; then
    echo "root:${SSH_PASSWORD}" | chpasswd
    echo "[INFO] Custom SSH_PASSWORD applied"
else
    echo "[INFO] Default SSH password ('runpod') active alongside public-key auth"
fi

/usr/sbin/sshd -t
/usr/sbin/sshd -D -e &

echo "[OK] SSH started"

# ------------------------------------------------------------
# NGINX
# ------------------------------------------------------------

echo ""
echo "--- Starting NGINX ---"

nginx -t
nginx

echo "[OK] NGINX started"

# ------------------------------------------------------------
# RUNPOD FILE UPLOADER
# ------------------------------------------------------------

echo ""
echo "--- Starting RunPod File Uploader ---"

if command -v runpod-uploader >/dev/null 2>&1; then

    runpod-uploader > /dev/null 2>&1 &

    UPLOADER_PID=$!

    sleep 2

    if kill -0 "$UPLOADER_PID" 2>/dev/null; then
        echo "[OK] RunPod File Uploader started"
        echo "[INFO] PID: $UPLOADER_PID"
        echo "[INFO] Expected port: 2999"
    else
        echo "[ERROR] File Uploader exited during startup"
    fi

else

    echo "[ERROR] runpod-uploader not installed"

fi

# ------------------------------------------------------------
# PORT INFORMATION
# ------------------------------------------------------------

echo ""
echo "--- Listening Ports ---"

ss -lntp || true

# ============================================================
# 7. START JUPYTER LAB
# ============================================================

echo ""
echo "============================================================"
echo "             STARTING JUPYTER LAB"
echo "============================================================"

echo "[INFO] Workspace: /workspace"
echo "[INFO] Jupyter port: 8888"
echo "[INFO] Uploader port: 2999"
echo "[INFO] SSH port: 22"

exec jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --allow-root \
    --no-browser \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_origin_pat='.*' \
    --ServerApp.token="${JUPYTER_TOKEN:-}" \
    --ServerApp.password='' \
    --ServerApp.root_dir='/workspace'
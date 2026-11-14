#!/bin/bash
set -e

echo ""
echo "============================================================"
echo "         NVIDIA CUDA RUNPOD CONTAINER STARTUP"
echo "============================================================"

# ------------------------------------------------------------
# 1. NVIDIA GPU INFORMATION
# ------------------------------------------------------------

echo ""
echo "[1/6] NVIDIA GPU INFORMATION"
echo "------------------------------------------------------------"

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
else
    echo "[WARNING] nvidia-smi not available"
fi

# ------------------------------------------------------------
# 2. CUDA INFORMATION
# ------------------------------------------------------------

echo ""
echo "[2/6] CUDA INFORMATION"
echo "------------------------------------------------------------"

if command -v nvcc >/dev/null 2>&1; then
    nvcc --version
else
    echo "[INFO] nvcc not installed (runtime image)"
fi

if [ -f /usr/local/cuda/version.json ]; then
    cat /usr/local/cuda/version.json
elif [ -f /usr/local/cuda/version.txt ]; then
    cat /usr/local/cuda/version.txt
fi

# Check CUDA libraries
for lib in libcudart.so libcublas.so libcudnn.so; do
    if ldconfig -p 2>/dev/null | grep -q "$lib"; then
        echo "[OK] $lib available"
    else
        echo "[INFO] $lib not found in ldconfig cache"
    fi
done

# ------------------------------------------------------------
# 3. PYTHON INFORMATION
# ------------------------------------------------------------

echo ""
echo "[3/6] PYTHON INFORMATION"
echo "------------------------------------------------------------"

python --version
pip --version
uv --version 2>/dev/null || echo "[INFO] uv unavailable"

# ------------------------------------------------------------
# 4. IMPORTANT PYTHON LIBRARIES
# ------------------------------------------------------------

echo ""
echo "[4/6] PYTHON LIBRARY AVAILABILITY"
echo "------------------------------------------------------------"

python - <<'PY'
import importlib.metadata as metadata
import importlib.util

packages = {
    "torch": "PyTorch",
    "torchvision": "TorchVision",
    "torchaudio": "TorchAudio",
    "transformers": "HuggingFace Transformers",
    "tokenizers": "HuggingFace Tokenizers",
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
    "yaml": "PyYAML",
    "orjson": "Orjson",
    "psutil": "PSUtil",
    "cryptography": "Cryptography",
}

for module, name in packages.items():
    try:
        spec = importlib.util.find_spec(module)
        if spec is None:
            print(f"[MISSING] {name}")
            continue

        try:
            version = metadata.version(module.replace("cv2", "opencv-python")
                                            .replace("sklearn", "scikit-learn")
                                            .replace("PIL", "Pillow")
                                            .replace("yaml", "PyYAML"))
        except metadata.PackageNotFoundError:
            version = "installed"

        print(f"[OK] {name}: {version}")

    except Exception as e:
        print(f"[ERROR] {name}: {e}")

# PyTorch CUDA diagnostics
try:
    import torch

    print("\n--- PyTorch CUDA Diagnostics ---")
    print("PyTorch:", torch.__version__)
    print("CUDA compiled version:", torch.version.cuda)
    print("CUDA available:", torch.cuda.is_available())

    if torch.cuda.is_available():
        print("GPU count:", torch.cuda.device_count())

        for i in range(torch.cuda.device_count()):
            print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
            print(f"Capability: {torch.cuda.get_device_capability(i)}")

        print("cuDNN version:", torch.backends.cudnn.version())
    else:
        print("[INFO] CUDA GPU unavailable to PyTorch")

except ImportError:
    print("[INFO] PyTorch not installed")

PY

# ------------------------------------------------------------
# 5. SYSTEM TOOLS
# ------------------------------------------------------------

echo ""
echo "[5/6] SYSTEM TOOLS"
echo "------------------------------------------------------------"

for cmd in git curl wget sshd nginx tmux htop tree unzip rsync; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK] $cmd: $(command -v "$cmd")"
    else
        echo "[MISSING] $cmd"
    fi
done

# Runpod Weld
if command -v rpweld >/dev/null 2>&1; then
    echo ""
    echo "--- Runpod Weld ---"
    rpweld --version || true
else
    echo "[INFO] Runpod Weld unavailable"
fi

# ------------------------------------------------------------
# 6. START SERVICES
# ------------------------------------------------------------

echo ""
echo "[6/6] STARTING SERVICES"
echo "------------------------------------------------------------"

# Start SSH
/usr/sbin/sshd -D -e &

echo "[OK] SSH service started"

echo ""
echo "============================================================"
echo "         STARTING JUPYTER LAB"
echo "============================================================"

exec jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --allow-root \
    --no-browser \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_origin_pat='.*' \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.root_dir='/workspace'
# ============================================================
# NVIDIA CUDA 12.9 + CUDNN RUNTIME
# RunPod Development Environment
# ============================================================

FROM vishva123/nvidia-cuda-12.9-cudnn-runtime-ubuntu24.04-python-3.12

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ============================================================
# ENVIRONMENT
# ============================================================

WORKDIR /workspace

ENV PATH="/opt/venv/bin:/usr/local/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ENV HF_HOME="/workspace/.cache/huggingface"
ENV HF_XET_HIGH_PERFORMANCE=1

# ============================================================
# SYSTEM DEPENDENCIES
# ============================================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    openssh-server \
    nginx \
    curl \
    wget \
    ca-certificates \
    vim \
    nano \
    tmux \
    htop \
    tree \
    unzip \
    zip \
    jq \
    rsync \
    procps \
    iproute2 \
    dnsutils \
    lsof \
    file \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# SSH CONFIGURATION
# ============================================================

RUN mkdir -p /var/run/sshd /etc/ssh/sshd_config.d && \
    printf '%s\n' \
    'PermitRootLogin prohibit-password' \
    'PubkeyAuthentication yes' \
    'PasswordAuthentication no' \
    'UsePAM no' \
    > /etc/ssh/sshd_config.d/99-runpod.conf

# ============================================================
# PYTHON DEVELOPMENT ENVIRONMENT
# ============================================================

RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install \
    jupyterlab \
    notebook \
    ipywidgets \
    ipykernel \
    jupyterlab-widgets \
    numpy \
    scipy \
    pandas \
    scikit-learn \
    matplotlib \
    tqdm \
    Pillow \
    opencv-python \
    rich \
    cryptography \
    hf_xet \
    hf_transfer \
    requests \
    httpx \
    aiohttp \
    aiofiles \
    websockets \
    fastapi \
    "uvicorn[standard]" \
    python-multipart \
    pyyaml \
    orjson \
    psutil \
    packaging \
    safetensors \
    sentencepiece \
    protobuf \
    huggingface_hub \
    uv

# ============================================================
# INSTALL RUNPOD WELD
# ============================================================

RUN VERSION=$(curl -fsSL \
        https://api.github.com/repos/kodxana/Runpod-Weld/releases/latest \
        | jq -r '.tag_name | sub("^v"; "")') \
    && test -n "$VERSION" \
    && BASE="https://github.com/kodxana/Runpod-Weld/releases/download/v${VERSION}" \
    && curl -fL "${BASE}/rpweld_${VERSION}_amd64.deb" \
        -o "/tmp/rpweld_${VERSION}_amd64.deb" \
    && curl -fL "${BASE}/SHA256SUMS" \
        -o /tmp/SHA256SUMS \
    && cd /tmp \
    && sha256sum -c --ignore-missing SHA256SUMS \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        "./rpweld_${VERSION}_amd64.deb" \
    && rpweld --version \
    && rm -f "/tmp/rpweld_${VERSION}_amd64.deb" \
        /tmp/SHA256SUMS \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# INSTALL RUNPOD FILE UPLOADER
# ============================================================

RUN curl -fsSL \
    https://github.com/kodxana/RunPod-FilleUploader/raw/main/scripts/installer.sh \
    -o /tmp/runpod-uploader-installer.sh \
    && chmod +x /tmp/runpod-uploader-installer.sh \
    && /bin/bash /tmp/runpod-uploader-installer.sh \
    && command -v runpod-uploader \
    && rm -f /tmp/runpod-uploader-installer.sh

# ============================================================
# WORKSPACE AND STARTUP CONFIGURATION
# ============================================================

RUN mkdir -p \
    /workspace \
    /workspace/.cache/huggingface \
    /var/log \
    /var/run/sshd

# ============================================================
# VERIFY INSTALLED COMMANDS
# ============================================================

RUN python --version \
    && pip --version \
    && uv --version \
    && rpweld --version \
    && command -v runpod-uploader \
    && nginx -v \
    && ssh -V

# ============================================================
# EXPOSE RUNPOD PORTS
# ============================================================

EXPOSE 22
EXPOSE 80
EXPOSE 8888
EXPOSE 2999

# ============================================================
# ENTRYPOINT
# ============================================================

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]

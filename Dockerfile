# ============================================================
# NVIDIA PYTORCH 2.14 + CUDA 13.2 + CUDNN DEVEL
# RunPod Development Environment
# ============================================================

FROM pytorch/pytorch:2.14.1-cuda13.2-cudnn9-devel

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PATH="/opt/conda/bin:/usr/local/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH" \
    HF_HOME="/workspace/.cache/huggingface" \
    HF_XET_HIGH_PERFORMANCE=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1

WORKDIR /workspace

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

RUN mkdir -p /var/run/sshd /root/.ssh /etc/ssh/sshd_config.d && \
    chmod 700 /root/.ssh && \
    ssh-keygen -A && \
    echo 'root:runpod' | chpasswd && \
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config && \
    printf '%s\n' \
    'PermitRootLogin yes' \
    'PubkeyAuthentication yes' \
    'PasswordAuthentication yes' \
    'AuthorizedKeysFile .ssh/authorized_keys' \
    'UsePAM no' \
    > /etc/ssh/sshd_config.d/00-runpod.conf && \
    echo 'export PATH="/opt/conda/bin:/usr/local/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH"' >> /root/.bashrc

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
    transformers \
    tokenizers \
    accelerate \
    datasets \
    uv

# ============================================================
# INSTALL FLASH-ATTN
# ============================================================

RUN MAX_JOBS=2 pip install \
    https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.10.0/flash_attn-2.8.3+cu132torch2.14-cp312-cp312-linux_x86_64.whl \
    --no-build-isolation

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
# EXPOSE RUNPOD PORTS
# ============================================================

EXPOSE 22 80 8888 2999

# ============================================================
# ENTRYPOINT
# ============================================================

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
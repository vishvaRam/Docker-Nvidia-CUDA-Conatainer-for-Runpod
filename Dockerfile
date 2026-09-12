# Use YOUR custom NVIDIA CUDA base image with Python 3.12 and uv
FROM vishva123/nvidia-cuda-12.6-cudnn-runtime-ubuntu24.04-python-3.12

# Set the working directory inside the container
WORKDIR /workspace

# Set PATH to include Python 3.12 binaries and CUDA
# Your base image already has python3.12 at /usr/local/bin
ENV PATH="/opt/venv/bin:/usr/local/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Install common development tools and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    openssh-server \
    nginx \
    curl \
    vim \
    nano \
    wget \
    tmux \
    htop \
    tree \
    unzip \
    zip \
    rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Generate SSH host keys for SSH access
RUN ssh-keygen -A


# Install JupyterLab and common Python packages
RUN pip install \
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
    pyyaml \    
    orjson \    
    psutil \    
    packaging \ 
    uv && \
    jupyter labextension enable @jupyter-widgets/jupyterlab-manager

# Configure SSH
RUN mkdir -p /var/run/sshd && \
    echo 'root:runpod' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Ensure PATH is set for SSH sessions
RUN echo 'export PATH="/opt/venv/bin:/usr/local/bin:$PATH"' >> /root/.bashrc

# Expose ports for JupyterLab and SSH
EXPOSE 8888
EXPOSE 22

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Enable Hugging Face fast transfers
ENV HF_XET_HIGH_PERFORMANCE=1

# Copy and set up entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use the entrypoint script to manage services
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

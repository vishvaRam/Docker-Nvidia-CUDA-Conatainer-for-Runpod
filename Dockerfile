# Use YOUR custom NVIDIA CUDA base image with Python 3.11 and uv
FROM vishva123/nvdia-cuda-13.0.1-cudnn-devel-ubuntu24.04-py-3.11-uv

# Set the working directory inside the container
WORKDIR /workspace

# Set PATH to include Python 3.11 binaries and CUDA
# Your base image already has python3.11 at /usr/local/bin
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
    "jupyterlab-widgets>=1.0.0" \
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
    hf_transfer && \
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

# Copy and set up entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use the entrypoint script to manage services
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

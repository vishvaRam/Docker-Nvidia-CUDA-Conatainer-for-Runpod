# NVIDIA CUDA & PyTorch RunPod Container Images

This repository contains Dockerfiles and an entrypoint script for building GPU-accelerated
development containers optimized for [RunPod](https://runpod.io). Each Git branch targets a
specific combination of **NVIDIA CUDA**, **cuDNN**, and **PyTorch** versions, along with a
matching Python environment.

---

## Repository Layout

| File | Purpose |
| --- | --- |
| `Dockerfile` | The build file for the current branch (`Nvidia-CUDA-13.2`). |
| `entrypoint.sh` | Startup script that reports GPU/CUDA/Python info and launches SSH, NGINX, the file uploader, and JupyterLab. |
| `README.md` | This documentation file. |

Each branch carries its own version of the `Dockerfile`. The shared `entrypoint.sh` is copied
into every image and provides a consistent startup experience.

---

## How Branches Are Organized

There are two families of images:

1. **`Nvidia-CUDA-*`** — Base images built on the `vishva123/nvidia-cuda-*` images. These expose
   CUDA and cuDNN but **do not** include PyTorch.
2. **`Pytorch-*`** — Images built on the official `pytorch/pytorch` images, pre-baking
   PyTorch, cuDNN, and a prebuilt **flash-attention** wheel for the matching CUDA version.

Every image ships with:

- SSH access (password `runpod` by default, or via public key)
- NGINX (port 80)
- JupyterLab (port 8888)
- RunPod file uploader (port 2999)
- A Python 3.12 environment with common scientific and ML packages

---

## Branch Reference

### CUDA-only images (`Nvidia-CUDA-*`)

| Branch | Base image | CUDA | cuDNN mode | Python | Flash-attention |
| --- | --- | --- | --- | --- | --- |
| `Nvidia-CUDA-12.6` | `vishva123/nvidia-cuda-12.6-cudnn-runtime-ubuntu24.04-python-3.12` | 12.6 | **runtime** | 3.12 | — |
| `Nvidia-CUDA-12.9` | `vishva123/nvidia-cuda-12.9-cudnn-devel-ubuntu24.04-python-3.12` | 12.9 | **devel** | 3.12 | — |
| `Nvidia-CUDA-13.0` | `vishva123/nvidia-cuda-13.0-cudnn-devel-ubuntu24.04-python-3.12` | 13.0 | **devel** | 3.12 | — |
| `Nvidia-CUDA-13.2` *(current)* | `vishva123/nvidia-cuda-13.2-cudnn-devel-ubuntu24.04-python-3.12` | 13.2 | **devel** | 3.12 | — |

> The `Nvidia-CUDA-12.6` branch uses the **runtime** variant; all others use the **devel**
> variant, which includes the CUDA development headers needed to compile packages from source.

### PyTorch images (`Pytorch-*`)

| Branch | Base image | PyTorch | CUDA | cuDNN | Flash-attention wheel |
| --- | --- | --- | --- | --- | --- |
| `Pytorch-2.7.1-CUDA-12.8` | `pytorch/pytorch:2.7.1-cuda12.8-cudnn9-devel` | 2.7.1 | 12.8 | 9 | `flash-attn` (source build, `MAX_JOBS=4`) |
| `Pytorch-2.12-CUDA-12.6` | `pytorch/pytorch:2.12.1-cuda12.6-cudnn9-devel` | 2.12.1 | 12.6 | 9 | `flash_attn-2.8.3+cu126torch2.12` (v0.9.17) |
| `Pytorch-2.12-CUDA-13.0` | `pytorch/pytorch:2.12.1-cuda13.0-cudnn9-devel` | 2.12.1 | 13.0 | 9 | `flash_attn-2.8.3+cu130torch2.12` (v0.9.17) |
| `Pytorch-2.12-CUDA-13.2` | `pytorch/pytorch:2.12.1-cuda13.2-cudnn9-devel` | 2.12.1 | 13.2 | 9 | `flash_attn-2.8.3+cu132torch2.12` (v0.9.17) |
| `Pytorch-2.13-CUDA-12.6` | `pytorch/pytorch:2.13.0-cuda12.6-cudnn9-devel` | 2.13.0 | 12.6 | 9 | `flash_attn-2.8.3+cu126torch2.13` (v0.9.47) |
| `Pytorch-2.13-CUDA-13.0` | `pytorch/pytorch:2.13.0-cuda13.0-cudnn9-devel` | 2.13.0 | 13.0 | 9 | `flash_attn-2.8.3+cu130torch2.13` (v0.9.47) |
| `Pytorch-2.13-CUDA-13.2` | `pytorch/pytorch:2.13.0-cuda13.2-cudnn9-devel` | 2.13.0 | 13.2 | 9 | `flash_attn-2.8.3+cu132torch2.13` (v0.9.47) |
| `Pytorch-2.15-CUDA-13.4` | `pytorch/pytorch:2.15.0-cuda13.4-cudnn9-devel` | 2.15.0 | 13.4 | 9 | `flash_attn-2.8.3+cu134torch2.15` (v1.5.0) |

> The flash-attention wheel is chosen to match each image's CUDA and PyTorch versions. The
> `Pytorch-2.15-CUDA-13.4` branch is the newest and uses flash-attention prebuild v1.5.0.

---

## Commonly Installed Software

Every image (regardless of branch) installs the same set of system tools and Python packages:

**System tools:** `git`, `openssh-server`, `nginx`, `curl`, `wget`, `tmux`, `htop`, `tree`,
`unzip`, `zip`, `rsync`, `jq`, and a broad set of libraries.

**RunPod integrations:**
- **RunPod Weld** (`rpweld`) — installed from the latest GitHub release, with SHA-256 verification.
- **RunPod File Uploader** (`runpod-uploader`) — a helper for pushing files into the container.

**Python packages:** `jupyterlab`, `notebook`, `ipywidgets`, `numpy`, `scipy`, `pandas`,
`scikit-learn`, `matplotlib`, `opencv-python`, `transformers`, `tokenizers`, `accelerate`,
`datasets`, `huggingface_hub`, `fastapi`, `uvicorn`, and many more.

---

## Ports Exposed

| Port | Service |
| --- | --- |
| 22 | SSH |
| 80 | NGINX |
| 8888 | JupyterLab |
| 2999 | RunPod file uploader |

---

## Using an Image on RunPod

1. Create a RunPod container and select the branch you want as the image source, e.g.
   `Nvidia-CUDA-13.2` or `Pytorch-2.15-CUDA-13.4`.
2. Connect via SSH (password `runpod`) or open JupyterLab on port 8888.
3. Upload code with the RunPod file uploader (port 2999).

---

## Choosing a Branch

- **Need CUDA without PyTorch?** Use a `Nvidia-CUDA-*` branch.
- **Need PyTorch + CUDA?** Use a `Pytorch-*` branch and pick the CUDA version that matches your
  model's requirements.
- **Latest versions?** `Pytorch-2.15-CUDA-13.4` is the newest combination.
- **Compiling from source?** Any `devel` variant (all except `Nvidia-CUDA-12.6`) includes the
  CUDA development headers.

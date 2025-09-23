# GPU Cluster Setup

### 1. Login your GPU compute provider.
For this, it's assumed your working directory is either `/` or `/workspace`. Edit as needed.

### 2. Run the below:
`mkdir -p /workspace ; cd /workspace ; git clone https://github.com/keennay/gpu-cluster-setup.git ; mv gpu-cluster-setup scripts ; cd scripts`<br><br>
`./01_init.sh`<br>
`./02_install_dependencies.sh`<br>
`./03_install_python.sh`<br>
`source ./04_setup_env.sh`<br>
`./05_install_packages.sh`<br>

### 3. Install any selection of open-weights models (DeepSeek V3/V3.1/R1, GLM-4.5, gpt-oss, Kimi K2, Qwen3)
./install_model.sh

### Template for Running GLM-4.5:
./run_glm.sh

### Change Between Python Environments
./launch_env.sh

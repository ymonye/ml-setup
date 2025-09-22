# GPU Cluster Setup

### 1. Login your GPU compute provider.
For this, it's assumed your working directory is either `/` or `/workspace`. Edit as needed.

### 2a. If the default user is `root`, run the below:
`mkdir -p /workspace ; cd /workspace ; git clone https://github.com/ymonye/ml-setup.git ; mv ml-setup scripts ; cd scripts`<br><br>
`./01_init.sh`<br>
`./02_install_dependencies.sh`<br>
`./03_install_python.sh`<br>
`source ./04_setup_env.sh`<br>
`./05_install_packages.sh`<br>

### 2b. If the default user is `user`, run the below:
`sudo mkdir -p /workspace ; sudo chown -R ubuntu:ubuntu /workspace ; cd /workspace ; git clone https://github.com/ymonye/ml-setup.git ; mv ml-setup scripts ; cd scripts`<br><br>
`sudo ./01_init.sh`<br>
`sudo ./02_install_dependencies.sh`<br>
`./03_install_python.sh`<br>
`source ./04_setup_env.sh`<br>
`./05_install_packages.sh`<br>

### 3. Install any selection of open-weights models (DeepSeek, GLM, gpt-oss, Kimi K2, Qwen3)
./install_model.sh

### Run / Install GLM 4.5:
./run_glm.sh

### Change Between Python Environments
./launch_env.sh

# GPU Cluster Setup

### Login your GPU compute provider. If it has a username other than ubuntu, replace it below.
sudo mkdir -p /workspace ; sudo chown -R ubuntu:ubuntu /workspace ; cd /workspace ; git clone https://github.com/ymonye/ml-setup.git ; mv ml-setup scripts ; cd scripts

### Setup the server with the following commands (Assumes using H100/H200/B200 GPU types)

#### As `root`
./01_init.sh<br>
./02_install_dependencies.sh<br>
./03_install_python.sh<br>
source ./04_setup_env.sh<br>
./05_install_packages.sh

#### As `user`
sudo ./01_init.sh<br>
sudo ./02_install_dependencies.sh<br>
./03_install_python.sh<br>
source ./04_setup_env.sh<br>
./05_install_packages.sh

### Install Selection of LLM
./install_model.sh

### Run GLM 4.5:
./run_glm.sh

### Change Between Python Environments
./launch_env.sh

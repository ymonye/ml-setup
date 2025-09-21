# ml-setup

### Login your GPU compute VPS. If it has a username other than ubuntu, replace it below.
sudo mkdir -p /workspace ; sudo chown -R ubuntu:ubuntu /workspace/* ; cd /workspace ; git clone https://github.com/ymonye/ml-setup.git ; mv ml-setup scripts ; cd scripts

### Setup Server with the Following Commands (Assumes using H100/H200/B200 GPU types)

./00_init.sh<br>
./01_install_dependencies.sh<br>
./02_install_python.sh<br>
source ./03_setup_env.sh<br>
./04_install_packages.sh

### Install Desired LLM
./install_model.sh

### Run Desired LLM (This will ask for the vLLM or SGLang,  model name, & num GPUs)
./run_glm.sh

### Change Between Python Environments
./launch_env.sh

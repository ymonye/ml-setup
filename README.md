# ml-setup

### Login your GPU compute VPS. If it has a username other than ubuntu, replace it below.
sudo mkdir -p /workspace ; sudo chown -R ubuntu:ubuntu /workspace ; cd /workspace ; git clone https://github.com/ymonye/ml-setup.git ; mv ml-setup scripts ; cd scripts

### Setup Server with the Following Commands (Assumes using H100/H200/B200 GPU types)

./01_init.sh<br>
./02_install_dependencies.sh<br>
./03_install_python.sh<br>
source ./04_setup_env.sh<br>
./05_install_packages.sh

### Install Desired LLM
* (1) DeepSeek-V3/V3.1/R1 (LMDeploy)
* (2) DeepSeek-V3/V3.1/R1 (SGLang)
* (3) DeepSeek-V3/V3.1/R1 (vLLM)
* (4) GLM 4.5 (SGLang)
* (5) GLM 4.5 (vLLM)
* (6) gpt-oss (Transformers)
* (7) gpt-oss (vLLM)
* (8) Kimi K2 (SGLang)
* (9) Kimi K2 (vLLM)
* (10) Qwen3 (SGLang)
* (11) Qwen3 (Transformers)
* (12) Qwen3 (vLLM)
* (13) Custom

./install_model.sh

### Run Desired LLM, this will ask for the following:
### 
./run_glm.sh

### Change Between Python Environments
./launch_env.sh

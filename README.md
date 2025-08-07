# ml-setup

### Login your GPU compute VPS. If it has a username other than ubuntu, replace it below.
sudo mkdir -p /data/ml ; sudo chown -R ubuntu:ubuntu /data/* ; cd /data/ml ; git clone https://github.com/ymonye/ml-setup.git ; mv ml-setup scripts ; cd scripts

### Run 00_init.sh, then the rest in numerical order

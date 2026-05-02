#!/bin/bash
set -e

## Single update and all dependencies in one pass
sudo apt update
sudo apt install -y \
    linux-modules-extra-$(uname -r) \
    ca-certificates curl \
    adb scrcpy \
    lzip python3 python3-venv python3-pip

## Kernel modules
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
sudo tee /etc/modules-load.d/redroid.conf << 'EOF'
binder_linux
options binder_linux devices="binder,hwbinder,vndbinder"
EOF

## Docker installation
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

## redroid/GApps image build
mkdir -p ~/redroid
cd ~/redroid
if [ ! -d "redroid-script" ]; then
    git clone https://github.com/ayasa520/redroid-script.git
fi
cd redroid-script
python3 -m venv venv
venv/bin/pip install -r requirements.txt
sudo venv/bin/python3 redroid.py -a 11.0.0 -g -c docker
cd ~/redroid

## Verify Docker image build
if ! sudo docker images | grep -q "11.0.0_gapps"; then
    echo "Error: Docker image build failed. Check output above."
    exit 1
fi


## Docker compose setup
cat > docker-compose.yml << 'EOF'
services:
  redroid:
    image: redroid/redroid:11.0.0_gapps # We use Android 11 so we can register devices.
    stdin_open: true
    tty: true
    privileged: true
    ports:
      - 127.0.0.1:5555:5555 # Only listen on localhost for safety, we can use SSH tunneling
    volumes:
      - ./redroid-11-data:/data # Where the data is written
    command:
      - androidboot.redroid_width=720 # Screen resolution
      - androidboot.redroid_height=1280
      - androidboot.redroid_dpi=320
      - androidboot.redroid_fps=60
      - androidboot.redroid_gpu_mode=guest # host = GPU acceleration, guest = software rendering
      #- ro.product.cpu.abilist0=x86_64,arm64-v8a,x86,armeabi-v7a,armeabi
      #- ro.product.cpu.abilist64=x86_64,arm64-v8a
      #- ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi
      #- ro.dalvik.vm.isa.arm=x86
      #- ro.dalvik.vm.isa.arm64=x86_64
      #- ro.enable.native.bridge.exec=1
      #- ro.dalvik.vm.native.bridge=libndk_translation.so
      #- ro.ndk_translation.version=0.2.2
EOF

echo "Starting docker container..."
sudo docker compose up -d

echo "Waiting for redroid to start..."
until adb connect 127.0.0.1:5555 2>&1 | grep -q "connected"; do
    sleep 2
done

echo "Device connected, waiting for boot to complete..."
adb -s 127.0.0.1:5555 wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 2; done'

echo "Pushing KISS launcher..."
adb -s 127.0.0.1:5555 install ~/maple-idle-emulation/KISS.apk

echo "Setup complete. Run start.sh to start the container."

#!/usr/bin/env bash
set -x
PACKAGES=$(grep -v -E "^\s*#" apt_packages.txt)
sudo apt update
sudo apt install -y $PACKAGES

sudo snap install microk8s --classic --channel=1.27
microk8s status --wait-ready
microk8s enable dns
microk8s enable hostpath-storage
microk8s enable ingress 
microk8s enable dashboard
microk8s enable registry --size=40Gi
microk8s status --wait-ready
sudo snap alias microk8s.kubectl kubectl


# Install Brave (Chrome Clone with less tracking)
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update
sudo apt install -y brave-browser


curl -fsSL https://get.docker.com | sudo sh - 
curl -fsSL https://get.pnpm.io/install.sh | sh -
pnpm env use --global 16
node --version

sudo update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

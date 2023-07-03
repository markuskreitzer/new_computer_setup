#!/usr/bin/bash
set -e
set -x 
#
# Copyright 2022 Markus Kreitzer, All Rights Reserved
#
# Install required system packages.

# Uncomment here if you are running in an env that MITM's all traffic.
#CURL_CERT_IGNORE=' -k '
CURL_CERT_IGNORE=' '

function install_apt_dependencies {
    sudo DEBIAN_FRONTEND=noninteractive apt update -yq
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq
    wget https://raw.githubusercontent.com/markuskreitzer/new_computer_setup/master/apt_packages.txt
    while read -r line; do
        sudo apt install -y "$line" || echo "Failed to install $line"
    done < <(grep -v -E "^\s*#" apt_packages.txt)
    rm -f apt_packages.txt
    sudo update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100
}

function install_docker_ubuntu {
    echo "Install Docker and Docker-Compose"
    sudo apt-get remove docker docker-engine docker.io containerd runc || echo ""
	curl $CURL_CERT_IGNORE -fsSL https://get.docker.com | bash - 
	sudo  su -c "curl $CURL_CERT_IGNORE -SL https://github.com/docker/compose/releases/download/v2.14.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose"
	sudo usermod -a -G docker $USER
	echo "Don't forget to update your /etc/docker/daemon.json file"
}

function install_starship_hacknerdfont {
  #############################################
  echo "Install Starship and required fonts."
  #############################################
	git clone "https://github.com/markuskreitzer/hack-font-ligature-nerd-font.git"
	mkdir ~/.fonts || echo "$HOME/.fonts already exists! Continuing..."
	cp hack-font-ligature-nerd-font/font/*.ttf ~/.fonts && rm -rf hack-font-ligature-nerd-font
	curl "$CURL_CERT_IGNORE" -sS https://starship.rs/install.sh | sudo sh -
	echo 'eval "$(starship init bash)"' >> ~/.bashrc
}

function install_microk8s_ubuntu {
  echo "Install Microk8s"
	sudo snap install microk8s --classic
	sudo snap alias microk8s.kubectl kubectl
	sudo snap alias microk8s.kubectl kk 
	sudo usermod -a -G microk8s $USER
	sudo chown -f -R $USER ~/.kube || echo ".kube did not exist"
	echo "Kubectl Auto Completion" >> ~/.bashrc
	echo 'source <(kk completion bash | sed "s/kubectl/kk/g")' >> ~/.bashrc
	echo 'source <(kubectl completion bash)' >> ~/.bashrc
	microk8s inspect
	cat >/etc/docker/daemon.json <<EOF
{
    "insecure-registries" : ["localhost:32000"] 
}
EOF
  sudo microk8s status --wait-ready
	sudo microk8s enable dashboard
  sudo microk8s enable ingress
	sudo microk8s enable dns
  sudo microk8s enable registry
  sudo microk8s enable istio
	sudo microk8s kubectl get all --all-namespaces
	#microk8s dashboard-proxy
}

function install_node_ubuntu {
    echo "Install Node.js with yarn"
	# update to newer version from: https://github.com/nodesource/distributions/blob/master/README.md#debinstall
	curl $CURL_CERT_IGNORE -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - && sudo apt-get install -y nodejs
	mkdir ~/.npm-global
	npm config set prefix "$HOME/.npm-global"
	echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.profile
	npm i -g pnpm yarn
}

function install_pnpm_node {
    curl $CURL_CERT_IGNORE -fsSL https://get.pnpm.io/install.sh | sh -
    pnpm env use --global 16
    pnpm install -g yarn
    node --version
    yarn --version
}

function install_vscode_ubuntu {
    echo "Install IDE Stuff"
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
	rm -f packages.microsoft.gpg
	sudo apt update
	sudo apt install -y code # or code-insiders
	extensions="eamodio.gitlens ms-azuretools.vscode-docker ms-kubernetes-tools.vscode-kubernetes-tools ms-python.isort ms-python.python ms-python.vscode-pylance ms-toolsai.jupyter ms-toolsai.jupyter-keymap ms-toolsai.jupyter-renderers ms-toolsai.vscode-jupyter-cell-tags ms-toolsai.vscode-jupyter-slideshow ms-vscode-remote.remote-containers ms-vscode.vscode-typescript-next redhat.vscode-yaml vscodevim.vim Vue.vscode-typescript-vue-plugin"
	for e in $extensions
	do	
		echo "Installing $e"
		code --install-extension $e
	done
}

function install_rust {
  curl $CURL_CERT_IGNORE --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source "$HOME"/.cargo/env
  wget https://raw.githubusercontent.com/markuskreitzer/new_computer_setup/master/linux/cargo_packages.txt
  grep -v '^#' cargo_packages.txt | while IFS= read -r package
  do
    cargo install "$package"
  done

}

function install_brave_ubuntu {
    echo "Install Brave (Chrome Clone with less tracking)"
    sudo curl $CURL_CERT_IGNORE -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update
    sudo apt install -y brave-browser
}


sudo DEBIAN_FRONTEND=noninteractive apt update -yq
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq
sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y
echo "Reboot the system and rerun this script to load any new kernel updates. Press y to reboot. Press any other key to continue."
read -r line
if [ "$line" == "y" ]; then
  sudo reboot
fi

install_apt_dependencies
install_rust
install_starship_hacknerdfont
install_docker_ubuntu
install_microk8s_ubuntu
install_pnpm_node

#install_node_ubuntu
#install_vscode_ubuntu
#install_brave_ubuntu


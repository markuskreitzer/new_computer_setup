#!/usr/bin/bash
set -e
set -x 

#
# Copyright 2022 Markus Kreitzer, All Rights Reserved
#

# Install required system packages.
sudo apt update 
sudo apt upgrade -y  
sudo apt install -y curl build-essential uidmap git pandoc neovim apt-transport-https wget gpg 

#############################################
## Install Docker and Docker-Compose
#############################################
function install_docker {
	sudo apt-get remove docker docker-engine docker.io containerd runc || echo ""
	curl -fsSL https://get.docker.com | bash - 
	# dockerd-rootless-setuptool.sh install
	sudo  su -c "curl -SL https://github.com/docker/compose/releases/download/v2.14.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose"
	echo "Don't forget to update your /etc/docker/daemon.json file"
}

#############################################
## Install Starship and required fonts.
#############################################
function install_starship_hacknerdfont {
	git clone "https://github.com/markuskreitzer/hack-font-ligature-nerd-font.git"
	mkdir ~/.fonts || echo "~/.fonts already exists! Continuing..."
	cp hack-font-ligature-nerd-font/font/*.ttf ~/.fonts && rm -rf hack-font-ligature-nerd-font
	curl -sS https://starship.rs/install.sh -o starship_install.sh
	sh starship_install.sh -y && rm starship_install.sh
	echo 'eval "$(starship init bash)"' >> ~/.bashrc
}

#############################################
## Install Microk8s
#############################################
function install_microk8s {
	sudo snap install microk8s --classic
	sudo snap alias microk8s.kubectl kubectl
	sudo snap alias microk8s.kubectl kk 
	sudo usermod -a -G microk8s $USER
	sudo chown -f -R $USER ~/.kube || echo ".kube did not exist"
	echo 'source <(mk completion bash | sed "s/kubectl/kk/g")' >> ~/.bashrc
	microk8s inspect	
	cat >/etc/docker/daemon.json <<EOF
{
    "insecure-registries" : ["localhost:32000"] 
}
EOF
	microk8s enable dashboard
	microk8s enable dns
    microk8s enable registry:size=40Gi
    microk8s enable istio
	microk8s kubectl get all --all-namespaces
	microk8s dashboard-proxy
}

#############################################
## Install Node.js
#############################################
function install_node {
	# update to newer version from: https://github.com/nodesource/distributions/blob/master/README.md#debinstall
	# curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - && sudo apt-get install -y nodejs
	#mkdir ~/.npm-global
	#npm config set prefix '~/.npm-global'
	#echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.profile
	#npm i -g pnpm yarn
	curl -fsSL https://get.pnpm.io/install.sh | sh -
	pnpm env use --global 16 
}


#############################################
## Install IDE Stuff
#############################################
function install_ide {
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

install_starship_hacknerdfont
install_docker
install_node
install_ide
install_microk8s

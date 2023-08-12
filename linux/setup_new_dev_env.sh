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
  # Optional arguments are files containing lists of packages to install (default:  Pull apt_packages.txt from github)
  local files=("$@")

  local should_remove_file=false
  if [ ${#files[@]} -eq 0 ]; then
    should_remove_file=true
    wget -O apt_packages.txt "https://raw.githubusercontent.com/markuskreitzer/new_computer_setup/master/linux/apt_packages.txt"
    files=("apt_packages.txt")
  fi

  sudo DEBIAN_FRONTEND=noninteractive apt update -yq
  sudo DEBIAN_FRONTEND=noninteractive apt upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq
  for file in "${files[@]}"
  do
    while read -r line; do
      sudo DEBIAN_FRONTEND=noninteractive apt install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq "$line" || echo "Failed to install $line"
    done < <(awk '{print $1}' "$file" | grep -v -E "^\s*#")
  done
  if [ "$should_remove_file" = true ]; then
    rm -f apt_packages.txt
  fi
  sudo update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100
}

function install_snaps {
  while read -r line; do
    status=$(sudo snap install $line 2>&1)
    if [[ "$status" == *"already installed"* ]]; then
      sudo snap refresh $(echo "$line" | awk '{print $1}')
    else
      echo "$status"
    fi
  # Don't split due to snap flags
  done < <(grep -v -E "^\s*#" snaps.txt)
}

function install_docker_images {
  chmod +x ./install_docker_images.sh
  source ./install_docker_images.sh
}

function install_npm_packages {
  while read -r line; do
    npm install -g "$line" || echo "Failed to install $line"
  done < <(awk '{print $1}' npm_packages.txt | grep -v -E "^\s*#")
}

function install_docker_ubuntu {
  echo "Install Docker and Docker-Compose"
  sudo apt-get remove docker docker-engine docker.io containerd runc || echo ""
  curl $CURL_CERT_IGNORE -fsSL https://get.docker.com | bash -
  sudo  su -c "curl $CURL_CERT_IGNORE -SL https://github.com/docker/compose/releases/download/v2.14.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose"
  sudo usermod -a -G docker $USER
}

function install_starship_hacknerdfont {
  echo "Install Starship and required fonts."
  git clone "https://github.com/markuskreitzer/hack-font-ligature-nerd-font.git"
  mkdir ~/.fonts || echo "$HOME/.fonts already exists! Continuing..."
  cp hack-font-ligature-nerd-font/font/*.ttf ~/.fonts && rm -rf hack-font-ligature-nerd-font
  curl "$CURL_CERT_IGNORE" -sS https://starship.rs/install.sh | sudo sh -s -- -y --bin-dir /usr/local/bin
  echo 'eval "$(starship init bash)"' >> ~/.bashrc
}

function install_microk8s_ubuntu {
  echo "Install Microk8s"
  sudo snap install microk8s --classic
  # sudo iptables -P FORWARD ACCEPT
  # sudo netfilter-persistent save
  sudo snap alias microk8s.kubectl kubectl
  sudo snap alias microk8s.kubectl kk
  sudo usermod -a -G microk8s $USER
  sudo chown -f -R $USER ~/.kube || echo ".kube did not exist"
  echo "Kubectl Auto Completion" >> ~/.bashrc
  echo 'source <(kk completion bash | sed "s/kubectl/kk/g")' >> ~/.bashrc
  echo 'source <(kubectl completion bash)' >> ~/.bashrc
  cat << EOF | sudo tee /etc/docker/daemon.json
  {
      "insecure-registries" : ["localhost:32000"]
  }
EOF
  sudo systemctl restart docker.service
  sudo microk8s inspect
  sudo microk8s status --wait-ready
  sudo microk8s enable dashboard
  sudo microk8s enable ingress
  sudo microk8s enable dns
  sudo microk8s enable registry
  sudo microk8s enable ha-cluster
  sudo microk8s enable helm
  sudo microk8s enable helm3
  sudo microk8s enable hostpath-storage
  sudo microk8s enable metrics-server
  sudo microk8s enable storage
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
  curl $CURL_CERT_IGNORE -fsSL https://get.pnpm.io/install.sh -o install_pnpm.sh
  chmod +x install_pnpm.sh
  . ./install_pnpm.sh
  rm install_pnpm.sh
  export PATH="$HOME/.local/share/pnpm:$PATH"
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
  #extensions="eamodio.gitlens ms-azuretools.vscode-docker ms-kubernetes-tools.vscode-kubernetes-tools ms-python.isort ms-python.python ms-python.vscode-pylance ms-toolsai.jupyter ms-toolsai.jupyter-keymap ms-toolsai.jupyter-renderers ms-toolsai.vscode-jupyter-cell-tags ms-toolsai.vscode-jupyter-slideshow ms-vscode-remote.remote-containers ms-vscode.vscode-typescript-next redhat.vscode-yaml vscodevim.vim Vue.vscode-typescript-vue-plugin"
  extensions=$(curl -s $CURL_CERT_IGNORE "https://raw.githubusercontent.com/markuskreitzer/new_computer_setup/master/applications/vscode_extensions.txt")
  for e in $extensions
  do
    echo "Installing $e"
    code --install-extension $e
  done
}

function install_rust {
  curl $CURL_CERT_IGNORE --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME"/.cargo/env
  wget https://raw.githubusercontent.com/markuskreitzer/new_computer_setup/master/linux/cargo_packages.txt
  grep -v '^#' cargo_packages.txt | while IFS= read -r package
  do
    cargo install "$package"
  done
  rm cargo_packages.txt
  echo "alias cat='bat'" >> ~/.bashrc
  echo "alias ls='exa'" >> ~/.bashrc
}

function install_brave_ubuntu {
  echo "Install Brave (Chrome Clone with less tracking)"
  sudo curl $CURL_CERT_IGNORE -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  sudo apt update
  sudo apt install -y brave-browser
}

function install_speedtest {
  # The standard speed test that comes with Linux doesn't perform well on speeds above 300 Mbps.
  curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
  sudo apt-get install speedtest
}

function setup_aliases {
  curl -s https://raw.githubusercontent.com/markuskreitzer/new_computer_setup/master/linux/aliases.txt > $HOME/.aliases
  echo "source $HOME/.aliases" >> $HOME/.bashrc
  echo "set -o vi" >> $HOME/.bashrc
}

function install_basic_env {
  local files=("$@")
  
  install_apt_dependencies "${files[@]}"
  install_starship_hacknerdfont
  install_docker_images
  install_snaps
}

function install_google_chrome {
  echo "Install Google Chrome"
  cd /tmp >/dev/null || exit
  wget --quiet --output-document=google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg --install google-chrome-stable_current_amd64.deb
  sudo apt-get install google-chrome-stable --yes
  rm google-chrome-stable_current_amd64.deb
  cd - >/dev/null || exit
}

function install_opera {
  debFile='/tmp/opera-stable_100.0.4815.30_amd64.deb'
  url='https://download.opera.com/download/get/?id=62183&location=415&nothanks=yes&sub=marine&utm_tryagain=yes'

  echo "Install Opera (for Aria AI)"
  cd /tmp >/dev/null || exit
  wget "$url" -O "$debFile"
  chmod +x "$debFile"
  sudo dpkg --install "$debFile"
  sudo apt-get install "$debFile" --yes
  rm "$debFile"
  sudo apt-get update --yes
  cd - >/dev/null || exit
}

function install_kompose {
  curl $CURL_CERT_IGNORE -SL https://github.com/kubernetes/kompose/releases/download/v1.26.0/kompose-linux-amd64 -o kompose &&
    chmod +x kompose &&
    sudo mv ./kompose /usr/local/bin/kompose
}

function install_zsh {
  echo "Install Zsh"
  sudo apt-get install zsh -yq
  chsh -s "$(which bash)" "$USER"
}

function install_oh_my_zsh {
  echo "Install Oh My Zsh"
  if [ -d "$HOME/.oh-my-zsh.bak" ]; then
    rm -rf "$HOME/.oh-my-zsh.bak"
  fi
  if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh already installed. Backing up ~/.oh-my-zsh"
    mv "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh.bak"
  fi
  curl $CURL_CERT_IGNORE -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh --output install-oh-my-zsh.sh
  chmod +x install-oh-my-zsh.sh
  ZSH= sh ./install-oh-my-zsh.sh <<EOF
n
EOF
  rm install-oh-my-zsh.sh
  chsh -s "$(which bash)" "$USER"
}

function add_completion_scripts {
  cd ~ >/dev/null || exit
  mkdir -p ~/.bash/completion
  mkdir -p ~/.zsh/completion
  touch ~/.bashrc
  echo 'find ~/.bash/completion -type f | xargs -I {} bash -c "source {}"' >>~/.bashrc
  echo 'find ~/.zsh/completion -type f | xargs -I {} bash -c "source {}"' >>~/.zshrc
  cd - >/dev/null || exit

  # Docker
  # -> If Docker completion is not handled by installation script, may want to include it
  # curl $CURL_CERT_IGNORE -SL https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o ~/.bash/completion/docker
  # curl $CURL_CERT_IGNORE -SL https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/zsh/_docker -o ~/.zsh/completion/docker

  # Git
  curl $CURL_CERT_IGNORE -SL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.bash/completion/git-completion
  curl $CURL_CERT_IGNORE -SL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh -o ~/.zsh/completion/git-completion

  # Kompose
  kompose completion bash >"$HOME/.bash/completion/kompose"
  kompose completion zsh >"$HOME/.zsh/completion/kompose"
}

function install_containerization {
  install_docker_ubuntu
  install_microk8s_ubuntu
}

function install_nice_to_have {
  local files=("$@")
  install_apt_dependencies "${files[@]}"
  install_google_chrome
  install_opera
  install_kompose
  install_zsh
  install_oh_my_zsh
}

function install_it_admin {
  local files=("$@")
  install_apt_dependencies "${files[@]}"
}

function add_repositories {
  sudo add-apt-repository ppa:openshot.developers/ppa --yes

  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}
function check_options {
  for var in "$@"
  do
    if [[ "$var" == *"--gui"* ]]; then
      install_vscode_ubuntu
      install_brave_ubuntu
    fi
    if [[ "$var" == *"--base"* ]]; then
      install_basic_env "apt_packages.txt" "apt_packages.nice_to_have.txt"
    fi
    if [[ "$var" == *"--rust"* ]]; then
      install_rust
    fi

    if [[ "$var" == *"--node"* ]]; then
      install_pnpm_node
    fi
    if [[ "$var" == *"--speedtest"* ]]; then
      install_speedtest
    fi
    if [[ "$var" == *"--containers"* ]]; then
      install_containerization
    fi
    if [[ "$var" == *"--nice-to-have"* ]]; then
      install_nice_to_have
    fi
    if [[ "$var" == *"--it-admin"* ]]; then
      install_it_admin
    fi
    if [[ "$var" == *"--help"* ]]; then
      echo "Usage: $0 [ all ]
    --containers: Install microk8s and docker
    --rust: Install rust
    --node: Install pnpm and node
    --gui: Install GUI stuff like Brave and VSCode
    --speedtest: Install speedtest"
      exit 1
    fi
  done
}

# Curl is a dependency for everything so we'll just install it first.
sudo DEBIAN_FRONTEND=noninteractive apt install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq curl

if [[ "$1" == *"--all"* ]]; then
  add_repositories
  install_basic_env "apt_packages.txt" 
  install_nice_to_have "apt_packages.nice_to_have.txt"
  install_it_admin "apt_packages.it_admin.txt"
  install_containerization
  install_rust
  # install_pnpm_node
  install_speedtest
  install_vscode_ubuntu
  install_brave_ubuntu
  install_npm_packages
  add_completion_scripts
else
  check_options "$@"
fi

setup_aliases

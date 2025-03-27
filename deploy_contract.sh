#!/bin/bash

echo "Starting Counter Seismic contract deployment on devnet..."

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Catch errors in pipelines
set -u  # Treat unset variables as errors

cd

# Update system and install required dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential jq unzip software-properties-common

# Check and upgrade GLIBC if needed
REQUIRED_GLIBC="2.34"
CURRENT_GLIBC=$(ldd --version | head -n1 | awk '{print $NF}')

if dpkg --compare-versions "$CURRENT_GLIBC" ge "$REQUIRED_GLIBC"; then
    echo "GLIBC $CURRENT_GLIBC is already installed. Skipping upgrade."
else
    echo "Upgrading GLIBC to $REQUIRED_GLIBC..."
    wget http://ftp.gnu.org/gnu/libc/glibc-2.34.tar.gz
    tar -xvzf glibc-2.34.tar.gz
    cd glibc-2.34
    mkdir build && cd build
    ../configure --prefix=/opt/glibc-2.34
    make -j$(nproc)
    sudo make install
    export LD_LIBRARY_PATH=/opt/glibc-2.34/lib:$LD_LIBRARY_PATH
    echo 'export LD_LIBRARY_PATH=/opt/glibc-2.34/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
    source ~/.bashrc
    cd ~
fi

# Upgrade libstdc++ if needed
if ! strings /usr/lib/x86_64-linux-gnu/libstdc++.so.6 | grep -q "GLIBCXX_3.4.29"; then
    echo "Upgrading libstdc++..."
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
    sudo apt update
    sudo apt install -y gcc-11 g++-11
fi

# Install Rust
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed. Skipping installation."
fi

rustc --version

sleep 2

# Install sfoundryup
echo "Installing sfoundryup..."
curl -L -H "Accept: application/vnd.github.v3.raw" \
     "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash

sleep 2
export PATH="$HOME/.seismic/bin:$PATH"
echo 'export PATH="$HOME/.seismic/bin:$PATH"' >> ~/.bashrc

# Source bashrc safely
echo "Sourcing ~/.bashrc..."
set +u  # Temporarily disable unbound variable checking
source ~/.bashrc
set -u  # Re-enable it

echo "Running sfoundryup..."
sfoundryup

# Clone try-devnet repository with submodules
if [ ! -d "try-devnet" ]; then
    echo "Cloning try-devnet repository..."
    git clone --recurse-submodules https://github.com/SeismicSystems/try-devnet.git
else
    echo "try-devnet repository already exists. Pulling latest changes..."
    cd try-devnet
    git pull
    git submodule update --init --recursive
    cd ..
fi

# Navigate to contract directory and deploy
cd try-devnet/packages/contract/ || exit
echo "Deploying contract..."
bash script/deploy.sh

# Install Bun for CLI interaction
cd $HOME/try-devnet/packages/cli/
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

bun install

# Interact with an encrypted contract
bash script/transact.sh

echo "Deployment completed successfully!"

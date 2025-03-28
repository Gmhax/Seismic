#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Install Rust
echo "Installing Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"

# Install jq
echo "Installing jq..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install jq
else
    sudo apt-get update && sudo apt-get install -y jq
fi

# Install sfoundryup
echo "Installing sfoundryup..."
curl -L -H "Accept: application/vnd.github.v3.raw" \
     "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash

# Ensure environment variables are loaded
source ~/.bashrc
source ~/.profile
source ~/.seismic/env || true  # Load seismic env if it exists

# Run sfoundryup
echo "Running sfoundryup..."
~/.seismic/bin/sfoundryup

# Clone repository
echo "Cloning repository..."
git clone --recurse-submodules https://github.com/SeismicSystems/try-devnet.git
cd try-devnet/packages/contract/

# Deploy contract
echo "Deploying contract..."
bash script/deploy.sh

# Install Bun
echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Install node dependencies
echo "Installing node dependencies..."
cd ../cli/
bun install

# Send transactions
echo "Sending transactions..."
bash script/transact.sh

echo "Deployment and interaction completed successfully!"

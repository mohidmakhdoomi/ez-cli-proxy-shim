#!/bin/bash

shim_dir="$(pwd)/bin"
proxy_dir="$(pwd)"

home_profile="$HOME/.profile"

pathaddtofile_pre() {
    if [[ ":$PATH:" != *":$1:"* ]]; then
        echo "export PATH=\"$1:\$PATH\"" >> "$2"
    fi
}

pathaddtofile_post() {
    if [[ ":$PATH:" != *":$1:"* ]]; then
        echo "export PATH=\"\$PATH:$1\"" >> "$2"
    fi
}

# install Go and add to PATH
wget https://go.dev/dl/go1.26.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.26.5.linux-amd64.tar.gz
pathaddtofile_post "/usr/local/go/bin" "$home_profile" # (or can do /etc/profile)
source $home_profile
pathaddtofile_post "$(go env GOPATH)/bin" "$home_profile" # (or can do $HOME/.bashrc)
source $home_profile
rm go1.26.5.linux-amd64.tar.gz

# install CLIProxyAPI at the specific commit that I installed
mkdir -p "$proxy_dir" && cd "$proxy_dir" && sudo rm -rf ./CLIProxyAPI
git clone https://github.com/router-for-me/CLIProxyAPI.git && cd CLIProxyAPI
git checkout f71ec0eb6776854457892452cf28c47f0d658251 # can remove this line if you want the latest
go build -o cli-proxy-api ./cmd/server

# setup basic config file for CLIProxyAPI
mkdir -p $HOME/.cli-proxy-api/ && wget -O $HOME/.cli-proxy-api/config_1.yaml https://raw.githubusercontent.com/mohidmakhdoomi/ez-cli-proxy-shim/f0491c6271cd325251144bb8bfe85992a1fb67fe/config.yaml

# do Codex OAuth for CLIProxyAPI
./cli-proxy-api --config $HOME/.cli-proxy-api/config_1.yaml --codex-login

# schedule CLIProxyAPI startup at boot
cd "$proxy_dir"
crontab -l > mycron
echo "@reboot $proxy_dir/CLIProxyAPI/cli-proxy-api --config $HOME/.cli-proxy-api/config_1.yaml" >> mycron
crontab mycron
rm mycron

# setup Claude Code shim and add to PATH
mkdir -p "$shim_dir" && pathaddtofile_pre "$shim_dir" "$home_profile"
wget -O "$shim_dir/claude" https://raw.githubusercontent.com/mohidmakhdoomi/ez-cli-proxy-shim/f0491c6271cd325251144bb8bfe85992a1fb67fe/claude
chmod 755 "$shim_dir/claude"

# setup settings json for Claude Code shim to use CLIProxyAPI
mkdir -p "$HOME/.claude" && wget -O "$HOME/.claude/settings_cliproxyapi.json" https://raw.githubusercontent.com/mohidmakhdoomi/ez-cli-proxy-shim/f0491c6271cd325251144bb8bfe85992a1fb67fe/settings_proxy.json

echo "Done. Reboot to have CLIProxyAPI start up automatically."

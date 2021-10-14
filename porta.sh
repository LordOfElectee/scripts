#!/bin/bash

exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi
sleep 1 && curl -s https://api.nodes.guru/logo.sh | bash && sleep 3

function setupVars {
	if [ ! $PORTA_NODENAME ]; then
		read -p "Enter your node name: " PORTA_NODENAME_ORIGINAL
		echo 'export PORTA_NODENAME="'${PORTA_NODENAME_ORIGINAL}' | NodesGuru"' >> $HOME/.bash_profile
		echo 'export PORTA_NODENAME_ORIGINAL='${PORTA_NODENAME_ORIGINAL} >> $HOME/.bash_profile
	fi
	echo -e '\n\e[42mYour node name:' $PORTA_NODENAME_ORIGINAL '\e[0m\n'
	. $HOME/.bash_profile
	sleep 1
}

function setupSwap {
	echo -e '\n\e[42mSet up swapfile\e[0m\n'
	curl -s https://api.nodes.guru/swap4.sh | bash
}

function installRust {
	echo -e '\n\e[42mInstall Rust\e[0m\n' && sleep 1
	# sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
	curl https://getsubstrate.io -sSf | bash -s -- --fast 
	. $HOME/.cargo/env
}

function installDeps {
	echo -e '\n\e[42mPreparing to install\e[0m\n' && sleep 1
	cd $HOME
	sudo apt update
	sudo apt install make clang pkg-config libssl-dev build-essential git jq llvm libudev-dev -y < "/dev/null"
	installRust
}

function installSoftware {
	echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1
	cd $HOME
	git clone https://github.com/porta-network/porta-node.git
	cd porta-node
	cargo build --release
}

function updateSoftware {
	echo -e '\n\e[42mUpdate software\e[0m\n' && sleep 1
	sudo systemctl stop portad
	cd $HOME/porta-node
	git reset --hard
	git pull origin main
	cargo build --release
}

function installService {
echo -e '\n\e[42mRunning\e[0m\n' && sleep 1
echo -e '\n\e[42mCreating a service\e[0m\n' && sleep 1

sudo tee <<EOF >/dev/null $HOME/portad.service
[Unit]
Description=Porta Node
After=network-online.target
[Service]
User=$USER
ExecStart=$HOME/porta-node/target/release/porta --chain $HOME/porta-node/chain-spec-padlock.json -d $HOME/porta-node/MARSOHOT --name '${PORTA_NODENAME}' --validator --port 30337 --ws-port 9949 --rpc-port 9937 --ws-external --rpc-cors all --rpc-methods=unsafe
Restart=always
RestartSec=3
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/portad.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
sudo systemctl enable portad
sudo systemctl restart portad
echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service portad status | grep active` =~ "running" ]]; then
  echo -e "Your Porta node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice portad status\e[0m or \e[7mjournalctl -u portad -f\e[0m"
  # echo -e "Your node identity is: \e[7m" && journalctl -u portad | grep "Local node identity is: " | awk -F "[, ]+" '/Local node identity is: /{print $NF}' && echo -e "\e[0m"
  echo -e "Rotate your keys by the following command:"
  echo -e "\e[7mcurl -s -H \"Content-Type: application/json\" -d '{\"id\":1, \"jsonrpc\":\"2.0\", \"method\": \"author_rotateKeys\", \"params\":[]}' http://127.0.0.1:9937 | jq .result | sed 's/\"//g'\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your Porta node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
. $HOME/.bash_profile
}

function deletePorta {
	sudo systemctl disable portad
	sudo systemctl stop portad
}

PS3='Please enter your choice (input your option number and press enter): '
options=("Install" "Update" "Delete" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install")
            echo -e '\n\e[42mYou choose install...\e[0m\n' && sleep 1
			setupVars
			setupSwap
			installDeps
			installSoftware
			installService
			break
            ;;
        "Update")
            echo -e '\n\e[33mYou choose update...\e[0m\n' && sleep 1
			updateSoftware
			installService
			echo -e '\n\e[33mYour node was updated!\e[0m\n' && sleep 1
			break
            ;;
		"Delete")
            echo -e '\n\e[31mYou choose delete...\e[0m\n' && sleep 1
			deletePorta
			echo -e '\n\e[42mPorta was deleted!\e[0m\n' && sleep 1
			break
            ;;
        "Quit")
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done

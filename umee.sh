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
bash_profile=/mnt/nroot/.bash_profile
if [ -f "$bash_profile" ]; then
    . /mnt/nroot/.bash_profile
fi
sleep 1 && curl -s https://api.nodes.guru/logo.sh | bash && sleep 1

function setupVars {
	if [ ! $UMEE_NODENAME ]; then
		read -p "Enter node name: " UMEE_NODENAME
		echo 'export UMEE_NODENAME='\"${UMEE_NODENAME}\" >> /mnt/nroot/.bash_profile
	fi
	if [ ! $UMEE_WALLET ]; then
		read -p "Enter wallet name: " UMEE_WALLET
		echo 'export UMEE_WALLET='\"${UMEE_WALLET}\" >> /mnt/nroot/.bash_profile
	fi
	echo -e '\n\e[42mYour wallet name:' $UMEE_WALLET '\e[0m\n'
	echo 'export UMEE_CHAIN=umee-betanet-2' >> /mnt/nroot/.bash_profile
	. /mnt/nroot/.bash_profile
	sleep 1
}

function setupSwap {
	echo -e '\n\e[42mSet up swapfile\e[0m\n'
	curl -s https://api.nodes.guru/swap4.sh | bash
}

function installGo {
	echo -e '\n\e[42mInstall Go\e[0m\n' && sleep 1
	cd /mnt/nroot
	wget -O go1.16.5.linux-amd64.tar.gz https://golang.org/dl/go1.16.5.linux-amd64.tar.gz
	rm -rf /usr/local/go && tar -C /usr/local -xzf go1.16.5.linux-amd64.tar.gz && rm go1.16.5.linux-amd64.tar.gz
	echo 'export GOROOT=/usr/local/go' >> /mnt/nroot/.bash_profile
	echo 'export GOPATH=/mnt/nroot/go' >> /mnt/nroot/.bash_profile
	echo 'export GO111MODULE=on' >> /mnt/nroot/.bash_profile
	echo 'export PATH=$PATH:/usr/local/go/bin:/mnt/nroot/go/bin' >> /mnt/nroot/.bash_profile && . /mnt/nroot/.bash_profile
	go version
}

function installDeps {
	echo -e '\n\e[42mPreparing to install\e[0m\n' && sleep 1
	cd /mnt/nroot
	sudo apt update
	sudo apt install make clang pkg-config libssl-dev build-essential git jq ncdu -y < "/dev/null"
	installGo
}

function installCosmovisor {
	echo -e '\n\e[42mInstall Cosmovisor\e[0m\n' && sleep 1
	cd /mnt/nroot
	go get github.com/cosmos/cosmos-sdk/cosmovisor/cmd/cosmovisor
	useradd --no-create-home --shell /bin/false cosmovisor
	mkdir /mnt/nroot/cosmovisor
	mkdir -p /mnt/nroot/cosmovisor/genesis/bin
	cp $(which umeed) /mnt/nroot/cosmovisor/genesis/bin
	cp $(which cosmovisor) /mnt/nroot/cosmovisor
	chown -R cosmovisor:cosmovisor /mnt/nroot/cosmovisor
}

function installOrchestrator {
echo -e '\n\e[42mInstall Orchestrator\e[0m\n' && sleep 1
mv /mnt/nroot/gorc /mnt/nroot/.gorc.bak
wget -O gorc https://github.com/PeggyJV/gravity-bridge/releases/download/v0.2.10/gorc
chmod +x ./gorc
mv ./gorc /usr/local/bin
mkdir /mnt/nroot/gorc && cd /mnt/nroot/gorc
cp -r /mnt/nroot/.gorc.bak/keystore /mnt/nroot/gorc
contract_address="0xc846512f680a2161D2293dB04cbd6C294c5cFfA7"
echo "keystore = \"/mnt/nroot/gorc/keystore/\"

[gravity]
contract = \"$contract_address\"
fees_denom = \"uumee\"

[ethereum]
key_derivation_path = \"m/44'/60'/0'/0/0\"
rpc = \"https://rinkeby.nodes.guru:443\"
gas_price_multiplier = 1.0

[cosmos]
key_derivation_path = \"m/44'/118'/0'/0/0\"
grpc = \"http://localhost:9090\"
prefix = \"umee\"

[cosmos.gas_price]
amount = 0.00001
denom = \"uumee\"

[metrics]
listen_addr = \"127.0.0.1:3000\"
" > /mnt/nroot/gorc/config.toml
}

function generateKeysOrchestrator {
echo -e "[Orchestrator] Set up your \e[7mcosmos\e[0m wallet"
gorc --config /mnt/nroot/gorc/config.toml keys cosmos add "$UMEE_WALLET"_cosmos > /mnt/nroot/umee_"$UMEE_WALLET"_cosmos_key.txt
echo -e "[Orchestrator] You can get your mnemonic via \e[7mcat /mnt/nroot/umee_"$UMEE_WALLET"_cosmos_key.txt\e[0m"
cat /mnt/nroot/umee_"$UMEE_WALLET"_cosmos_key.txt | head -n 1
echo -e "[Orchestrator] Set up your \e[7meth\e[0m wallet"
gorc --config /mnt/nroot/gorc/config.toml keys eth add "$UMEE_WALLET"_eth > /mnt/nroot/umee_"$UMEE_WALLET"_eth_key.txt
echo -e "[Orchestrator] You can get your mnemonic via \e[7mcat /mnt/nroot/umee_"$UMEE_WALLET"_eth_key.txt\e[0m"
cat /mnt/nroot/umee_"$UMEE_WALLET"_eth_key.txt | head -n 1
eth_addr=`cat /mnt/nroot/umee_"$UMEE_WALLET"_eth_key.txt | tail -1`
echo -e "[Orchestrator] You should send some Rinkeby ETH to the wallet address: \e[7m$eth_addr\e[0m"
echo -e "[Orchestrator] You can do it via: \e[7mhttps://faucet.rinkeby.io/\e[0m"
}

function createServiceOrchestrator {
echo "[Unit]
Description=Gravity Bridge Orchestrator
After=online.target

[Service]
#Type=root
User=$USER
Environment=\"RUST_LOG=INFO\"
ExecStart=/usr/local/bin/gorc --config /mnt/nroot/gorc/config.toml orchestrator start --cosmos-key "$UMEE_WALLET"_cosmos --ethereum-key "$UMEE_WALLET"_eth
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/gorc.service
systemctl daemon-reload
systemctl enable gorc
systemctl restart gorc
}

function installGeth {
echo -e '\n\e[42mInstall Ethereum Node (light)\e[0m\n' && sleep 1
cd /mnt/nroot
wget -O /mnt/nroot/geth.tar.gz https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.8-26675454.tar.gz
tar -xzf geth.tar.gz
cp /mnt/nroot/geth-linux-amd64-1.10.8-26675454/geth /usr/bin
rm geth.tar.gz
}

function createServiceGeth {
cd /mnt/nroot
wget https://www.rinkeby.io/rinkeby.json
geth init rinkeby.json
#ExecStart=/usr/bin/geth --syncmode \"light\" --goerli --rpc --rpcport \"8545\"
#ExecStart=/usr/bin/geth --syncmode \"light\"  --http --http.addr=0.0.0.0 --http.port=8545 --cache=16 --ethash.cachesinmem=1 --rinkeby --v5disc --bootnodes=enode://a24ac7c5484ef4ed0c5eb2d36620ba4e4aa13b8c84684e1b4aab0cebea2ae45cb4d375b77eab56516d34bfbd3c1a833fc51296ff084b770b94fb9028c4d25ccf@52.169.42.101:30303
#ExecStart=/usr/bin/geth --syncmode \"light\"  --http --http.addr=0.0.0.0 --http.port=8545 --cache=16 --ethash.cachesinmem=1 --rinkeby --v5disc --bootnodes=enode://343149e4feefa15d882d9fe4ac7d88f885bd05ebb735e547f12e12080a9fa07c8014ca6fd7f373123488102fe5e34111f8509cf0b7de3f5b44339c9f25e87cb8@52.3.158.184:30303
echo "[Unit]
Description=Geth node
After=online.target

[Service]
#Type=root
User=$USER
ExecStart=/usr/bin/geth --syncmode \"light\" --http --http.addr=0.0.0.0 --http.port=8545 --rinkeby --bootnodes=enode://a24ac7c5484ef4ed0c5eb2d36620ba4e4aa13b8c84684e1b4aab0cebea2ae45cb4d375b77eab56516d34bfbd3c1a833fc51296ff084b770b94fb9028c4d25ccf@52.169.42.101:30303
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/geth.service
systemctl daemon-reload
systemctl enable geth
systemctl restart geth
}

function installSoftware {
	echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1
	cd /mnt/nroot
	git clone --depth 1 --branch v0.2.0 https://github.com/umee-network/umee.git
	cd umee && make install
	umeed version
	umeed init ${UMEE_NODENAME} --chain-id $UMEE_CHAIN
	wget -O /mnt/nroot/.umee/config/genesis.json "https://raw.githubusercontent.com/umee-network/umee/main/networks/$UMEE_CHAIN/genesis.json"
	# sed -i.bak -e "s/^minimum-gas-prices = \"\"/minimum-gas-prices = \"0.001uumee\"/; s/^pruning = \"default\"/pruning = \"nothing\"/" /mnt/nroot/.umee/config/app.toml
	# sed -i.bak -e "s/^pruning = \"default\"/pruning = \"nothing\"/" /mnt/nroot/.umee/config/app.toml
	sed -i '/\[grpc\]/{:a;n;/enabled/s/false/true/;Ta};/\[api\]/{:a;n;/enable/s/false/true/;Ta;}' /mnt/nroot/.umee/config/app.toml
	external_address=`curl ifconfig.me`
	peers="484eaf45fa5f9a6a57fad1e56a1a41e0f69a5c3e@65.21.156.69:26656,a9a84866786013f75138388fbf12cdfc425bd39c@137.184.69.184:26656,684dd9ce7746041d0453322808cc5b238861e386@137.184.65.210:26656,c4c425c66d2941ce4d5d98185aa90d2330de5efd@143.244.166.155:26656,eb42bdbd821fad7bd0048a741237625b4d954d18@143.244.165.138:26656"
	sed -i.bak -e "s/^external_address = \"\"/external_address = \"$external_address:26656\"/; s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" /mnt/nroot/.umee/config/config.toml
	wget -O /mnt/nroot/.umee/config/addrbook.json https://api.nodes.guru/umee_addrbook.json
	installCosmovisor
	installGeth
	createServiceGeth
	installOrchestrator
	generateKeysOrchestrator
	createServiceOrchestrator
}

function updateSoftware {
	echo -e '\n\e[42mUpdate software\e[0m\n' && sleep 1
	systemctl stop gorc geth umeed
	umeed unsafe-reset-all
	cd /mnt/nroot
	rm -r /mnt/nroot/umee
	git clone --depth 1 --branch v0.2.0 https://github.com/umee-network/umee.git
	cd umee && make install
	umeed version
	rm /mnt/nroot/.umee/config/genesis.json
	umeed init ${UMEE_NODENAME} --chain-id $UMEE_CHAIN
	wget -O /mnt/nroot/.umee/config/genesis.json "https://raw.githubusercontent.com/umee-network/umee/main/networks/$UMEE_CHAIN/genesis.json"
	peers="a9a84866786013f75138388fbf12cdfc425bd39c@137.184.69.184:26656,684dd9ce7746041d0453322808cc5b238861e386@137.184.65.210:26656,c4c425c66d2941ce4d5d98185aa90d2330de5efd@143.244.166.155:26656,eb42bdbd821fad7bd0048a741237625b4d954d18@143.244.165.138:26656"
	sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" /mnt/nroot/.umee/config/config.toml
	# wget -O /mnt/nroot/.umee/config/addrbook.json https://api.nodes.guru/umee_addrbook.json
	# cd /mnt/nroot/umee
	# git reset --hard
	# git pull origin main
	# make install
	
	# createServiceGeth
	installOrchestrator
	systemctl restart umeed
}

function installService {
echo -e '\n\e[42mRunning\e[0m\n' && sleep 1
echo -e '\n\e[42mCreating a service\e[0m\n' && sleep 1

echo "[Unit]
Description=Cosmovisor Process Manager
After=network.target

[Service]
User=$USER
Group=root
Type=simple
Environment=\"DAEMON_NAME=umeed\"
Environment=\"DAEMON_HOME=/mnt/nroot\"
Environment=\"DAEMON_RESTART_AFTER_UPGRADE=true\"
#Environment=\"DAEMON_ALLOW_DOWNLOAD_BINARIES=true\"
Environment=\"UNSAFE_SKIP_BACKUP=false\"
ExecStart=/mnt/nroot/cosmovisor/cosmovisor start
Restart=on-failure
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target" > /mnt/nroot/umeed.service
sudo mv /mnt/nroot/umeed.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
sudo systemctl enable umeed
sudo systemctl restart umeed
echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service umeed status | grep active` =~ "running" ]]; then
  echo -e "Your Umee node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice umeed status\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your Umee node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
. /mnt/nroot/.bash_profile
}

function disableUmeed {
	sudo systemctl disable umeed
	sudo systemctl stop umeed
}

PS3='Please enter your choice (input your option number and press enter): '
options=("Install" "Update" "Disable" "Quit")
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
			setupVars
			updateSoftware
			echo -e '\n\e[33mYour node was updated!\e[0m\n' && sleep 1
			break
            ;;
		"Disable")
            echo -e '\n\e[31mYou choose disable...\e[0m\n' && sleep 1
			disableUmeed
			echo -e '\n\e[42mUmeed was disabled!\e[0m\n' && sleep 1
			break
            ;;
        "Quit")
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done

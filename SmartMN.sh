#/bin/bash
NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
BLUE='\033[01;34m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
MAX=11

COINGITHUB=https://github.com/Stim-Community/stim.git
COINPATH=usr/local/bin
COINSRCDIR=Stim
# P2Pport and RPCport can be found in chainparams.cpp -> CMainParams()
COINPORT=8093
COINRPCPORT=8091
COINDAEMON=stimd
COINCLI=stim-cli
# COINCORE can be found in util.cpp -> GetDefaultDataDir()
COINCORE=root/.stimcore
COINCONFIG=stim.conf
key=""

checkForUbuntuVersion() {
   echo "[1/${MAX}] Checking Ubuntu version..."
    if [[ `cat /etc/issue.net`  == *16.04* ]]; then
        echo -e "${GREEN}* You are running `cat /etc/issue.net` . Setup will continue.${NONE}";
    else
        echo -e "${RED}* You are not running Ubuntu 16.04.X. You are running `cat /etc/issue.net` ${NONE}";
        echo && echo "Installation cancelled" && echo;
        exit;
    fi
}

updateAndUpgrade() {
    echo
    echo "[2/${MAX}] Runing update and upgrade. Please wait..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -y > /dev/null 2>&1
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1
    echo -e "${GREEN}* Completed${NONE}";
}

setupSwap() {
    echo -e "${BOLD}"
    read -e -p "Add swap space? (If you use a 1G RAM VPS, choose Y.) [Y/n] :" add_swap
    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        swap_size="3G"
    else
        echo -e "${NONE}[3/${MAX}] Swap space not created."
    fi

    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        echo && echo -e "${NONE}[3/${MAX}] Adding swap space...${YELLOW}"
        sudo fallocate -l $swap_size /swapfile
        sleep 2
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null 2>&1
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo -e "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Completed${NONE}";
    fi
}

installFail2Ban() {
    echo -e "${BOLD}"
    read -e -p "Install Fail2Ban? (This is just a safety program, optional.) [Y/n] :" install_F2B
    if [[ ("$install_F2B" == "y" || "$install_F2B" == "Y" || "$install_F2B" == "") ]]; then
        echo -e "[4/${MAX}] Installing fail2ban. Please wait..."
        sudo apt-get -y install fail2ban > /dev/null 2>&1
        sudo systemctl enable fail2ban > /dev/null 2>&1
        sudo systemctl start fail2ban > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Completed${NONE}";
    else
        echo -e "${NONE}[4/${MAX}] Fail2Ban not installed."
    fi
}

installFirewall() {
    echo -e "${BOLD}"
    read -e -p "Install Firewall? (This is just for safety, optional.) [Y/n] :" install_FW
    if [[ ("$install_FW" == "y" || "$install_FW" == "Y" || "$install_FW" == "") ]]; then
        echo -e "[5/${MAX}] Installing UFW. Please wait..."
        sudo apt-get -y install ufw > /dev/null 2>&1
        sudo ufw default deny incoming > /dev/null 2>&1
        sudo ufw default allow outgoing > /dev/null 2>&1
        sudo ufw allow ssh > /dev/null 2>&1
        sudo ufw limit ssh/tcp > /dev/null 2>&1
        sudo ufw allow $COINPORT/tcp > /dev/null 2>&1
        sudo ufw allow $COINRPCPORT/tcp > /dev/null 2>&1
        sudo ufw logging on > /dev/null 2>&1
        echo "y" | sudo ufw enable > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Completed${NONE}";
    else
        echo -e "${NONE}[5/${MAX}] Firewall not installed."
    fi
}

installDependencies() {
    echo
    echo -e "[6/${MAX}] Installing dependecies. Please wait..."
    sudo apt-get install git nano rpl wget python-virtualenv -qq -y > /dev/null 2>&1
    sudo apt-get install build-essential libtool automake autoconf -qq -y > /dev/null 2>&1
    sudo apt-get install autotools-dev autoconf pkg-config libssl-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libgmp3-dev libevent-dev bsdmainutils libboost-all-dev -qq -y > /dev/null 2>&1
    sudo apt-get install software-properties-common python-software-properties -qq -y > /dev/null 2>&1
    sudo add-apt-repository ppa:bitcoin/bitcoin -y > /dev/null 2>&1
    sudo apt-get update -qq -y > /dev/null 2>&1
    sudo apt-get install libdb4.8-dev libdb4.8++-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libminiupnpc-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libzmq5 -qq -y > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Completed${NONE}";
}

compileWallet() {
    echo
    echo -e "[7/${MAX}] Compiling wallet. Please wait..."
    git clone $COINGITHUB $COINSRCDIR > /dev/null 2>&1
    cd $COINSRCDIR > /dev/null 2>&1
    chmod 755 autogen.sh > /dev/null 2>&1
    chmod 755 configure > /dev/null 2>&1
    sudo ./autogen.sh > /dev/null 2>&1
    sudo ./configure > /dev/null 2>&1
    chmod 755 share/genbuild.sh > /dev/null 2>&1
    make > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Completed${NONE}";
}

installWallet() {
    echo
    echo -e "[8/${MAX}] Installing wallet. Please wait..."
    cd /root/$COINSRCDIR/src
    strip $COINDAEMON
    echo -e "${NONE}${GREEN}* Completed${NONE}";
}

configureWallet() {
    echo
    echo -e "[9/${MAX}] Configuring wallet. Please wait..."
    sudo mkdir -p /root/$COINCORE
    sudo touch /root/$COINCORE/$COINCONFIG
    sleep 10

    mnip=$(curl --silent ipinfo.io/ip)
    rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rpcpass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    mnkey=$key

    sleep 10

    echo -e "rpcuser=${rpcuser}\nrpcpassword=${rpcpass}\nrpcallowip=127.0.0.1\nlisten=1\nserver=1\ndaemon=1\nstaking=0\nmaxconnections=64\nlogtimestamps=1\nexternalip=${mnip}:${COINPORT}\nmasternode=1\nmasternodeprivkey=${mnkey}" > /root/$COINCORE/$COINCONFIG
    echo -e "${NONE}${GREEN}* Completed${NONE}";
}

configure_systemd() {
    echo
    echo -e "[10/${MAX}] Configuring systemd..."
    cat `EOF > /etc/systemd/system/$COINSRCDIR.service`
    [Unit]
    Description=$COINSRCDIR service
    After=network.target

    [Service]
    User=root
    Group=root

    Type=forking
    #PIDFile=$COINCORE/$COINSRCDIR.pid

    ExecStart=$COINPATH$COINDAEMON -daemon -conf=$COINCORE/$COINCONFIG -datadir=$COINCORE
    ExecStop=-$COINPATH$COINCLI -conf=$COINCORE/$COINCONFIG -datadir=$COINCONFIG stop

    Restart=always
    PrivateTmp=true
    TimeoutStopSec=60s
    TimeoutStartSec=10s
    StartLimitInterval=120s
    StartLimitBurst=5

    [Install]
    WantedBy=multi-user.target
    EOF

      systemctl daemon-reload
      sleep 3
      systemctl start $COINSRCDIR.service
      systemctl enable $COINSRCDIR.service >/dev/null 2>&1

      if [[ -z "$(ps axo cmd:100 | egrep $COINDAEMON)" ]]; then
         echo -e "${RED}$COINSRCDIR is not running${NC}, please investigate. You should start by running the following commands as root:"
         echo -e "${GREEN}systemctl start $COINSRCDIR.service"
         echo -e "systemctl status $COINSRCDIR.service"
         echo -e "less /var/log/syslog${NC}"
         exit 1
       fi
    echo -e "${NONE}${GREEN}* Completed${NONE}";
}



startWallet() {
    echo
    echo -e "[11/${MAX}] Starting wallet daemon..."
    cd /root/$COINSRCDIR/src
    sudo ./$COINDAEMON -daemon > /dev/null 2>&1
    sleep 5
    echo -e "${GREEN}* Completed${NONE}";
}

clear
cd



echo -e "${BOLD}"
read -p "This script will setup your Stim Masternode. Do you wish to continue? (y/n)?" response
echo -e "${NONE}"

if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h) : " key
    if [[ "$key" == "" ]]; then
        echo "WARNING: No private key entered, exiting!!!"
        echo && exit
    fi
    checkForUbuntuVersion
    updateAndUpgrade
    setupSwap
    installFail2Ban
    installFirewall
    installDependencies
    compileWallet
    installWallet
    configureWallet
    startWallet
    echo
    echo -e "${BOLD}The VPS side of your masternode has been installed. Use the following line in your cold wallet masternode.conf and replace the tx and index${NONE}".
    echo
    echo -e "${CYAN}masternode1 ${mnip}:${COINPORT} ${mnkey} tx index${NONE}"
    echo
    echo -e "${BOLD}Thank you for your support of Salen Coin.${NONE}"
    echo
else
    echo && echo "Installation cancelled" && echo
fi

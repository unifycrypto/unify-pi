#!/bin/bash
#NEBL-Pi Installer v1.0 for UNIFY Core v2.1.1

echo "================================================================================"
echo "=================== Welcome to the Official NEBL-Pi Installer =================="
echo "This script will install all necessary dependencies to run or compile UNIFYd"
echo "and/or UNIFY-qt, download the binaries or source code, and then optionally"
echo "compile UNIFYd, UNIFY-qt or both. UNIFYd and/or UNIFY-qt will be copied to"
echo "your Desktop when done."
echo ""
echo "Note that even on a new Raspberry Pi 3, the compile process can take 30 minutes"
echo "or more for UNIFYd and over 45 minutes for UNIFY-qt."
echo ""
echo "Pass -c to compile from source"
echo "Pass -d to install UNIFYd"
echo "Pass -q to install UNIFY-qt"
echo "Pass -dq to install both"
echo "Pass -x to disable QuickSync"
echo ""
echo "You can safely ignore all warnings during the compilation process, but if you"
echo "run into any errors, please report them to info@nebl.io"
echo "================================================================================"

USAGE="$0 [-d | -q | -c | -dqc]"

UNIFYDIR=~/neblpi-source
DEST_DIR=~/Desktop/
UNIFYD=false
UNIFYQT=false
COMPILE=false
JESSIE=false
QUICKSYNC=true

# check if we have a Desktop, if not, use home dir
if [ ! -d "$DEST_DIR" ]; then
    DEST_DIR=~/
fi

# create ~/.UNIFY if it does not exist
mkdir -p ~/.UNIFY

# check if we are running on Raspbian Jessie
if grep -q jessie "/etc/os-release"; then
    echo ""
    echo "================================================================================"
    echo "====================== Raspbian Jessie (Outdated) Detected ====================="
    echo ""
    echo "This install script is only compatible with Raspbian Stretch."
    echo "Please upgrade to Raspbian Stretch (take a backup first!)"
    echo ""
    echo "In 30 seconds this we will open a webpage detailing how to upgrade."
    echo ""
    echo "================================================================================"
    sleep 30
    python -mwebbrowser https://www.raspberrypi.org/documentation/raspbian/updating.md
    exit
fi

while getopts ':dqcx' opt
do
    case $opt in
        c) echo "Will compile all from source"
           COMPILE=true;;
        d) echo "Will Install UNIFYd"
	       UNIFYD=true;;
        q) echo "Will Install UNIFY-qt"
	       UNIFYQT=true;;
	    x) echo "Disabling Quick Sync and using traditional sync"
           QUICKSYNC=false;;
        \?) echo "ERROR: Invalid option: $USAGE"
            echo "-c            Compile all from source"
            echo "-d            Install UNIFYd (default false)"
            echo "-q            Install UNIFY-qt (default false)"
            echo "-dq           Install both"
            echo "-x            Disable QuickSync"
        exit 1;;
    esac
done

# get sudo
if [ "$COMPILE" = true ]; then
    sudo whoami
fi

if [ "$QUICKSYNC" = true ]; then
    echo "Will use QuickSync"
fi

# update and install dependencies
sudo apt-get update -y
if [ "$COMPILE" = true ]; then
    sudo apt-get install build-essential -y
    sudo apt-get install libboost-all-dev -y
    sudo apt-get install libdb++-dev -y
    sudo apt-get install libminiupnpc-dev -y
    sudo apt-get install libqrencode-dev -y
    sudo apt-get install libldap2-dev -y
    sudo apt-get install libidn11-dev -y
    sudo apt-get install librtmp-dev -y
    sudo apt-get install libcurl4-openssl-dev -y
    sudo apt-get install git -y
    if [ "$UNIFYQT" = true ]; then
        sudo apt-get install qt5-default -y
        sudo apt-get install qt5-qmake -y
        sudo apt-get install qtbase5-dev-tools -y
        sudo apt-get install qttools5-dev-tools -y
    fi
fi

if [ "$COMPILE" = true ]; then
    # delete our src folder and then remake it
    sudo rm -rf $UNIFYDIR
    mkdir $UNIFYDIR
    cd $UNIFYDIR

    # clone our repo, then create some necessary directories
    git clone -b master https://github.com/UNIFYTeam/UNIFY

    python UNIFY/build_scripts/CompileOpenSSL-Linux.py
    python UNIFY/build_scripts/CompileCurl-Linux.py
    export OPENSSL_INCLUDE_PATH=$UNIFYDIR/openssl_build/include/
    export OPENSSL_LIB_PATH=$UNIFYDIR/openssl_build/lib/
    export PKG_CONFIG_PATH=$UNIFYDIR/curl_build/lib/pkgconfig/
    cd UNIFY/wallet
fi

# start our build
if [ "$UNIFYD" = true ]; then
    if [ "$COMPILE" = true ]; then
        make "STATIC=1" -B -w -f makefile.unix
        strip UNIFYd
        cp ./UNIFYd $DEST_DIR
    else
        cd $DEST_DIR
        wget https://github.com/UNIFYTeam/UNIFY/releases/download/v2.1.1/2019-06-08---v2.1.1-7c49f0e---UNIFYd---RPi-raspbian-stretch.tar.gz
        tar -xvf 2019-06-08---v2.1.1-7c49f0e---UNIFYd---RPi-raspbian-stretch.tar.gz
        rm 2019-06-08---v2.1.1-7c49f0e---UNIFYd---RPi-raspbian-stretch.tar.gz
        sudo chmod 775 UNIFYd
    fi
    if [ ! -f ~/.UNIFY/UNIFY.conf ]; then
        echo rpcuser=$USER >> ~/.UNIFY/UNIFY.conf
        RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        echo rpcpassword=$RPCPASSWORD >> ~/.UNIFY/UNIFY.conf
        echo rpcallowip=127.0.0.1 >> ~/.UNIFY/UNIFY.conf
    fi
fi
cd ..
if [ "$UNIFYQT" = true ]; then
    if [ "$COMPILE" = true ]; then
        wget 'https://fukuchi.org/works/qrencode/qrencode-3.4.4.tar.bz2'
        tar -xvf qrencode-3.4.4.tar.bz2
        cd qrencode-3.4.4/
        ./configure --enable-static --disable-shared --without-tools --disable-dependency-tracking
        sudo make install
        cd ..
        qmake "USE_UPNP=1" "USE_QRCODE=1" "RELEASE=1" \
        "OPENSSL_INCLUDE_PATH=$UNIFYDIR/openssl_build/include/" \
        "OPENSSL_LIB_PATH=$UNIFYDIR/openssl_build/lib/" \
        "PKG_CONFIG_PATH=$UNIFYDIR/curl_build/lib/pkgconfig/" UNIFY-wallet.pro
        make -B -w
        cp ./wallet/UNIFY-qt $DEST_DIR
    else
        cd $DEST_DIR
        wget https://github.com/UNIFYTeam/UNIFY/releases/download/v2.1.1/2019-06-08---v2.1.1-7c49f0e---UNIFY-Qt---RPi-raspbian-stretch.tar.gz
        tar -xvf 2019-06-08---v2.1.1-7c49f0e---UNIFY-Qt---RPi-raspbian-stretch.tar.gz
        rm 2019-06-08---v2.1.1-7c49f0e---UNIFY-Qt---RPi-raspbian-stretch.tar.gz
        sudo chmod 775 UNIFY-qt
    fi
fi

if [ "$QUICKSYNC" = true ]; then
    echo "Downloading files for QuickSync"
    sudo apt-get install wget curl jq -y
    mkdir -p $HOME/.UNIFY
    mkdir -p $HOME/.UNIFY/txlmdb
    cd $HOME/.UNIFY/txlmdb
    # grab our JSON data
    RAND=$((RANDOM % 2))
    LOCK_FILE=$(curl -s https://raw.githubusercontent.com/UNIFYTeam/UNIFY-quicksync/master/download.json | jq -r --argjson jq_rand $RAND '.[0].files[0].url[$jq_rand]')
    DATA_FILE=$(curl -s https://raw.githubusercontent.com/UNIFYTeam/UNIFY-quicksync/master/download.json | jq -r --argjson jq_rand $RAND '.[0].files[1].url[$jq_rand]')

    LOCK_SHA256=$(curl -s https://raw.githubusercontent.com/UNIFYTeam/UNIFY-quicksync/master/download.json | jq -r '.[0].files[0].sha256sum')
    DATA_SHA256=$(curl -s https://raw.githubusercontent.com/UNIFYTeam/UNIFY-quicksync/master/download.json | jq -r '.[0].files[1].sha256sum')

    # download lock file
    mv lock.mdb lock.mdb.bak
    while [ 1 ]; do
        wget -O lock.mdb --no-dns-cache --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 --continue $LOCK_FILE
        if [ $? = 0 ]; then
            mv lock.mdb lock.mdb.sha # rename file just for SHA256 testing
            echo "lock.mdb download complete, calculating SHA256"
            DOWNLOAD_LOCK_SHA256=$(sha256sum lock.mdb.sha |cut -f 1 -d " ")
            if [ "$LOCK_SHA256" = "$DOWNLOAD_LOCK_SHA256" ]; then
                mv lock.mdb.sha lock.mdb # SHA256 success, move back
                break
            fi
        fi # check return value, then check sha256, break if successful (0)
        sleep 1s;
    done;
    rm lock.mdb.bak

    # download data file
    mv data.mdb data.mdb.bak
    while [ 1 ]; do
        wget -O data.mdb --no-dns-cache --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 --continue $DATA_FILE
        if [ $? = 0 ]; then
            mv data.mdb data.mdb.sha # rename file just for SHA256 testing
            echo "data.mdb download complete, calculating SHA256"
            DOWNLOAD_DATA_SHA256=$(sha256sum data.mdb.sha |cut -f 1 -d " ")
            if [ "$DATA_SHA256" = "$DOWNLOAD_DATA_SHA256" ]; then
                mv data.mdb.sha data.mdb # SHA256 success, move back
                break
            fi
        fi # check return value, then check sha256, break if successful (0)
        sleep 1s;
    done;
    rm data.mdb.bak

    # set permissions
    sudo chown ${USER}:${USER} -R $HOME/.UNIFY
fi

if [ "$UNIFYQT" = true ]; then
    if [ -d ~/Desktop ]; then
        echo ""
        echo "Starting UNIFY-qt"
        sleep 5
        nohup $DEST_DIR/UNIFY-qt > /dev/null &
        sleep 5
    fi
fi

echo ""
echo "================================================================================"
echo "========================== NEBL-Pi Installer Finished =========================="
echo ""
echo "If there were no errors during download or compilation UNIFYd and/or UNIFY-qt"
echo "should now be on your desktop (if you are using a CLI-only version of Raspbian"
echo "without a desktop the binaries have been copied to your home directory instead)."
echo "Enjoy!"
echo ""
echo "================================================================================"
read -rsn1 -p"Press any key to close this window";echo

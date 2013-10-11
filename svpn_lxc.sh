#!/bin/sh
# this script uses lxc to run multiple instances of SocialVPN
# this script is designed for Ubuntu 12.04 (64-bit)
#
# usage: svpn_lxc.sh username password host 1 10 30 svpn"

USERNAME=$1
PASSWORD=$2
XMPP_HOST=$3
CONTAINER_START=${4:-0}
CONTAINER_END=${5:-2}
WAIT_TIME=${6:-30}
CONTROLLER_GIT_REPO=${7:-https://github.com/ipop-project/ipop-scripts.git}
CONTROLLER_GIT_BRANCH=${8:-master}
HOST=$(hostname)
CONTROLLER=svpn_controller.py
START_PATH=container/rootfs/home/ubuntu/start.sh

sudo apt-get update
sudo apt-get install -y lxc tcpdump git

wget -O ubuntu.tgz http://goo.gl/Ze7hYz
wget -O container.tgz http://goo.gl/XJgdtf
wget -O svpn.tgz http://goo.gl/Sg4Vh2
git clone --depth 1 --branch $CONTROLLER_GIT_BRANCH $CONTROLLER_GIT_REPO \
    controller-git

sudo tar xzf ubuntu.tgz; tar xzf container.tgz; tar xzf svpn.tgz
sudo cp -a ubuntu/* container/rootfs/
sudo mv container/home/ubuntu container/rootfs/home/ubuntu/
mv svpn container/rootfs/home/ubuntu/svpn/
cp controller-git/src/svpn_controller.py container/rootfs/home/ubuntu/svpn/

cat > container/rootfs/home/ubuntu/svpn/config.json <<EOF
{
    "stun": ["stun.l.google.com:19302"],
    "turn": []
}
EOF

cat > $START_PATH << EOF
#!/bin/bash
SVPN_HOME=/home/ubuntu/svpn
CONFIG=\`cat \$SVPN_HOME/config\`
\$SVPN_HOME/svpn-jingle &> \$SVPN_HOME/svpn_log.txt &
python \$SVPN_HOME/$CONTROLLER \$CONFIG -c \$SVPN_HOME/config.json &> \
    \$SVPN_HOME/controller_log.txt &
EOF

chmod 755 $START_PATH

sudo tcpdump -i lxcbr0 -w dump_$HOST.cap &> /dev/null &

for i in $(seq $CONTAINER_START $CONTAINER_END)
do
    container_name=container$i
    lxc_path=/var/lib/lxc
    container_path=$lxc_path/$container_name

    sudo cp -a container $container_name

    echo -n "$USERNAME $PASSWORD $XMPP_HOST" > \
         $container_name/rootfs/home/ubuntu/svpn/config

    sudo mv $container_name $lxc_path
    sudo echo "lxc.rootfs = $container_path/rootfs" >> $container_path/config
    sudo echo "lxc.mount = $container_path/fstab" >> $container_path/config
    sudo lxc-start -n $container_name -d
    sleep $WAIT_TIME
done


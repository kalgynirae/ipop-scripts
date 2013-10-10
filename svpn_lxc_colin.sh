#!/bin/sh

XMPP_USERNAME=$1
XMPP_PASSWORD=$2
XMPP_HOST=$3
CONTAINER_START=${4:-0}
CONTAINER_END=${5:-3}
WAIT_TIME=${6:-30}
HOST=$(hostname)
IP_PREFIX="172.16.5"
BASE=container/rootfs/home/ubuntu
VIRTUAL_BASE=/home/ubuntu/socialvpn
LXC_PATH=/var/lib/lxc

# Install necessary packages
sudo apt-get update
sudo apt-get install -y lxc tcpdump git

# Set up the container
wget -O ubuntu.tgz http://goo.gl/Ze7hYz
wget -O container.tgz http://goo.gl/XJgdtf
wget -O svpn.tgz http://goo.gl/Sg4Vh2
tar xf ubuntu.tgz
tar xf container.tgz
tar xf svpn.tgz
#rmdir container/rootfs  # Dunno if this is needed
mv -a ubuntu container/rootfs
mv container/home/ubuntu $BASE
mv svpn/svpn-jingle $BASE

# Fetch latest socialvpn
git clone --depth 1 --branch $GIT_BRANCH $GIT_REPO \
    $BASE/socialvpn

cat > $BASE/config.json <<EOF
{
    "stun": ["stun.l.google.com:19302"],
    "turn": []
}
EOF

sudo tcpdump -i lxcbr0 -w dump_$HOST.cap &> /dev/null &

for i in $(seq $CONTAINER_START $CONTAINER_END)
do
    container_name=container$i
    container_path=$LXC_PATH/$container_name
    sudo cp -a container $container_name


    cat > $BASE/start.sh <<EOF
#!/bin/sh
$VIRTUAL_BASE/svpn-jingle &> $VIRTUAL_BASE/svpn_log.txt &
python $VIRTUAL_BASE/socialvpn/src/svpn_controller.py \
    $XMPP_USERNAME $XMPP_PASSWORD $XMPP_HOST $IP_PREFIX.$i \
    -c $VIRTUAL_BASE/config.json
EOF
    chmod 755 $BASE/start.sh

    sudo mv $container_name $LXC_PATH
    sudo echo "lxc.rootfs = $container_path/rootfs" >> $container_path/config
    sudo echo "lxc.mount = $container_path/fstab" >> $container_path/config
    sudo lxc-start -n $container_name -d
    sleep $WAIT_TIME
done

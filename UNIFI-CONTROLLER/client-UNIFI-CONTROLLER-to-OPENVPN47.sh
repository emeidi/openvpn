#!/bin/sh

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OPENVPN=$(which openvpn)
IPTABLES=$(which iptables)
IFCONFIG=$(which ifconfig)
IP=$(which ip)

CONFIG="/usr/local/apps/openvpn/UNIFI-CONTROLLER/UNIFI-CONTROLLER-to-OPENVPN47.conf"
LOGDIR="/var/log/openvpn"

VPNINTERFACE="tun47"
VPNPORT=4747

GATEWAY="10.0.147.1"
ENDPOINT="10.0.147.2"

SERVERNET="10.0.47.0"
SERVERNETMASK="$SERVERNET/24"
CLIENTNET="10.0.1.0"
CLIENTNETMASK="$CLIENTNET/24"

ETHINTERFACE="eth0"

if [ ! -e "$OPENVPN" ]
then
	echo "Could not find openvpn binary ($OPENVPN). Aborting."
	exit 1
fi

if [ ! -e "$IPTABLES" ]
then
	echo "Could not find iptable binary ($IPTABLES). Aborting."
	exit 1
fi

if [ ! -e "$IFCONFIG" ]
then
	echo "Could not find iptable binary ($IFCONFIG). Aborting."
	exit 1
fi

if [ ! -e "$IP" ]
then
	echo "Could not find iptable binary ($IFCONFIG). Aborting."
	exit 1
fi

if [ ! -d "$LOGDIR" ]
then
  echo "WARNING: Log directory missing. Trying to create it ..."

  CMD="mkdir -p \"$LOGDIR\""
	echo $CMD
	eval $CMD
  echo ""

  if [ ! -d "$LOGDIR" ]
  then
    echo "ERROR: Log directory '$LOGDIR' still does not exist. Aborting."
    exit 1
  fi

  CMD="chmod 777 \"$LOGDIR\""
	echo $CMD
	eval $CMD
  echo ""
fi

# http://www.ducea.com/2006/08/01/how-to-enable-ip-forwarding-in-linux/
IPV4FWDENABLED=$(cat /proc/sys/net/ipv4/ip_forward)

if [ $IPV4FWDENABLED -lt 1 ]
then
	echo "IPv4 forwarding is not enabled ($IPV4FWDENABLED). Enabling it ..."
	sysctl -w net.ipv4.ip_forward=1

	IPV4FWDENABLED=$(cat /proc/sys/net/ipv4/ip_forward)
	if [ $IPV4FWDENABLED -lt 1 ]
	then
		echo "Could not enable IPv4 forwarding. Aborting."
		exit 1
	fi

	echo "Done."
fi

echo "Listing openvpn processes ..."
ps ax | grep -i openvpn
echo "Done."
echo ""

echo "Killing potentially running openvpn processes using configuration $CONFIG ..."
PID=$(ps ax | grep -v grep | grep "$CONFIG" | awk '{print $1}')

if [ -z "$PID" ]
then
	echo "No process found containing '$CONFIG'."
	echo ""
else
	 # http://serverfault.com/a/664831
	 # https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html
	 # Control whether internally or externally generated SIGUSR1 signals are remapped to SIGHUP (restart without persisting state) or SIGTERM (exit).
	echo "Found process with PID '$PID'. Attempting to kill it ..."
	CMD="kill $PID" # No argument = SIGTERM
	echo $CMD
	eval $CMD

	echo "Done."
	echo ""

	echo "Sleeping 10 seconds ..."
	sleep 10
	echo "Done."
	echo ""

	PID=$(ps ax | grep -v grep | grep "$CONFIG" | awk '{print $1}')
	if [ ! -z "$PID" ]
	then
		echo "Could not kill PID $PID. Using the wrench now."
		CMD="kill -9 $PID"
		echo $CMD
		eval $CMD

		ps ax | grep -i openvpn
		#exit 1
	fi
fi

echo "Listing openvpn processes ..."
ps ax | grep -i openvpn
echo "Done."
echo ""

PROC="/proc/sys/net/ipv4/conf/$VPNINTERFACE"
if [ -d $PROC ]
then
	echo "$VPNINTERFACE found. Removing it."

  CMD="$IFCONFIG $VPNINTERFACE down"
	echo $CMD
	eval $CMD

	CMD="$IP link delete $VPNINTERFACE"
	echo $CMD
	eval $CMD

	if [ -f $PROC ]
	then
		echo "Could not remove '$PROC'. Aborting."
		exit 1
	fi

	echo "$PROC removed. Continuing."
	echo ""
fi

echo "Creating $VPNINTERFACE ..."
CMD="$OPENVPN --mktun --dev $VPNINTERFACE"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Creating router ..."
CMD="$IFCONFIG $VPNINTERFACE $ENDPOINT netmask 255.255.255.0 promisc up"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Adding route to Stritenstrasse ..."
CMD="route add -net $SERVERNET netmask 255.255.255.0 gw $GATEWAY"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Sleeping for five seconds ..."
sleep 5
echo "Done."
echo ""

echo "Initiating the tunnel ..."
CMD="$OPENVPN --config $CONFIG"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Checking whether openvpn is listening ..."
CMD="netstat -uap | grep -i openvpn"
echo $CMD
eval $CMD
echo "Done."
echo ""

# Allow traffic initiated from VPN to access LAN
IPTABLESRULEONE="FORWARD -i $VPNINTERFACE -o $ETHINTERFACE -s $SERVERNETMASK -d $CLIENTNETMASK -m conntrack --ctstate NEW -j ACCEPT"

# Allow traffic initiated from LAN to access VPN
IPTABLESRULETWO="FORWARD -i $VPNINTERFACE -o $ETHINTERFACE -s $CLIENTNETMASK -d $SERVERNETMASK -m conntrack --ctstate NEW -j ACCEPT"

# Allow established traffic to pass back and forth
IPTABLESRULETHREE="FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"

IPTABLESRULEFOUR="-t nat -A POSTROUTING -j MASQUERADE"

echo "Deleting iptables ..."
echo "$IPTABLES -D $IPTABLESRULEONE"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Setting up iptables ..."
CMD="$IPTABLES -I $IPTABLESRULEONE"
echo $CMD
eval $CMD
echo "Done."
echo ""

CMD="$IPTABLES -I $IPTABLESRULETWO"
echo $CMD
eval $CMD
echo "Done."
echo ""

CMD="$IPTABLES -I $IPTABLESRULETHREE"
echo $CMD
eval $CMD
echo "Done."
echo ""

CMD="$IPTABLES $IPTABLESRULEFOUR"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Checking iptables setup ..."
CMD="$IPTABLES -S | grep $VPNINTERFACE"
echo $CMD
eval $CMD
echo "Done."
echo ""

echo "Trying to ping ALPHA ..."
CMD="ping -c 5 -i 0.2 10.0.47.101"
echo $CMD
eval $CMD
echo "Done."
echo ""

exit 0

# openvpn
Startup scripts to establish Site-to-Site OpenVPNs between (at least) three sites

# Visualization
![Image of OpenVPN Site-to-Site VPN](OpenVPN Site-to-Site VPN Three Sites.CENSORED.png)

# Glossary
(please refer to visualization)

| Term | Description |
| ---- | ----------- |
| Local Site | 10.0.1.0/24 |
| Remote Sites | 10.0.17.0/24 and 10.0.47.0/24 |
| [OpenVPN] Client | UNIFI-CONTROLLER. The Linux computer device at the local site initiating the VPN tunnels to the remote sites |
| [OpenVPN] Server | OPENVPN17 and OPENVPN47. The Linux computers at remote sites listening on pre-defined UDP ports for incoming packets; OpenVPN endpoints |

# Pre-Requisites for a Three Site Setup
* Your sites use different (non-overlapping) subnets. I recommend to use the private Class A network `10.0.0.0/8` ie. local site `10.0.1.0/24`, remote site one `10.0.17.0/24` and remote site two `10.0.47.0/24`.
  * As you can see I add 100 to the subnet of the virtual the IP addresses of the `tunX` devices to immediately tell me at which tunnel I am currently looking at (the tunnel to subnet 10.0.47.0 is being established over the virtual subnet 10.0.147.0). Also, I set the name of the `tunX` to the third byte of the destination subnet; ie. `tun47` to connect to 10.0.47.0.
* Three computers running Linux
  * I've chosen Debian 8.3 Jessie Stable for all three computers
  * I've bought a used intel NUC Mini-PC which serves as my Linux server within my home LAN
  * I've bought two used [Lenovo X200s](https://support.lenovo.com/ch/en/documents/migr-73156) (ca. 150 CHF/each) to set them up at a hidden away location at the remote sites. This way, I have always a keyboard and a monitor ready in case I have to perform support tasks on location. I've replaced the batteries with Patona replicas (Lenovo P/N 43R9253) and added the cheapest SSD drives I could get ([32GB SanDisk Z400s](https://www.sandisk.com/business/computing/z400s) for 28 CHF/each at [PCP.ch](http://www.pcp.ch/)). Then I configured the laptops to not go to sleep when the lid is closed.
* (only in case if you don't use static IPv4 addresses) The routers or the Linux computers at the remote sites do have a DynDNS host name assigned and run a DynDNS daemon to periodically update the public IP address
* UDP Port forwarding has to be enabled on the routers at the remote sites (TP-LINK TL-WDR3600 and Netgear WNDR3700) forwarding UDP packets coming from the Internet on Ports 1717 or 4747 respectively to the OPENVPN17/47 devices
* SSH Port forwarding should be enabled on the routers at the remote sites (TP-LINK TL-WDR3600 and Netgear WNDR3700) forwarding SSH packets to a) OPENVPN17 or OPENVPN47 respectively and b) (if available) a second Linux machine on the remote LAN in case you fuck up OpenVPN configuration OPENVPN17 or OPENVPN47 (and please remember: if you fuck up the whole Linux installation, you might need to commute to the remote location to fix things)
* Static Routes have to be configured on all three routers in case you want all devices on the local LANs to talk to remote LANs (otherwise, only OPENVPN17, OPENVPN47 and UNIFI-CONTROLLER will be able to ping devices in other LANs)
* Set up a (private) Git or SVN repository to store all configuration and scripts both for restoring previous versions as well as to have always an up-to-date source for all three machines. Manually or automatically sync configuration to OPENVPN17, OPENVPN47 and UNIFI-CONTROLLER

# Installation Instructions
1. Download this GitHub repository to all three computers
1. Check Bash scripts for malicious contents
1. Make Bash scripts executable
1. Update all `.conf` and `.sh` files with the correct LAN addressing of your networks. You also could adjust the addressing of your `tunX` devices, but you don't necessarily need to
1. Update local (= on UNIFI-CONTROLLER) OpenVPN .conf files with the DynDNS hostnames of your remote sites (or their static IP addresses)
1. Generate static keys running `openvpn --genkey --secret static.key`. I recommend to generate a different static key for *each* VPN tunnel. Place them in all three folders of the repository on all three computers.
1. Update `/etc/network/interfaces` with a parameter `post-up` which points the startup script in your local repository directory. Examples: Please refer to file `etc-network-interfaces` in each computer folder
1. Set up static routes on your routers
1. Reboot OPENVPN17 and OPENVPN47, then reboot UNIFI-CONTROLLER

# Troubleshooting
My startup scripts are rather verbose and should be able to be run at any time over and over again (cleaning up before, then starting more or less from scratch). If unsure, you always can run them interactively and check their console output.

Second, always check OpenVPN logs in `/var/log/openvpn`. In case of failure, you should also try to increase OpenVPN verbosity to at least verb 5 in the local OpenVPN .conf

Check whether `ifconfig` reports the tun-Devices and whether the counters show any traffic. Sample output:

```
tun47     Link encap:UNSPEC  HWaddr 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  
          inet addr:10.0.147.1  P-t-P:10.0.147.1  Mask:255.255.255.0
          UP POINTOPOINT RUNNING NOARP PROMISC MULTICAST  MTU:1500  Metric:1
          RX packets:9033859 errors:0 dropped:0 overruns:0 frame:0
          TX packets:10611082 errors:0 dropped:17 overruns:0 carrier:0
          collisions:0 txqueuelen:100
          RX bytes:1566611815 (1.4 GiB)  TX bytes:4453247032 (4.1 GiB)
```

# Speed
I've set up an [iperf3](https://iperf.fr) server on UNIFI-CONTROLLER and run hourly speed tests initiated by `iperf3` clients on OPENVPN17 and OPENVPN47. I then move the JSON output to another Linux server in my network, parse the data, import it into [cacti](http://www.cacti.net) and plot the values using this software. As you can see in the images below, a) the throughput is generally steady (don't ask me what happened at 4am on Friday, October 21) and b) the upload speed is visibly capped by [upc cablecom](https://www.upc.ch/). Fun fact: OPENVPN17 is located in the City of Bern, OPENVPN47 on the countryside — unexpectedly, upload speed is faster outside of town.

![Image of OPENVPN17 to UNIFI-CONTROLLER iPerf3](OPENVPN17.CENSORED.png)
![Image of OPENVPN47 to UNIFI-CONTROLLER iPerf3](OPENVPN47.CENSORED.png)

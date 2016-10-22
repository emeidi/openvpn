remote      ddns.domain.tld
proto       udp
rport       4747
dev         tun47
secret      /usr/local/apps/openvpn/OPENVPN47/static.key
verb        4
comp-lzo
keepalive   15 60
daemon

bind
lport               4747
persist-tun
persist-key
user                nobody
group               nogroup
status              /var/log/openvpn/status.OPENVPN47.log
log-append          /var/log/openvpn/append.OPENVPN47.log
resolv-retry        infinite

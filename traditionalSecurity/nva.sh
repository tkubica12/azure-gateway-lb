#!/bin/bash

# Enable routing
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -p

# Enable outbound SNAT (Internet access for VMs)
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o eth0 -j MASQUERADE

# Enable service - rewrite destination to app LB IP and rewrite source to self
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 1001 -j DNAT --to-destination 10.0.0.100:80
sudo iptables -t nat -A POSTROUTING -p tcp -d 10.0.0.100 --dport 80 -j MASQUERADE
#!/bin/bash

# Install bridge support
sudo apt update
sudo apt install bridge-utils -y

# Create VXLAN interfaces
sudo ip link add vxlan0 type vxlan id 900 dev eth0 dstport 10800 remote 10.1.0.100
sudo ip link set vxlan0 up
sudo ip link add vxlan1 type vxlan id 901 dev eth0 dstport 10801 remote 10.1.0.100
sudo ip link set vxlan1 up

# Create bridge
sudo brctl addbr br0
sudo brctl addif br0 vxlan0
sudo brctl addif br0 vxlan1
sudo ip link set br0 up
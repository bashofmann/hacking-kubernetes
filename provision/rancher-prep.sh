#!/bin/bash

apt remove -y unattended-upgrades
apt update
apt install -y apt-transport-https ca-certificates curl socat jq git unzip wget
curl -fsSl "https://download.docker.com/linux/ubuntu/gpg" | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
apt install -y docker-ce=18.06.3~ce~3-0~ubuntu
systemctl disable apparmor
systemctl stop apparmor
apt purge -y apparmor

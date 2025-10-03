#/usr/bin/sh

if [ "$1" == "setup" ]; then
    echo "alias c=clear" >> ~/.bashrc
    sudo apt-get upgrade
    sudo apt install vim -y
    sudo echo "set nu rnu" >> ~/.vimrc
    sudo echo "syntax on" >> ~/.vimrc
    sudo echo "set -o vi" >> ~/.bashrc
    sudo swapoff -a

    sudo apt-get update
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
    sysctl net.ipv4.ip_forward

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    sudo systemctl status docker
    sudo systemctl start docker

    sudo systemctl stop apparmor
    sudo systemctl disable apparmor 
    sudo systemctl restart containerd.service

    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable --now kubelet

    sudo rm /etc/containerd/config.toml
    sudo systemctl restart containerd

    touch kubeadm-config.yaml
    echo "# kubeadm-config.yaml
    kind: ClusterConfiguration
    apiVersion: kubeadm.k8s.io/v1beta4
    kubernetesVersion: v1.34.1
    networking:
    podSubnet: "10.244.0.0/16"
    controlPlaneEndpoint: 192.168.1.175:6443
    cgroupDriver: systemd" >> kubeadm-config.yaml

    mkdir -p $HOME/.kube
fi

if [ "$1" == "reset" ]; then
    sudo rm -rf /etc/kubernetes/
    sudo rm -f $HOME/.kube/config
    sudo kubeadm reset
fi

if [ "$1" == "init" ]; then
    sudo kubeadm init --config kubeadm-config.yaml
    sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi
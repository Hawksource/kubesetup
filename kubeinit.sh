#!/bin/sh

if [ "$1" = "setup" ]; then
    echo "alias c=clear" >> ~/.bashrc
    sudo apt-get upgrade -y
    sudo apt install vim -y
    echo "set nu rnu" >> ~/.vimrc
    echo "syntax on" >> ~/.vimrc
    echo "set -o vi" >> ~/.bashrc
    sudo swapoff -a

    # Required sysctl
    echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/k8s.conf
    sudo sysctl --system

    # Docker repo (needed for containerd)
    sudo apt-get update
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install containerd.io docker-buildx-plugin docker-compose-plugin -y

    # DO NOT disable AppArmor (breaks containerd)

    # Proper containerd config
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd

    # Kubernetes repo
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
        | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable --now kubelet

    mkdir -p $HOME/.kube
fi


if [ "$1" = "reset" ]; then
    sudo kubeadm reset -f
    sudo rm -rf /etc/kubernetes/
    rm -f $HOME/.kube/config
fi


if [ "$1" = "init" ]; then
    sudo kubeadm init --config kubeadm-config.yaml

    mkdir -p $HOME/.kube
    sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo ""
    echo " After init, apply a CNI (example: Flannel):"
    echo "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
fi

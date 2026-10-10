#!/usr/bin/env bash

############################################################
# 安装K8S 环境
############################################################


print() {
    echo '
    马上开始 K8S 的安装，请确认是否开始安装。
    '
    read -p "请输入 [y/n]（默认不安装）: " choice

    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "退出安装。"
        exit 0
    fi
}

install_k8s() {
    apt-get update && apt-get install -y apt-transport-https
    curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.28/deb/Release.key |
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.28/deb/ /" |
        tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
}

set_k8s() {
    sed -i 's|KUBELET_EXTRA_ARGS=$|KUBELET_EXTRA_ARGS="--cgroup-driver=systemd --container-runtime-endpoint=/run/cri-dockerd.sock" |' /etc/default/kubelet
    systemctl enable kubelet
}

pull_k8s() {
    kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock
}

main() {
    print

    install_k8s
    set_k8s

    exit 0
}

main


kubectl cluster-info

# kube-proxy
kubectl get configmap -n kube-system
kubectl edit configmap kube-proxy -n kube-system
    mode: "ipvs"
kubectl rollout restart daemonset kube-proxy -n kube-system

# 重启后查看kube-proxy 的状态
kubectl get pods -n kube-system

# 验证 dns
kubectl get svc -n kube-system

dig -t a www.bing.com @10.96.0.10
# 如果能解析出 A 记录，说明dns 没有问题

root@k8s-master01:/etc/default# kubeadm init --kubernetes-version=v1.28.15 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.52.129  --cri-socket unix:///var/run/cri-dockerd.sock
[init] Using Kubernetes version: v1.28.15
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [k8s-master01 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.52.129]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [k8s-master01 localhost] and IPs [192.168.52.129 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [k8s-master01 localhost] and IPs [192.168.52.129 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 4.002378 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node k8s-master01 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node k8s-master01 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: vrp1m2.bgm8l8xbxsmhjmg4
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.52.129:6443 --token vrp1m2.bgm8l8xbxsmhjmg4 \
        --discovery-token-ca-cert-hash sha256:7aaae499b1f2ab15f4f8c513d8c54181216afdbd07c436501e9e4881eddec95e


## 问题解决
kubectl describe pod calico-apiserver-5b9b48d497-5ck29 -n calico-apiserver
network is not ready: container runtime network not ready: NetworkReady=false
reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized

# 这个目录下没有配置文件，说明没有安装 CNI
ls /etc/cni/net.d/

wget https://docs.projectcalico.org/manifests/calico.yaml
修改配置文件中的这个配置项
- name: CALICO_IPV4POOL_CIDR
  value: "10.244.0.0/16"

kubectl apply -f calico.yaml
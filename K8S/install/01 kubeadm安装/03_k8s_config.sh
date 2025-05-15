
# 1、安装
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.28/rpm/repodata/repomd.xml.key
EOF
setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet

# debian 系统安装
apt-get update && apt-get install -y apt-transport-https
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.28/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.28/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl



# 2、配置kubelet
# 为了实现docker使用的cgroupdriver与kubelet使用的cgroup的一致性，建议修改如下文件内容。
# vim /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"

# debian 系统 /etc/default/kubelet

systemctl enable kubelet

# 3、
# cat image_download.sh
#!/bin/bash
images_list='
registry.k8s.io/kube-apiserver:v1.28.15
registry.k8s.io/kube-controller-manager:v1.28.15
registry.k8s.io/kube-scheduler:v1.28.15
registry.k8s.io/kube-proxy:v1.28.15
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.15-0
registry.k8s.io/coredns/coredns:v1.10.1'

for i in $images_list
do
        docker pull $i
done

docker save -o k8s-v1-28-15.tar $images_list


# 4、集群初始化
# 在主节点做初始化
kubeadm init --kubernetes-version=v1.28.15 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.52.129


kubeadm init --kubernetes-version=v1.28.15 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.52.129

# 以下报错解决
[init] Using Kubernetes version: v1.28.15
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR CRI]: container runtime is not running: output: time="2025-05-04T11:52:11-04:00" level=fatal msg="validate service connection: validate CRI v1 runtime API for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
, error: exit status 1
        [ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables does not exist
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
To see the stack trace of this error execute with --v=5 or higher

# 问题解决
# 解决容器运行时问题
# (1) 检查 containerd.md 是否已安装并运行
# 运行以下命令检查 containerd.md 的状态：
sudo systemctl status containerd.md

# (2) 验证 containerd.md 配置
# 确保 containerd.md 的配置文件（通常位于 /etc/containerd.md/config.toml）正确配置了 CRI（容器运行时接口）。运行以下命令生成默认配置（如果配置文件不存在）：
sudo containerd.md config default | sudo tee /etc/containerd.md/config.toml

# (3) 重启 containerd.md
# 修改配置后，重启 containerd.md：
sudo systemctl restart containerd.md

# (4) 验证 containerd.md 是否支持 CRI
# 运行以下命令验证 containerd.md 是否支持 CRI：
sudo ctr version
# 如果输出显示版本信息，说明 containerd.md 已正确配置。

# 解决 /proc/sys/net/bridge/bridge-nf-call-iptables 问题
# (1) 加载 br_netfilter 内核模块
# 运行以下命令加载 br_netfilter 模块：
sudo modprobe br_netfilter

# (2) 确保模块已加载
# 运行以下命令检查模块是否已加载：
lsmod | grep br_netfilter
# 如果输出显示 br_netfilter，说明模块已加载。

# (3) 确保 /proc/sys/net/bridge/bridge-nf-call-iptables 存在
# 运行以下命令检查文件是否存在：
cat /proc/sys/net/bridge/bridge-nf-call-iptables

# 如果文件不存在，可能是内核未正确配置。可以手动创建并设置值：
echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables

# (4) 永久生效
# 为了确保每次重启后配置仍然有效，编辑 /etc/sysctl.conf 文件：
sudo vim /etc/sysctl.conf

# 添加以下内容：
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
# 保存并退出，然后应用配置：

sudo sysctl --system


[init] Using Kubernetes version: v1.28.15
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
W0504 12:48:00.026524    2144 checks.go:835] detected that the sandbox image "registry.k8s.io/pause:3.8" of the container runtime is inconsistent with that used by kubeadm. It is recommended that using "registry.k8s.io/pause:3.9" as the CRI sandbox image.
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local master01] and IPs [10.96.0.1 192.168.52.129]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost master01] and IPs [192.168.52.129 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost master01] and IPs [192.168.52.129 127.0.0.1 ::1]
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
[apiclient] All control plane components are healthy after 21.505666 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node master01 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node master01 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: o4l5gb.8jem7v7x9upd376t
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

kubeadm join 192.168.52.129:6443 --token ghwg0j.hwc8l4o3h8j65le4 \
        --discovery-token-ca-cert-hash sha256:31ae1608dded0e8a442eaa653e52fc371f46bcbe3b047aa4a7a0a218d2601a50


# 5、根据提示执行
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

# 6、安装集群网络环境
使用calico部署集群网络
安装参考网址：https://projectcalico.docs.tigera.io/about/about-calico



###########################################################################
# 重置

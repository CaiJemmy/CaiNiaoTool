#!/usr/bin/env bash

###############################################
# node 相关命令

# 查看节点标签信息
echo "查看节点标签信息: kubectl get node --show-labels"
kubectl get node --show-labels

# 查看集群节点信息
echo "查看集群节点信息: kubectl get nodes"
kubectl get nodes

# 查看集群节点详细信息
echo "查看集群节点详细信息: kubectl get nodes -o wide"
kubectl get nodes -o wide


# 查看节点描述详细信息
echo "查看节点描述详细信息: kubectl describe node k8s-master01"
kubectl describe node k8s-master01



# 查看节点标签信息
echo "查看节点标签信息: kubectl get node --show-labels"
kubectl get node --show-labels


# 设置节点标签
echo "设置节点标签: kubectl label node k8s-worker01 region=cainiao"
kubectl label node k8s-worker01 region=cainiao


# 查看所有节点带region的标签
echo "查看所有节点带region的标签: kubectl get nodes -L region"
kubectl get nodes -L region

# 设置多维度标签
echo "设置多维度标签: kubectl label node k8s-worker02 zone=A env=test bussiness=game"
kubectl label node k8s-worker02 zone=A env=test bussiness=game

echo "查看k8s-worker02节点标签信息: kubectl get nodes k8s-worker02 --show-labels"
kubectl get nodes k8s-worker02 --show-labels


# 显示节点的相应标签
echo "显示节点的相应标签: kubectl get nodes -L region,zone"
kubectl get nodes -L region,zone


# 查找region=cainiao的节点
echo "查找region=cainiao的节点: kubectl get nodes -l region=cainiao"
kubectl get nodes -l region=cainiao


# 标签的修改
echo "标签的修改: kubectl label node k8s-worker02 bussiness=ad --overwrite=true"
kubectl label node k8s-worker02 bussiness=ad --overwrite=true

kubectl get node k8s-worker02 -L bussiness

# 标签的删除
echo "标签的删除: kubectl label node k8s-worker01 region-"
kubectl label node k8s-worker01 region-

kubectl get nodes k8s-worker01 --show-labels



# 标签选择器
echo "标签选择器，测试1: kubectl label node k8s-master01 env=test1"
kubectl label node k8s-master01 env=test1

echo "标签选择器，测试2: kubectl label node k8s-worker01 env=test2"
kubectl label node k8s-worker01 env=test2

echo "标签选择器，获取测试数据: kubectl get node -l \"env in(test1,test2)\""
kubectl get node -l "env in(test1,test2)"


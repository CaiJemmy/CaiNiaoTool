#!/usr/bin/env bash

###############################################
#
#
###############################################

# 配置自动补全
set_k8s_completion() {
    [ ! -f /usr/share/bash-completion/bash_completion ] && apt -y install bash-completion
    source /usr/share/bash-completion/bash_completion

    [ ! -d ~/.kube ] && mkdir ~/.kube
    [ ! -f ~/.kube/completion.bash.inc ] && kubectl completion bash > ~/.kube/completion.bash.inc

    if ! grep -q "source ~/.kube/completion.bash.inc" ~/.profile; then
        echo "source ~/.kube/completion.bash.inc" >> ~/.profile
    fi
    source "$HOME/.profile"
}

# worker node节点管理集群
# 在 worker 节点执行下面的scp命令，注意主机名：k8s-master01
scp_k8s_config() {
    [ ! -f /root/.kube/config ] && scp k8s-master01:/etc/kubernetes/admin.conf /root/.kube/config
}

main() {
    set_k8s_completion
    scp_k8s_config

    exit 0
}

main

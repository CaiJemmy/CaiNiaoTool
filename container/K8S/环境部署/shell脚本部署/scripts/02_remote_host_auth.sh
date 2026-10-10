#!/bin/bash
# **********************************************************
# * 作者       : cainiaoliu
# * 联系       : 123894924@qq.com
# * 时间       : 2026-10-10
# * 版本       : V0.1
# * 描述       : 批量设定远程主机免密码认证
# **********************************************************

# 加载配置文件
source "./lib/utils.sh"
root_dir=$(dirname "$PWD")
[ -f "${root_dir}/conf/config" ] && . "${root_dir}/conf/config" || exit

# 准备工作
os_type="$1"
[ "${os_type}" == "centos" ] && cmd_type='yum' || cmd_type='apt-get'
target_type=(部署 免密 同步 主机名 软件源 退出)

# 菜单
menu(){
  echo -e "\e[31m批量设定远程主机免密码认证管理界面\e[0m"
  echo "====================================================="
  echo -e "\e[32m 1: 部署环境   2: 免密认证   3: 同步hosts \e[0m"
  echo -e "\e[32m 4: 设定主机名 5: 更新软件源 6: 退出操作 \e[0m"
  echo "====================================================="
}

# 更新hosts文件
update_hosts(){
  awk '$0~"kubernetes-"{print $1,$2".superopsmsb.com",$2}' "${confs_dir}/${host_name}" >> "${host_file}"
}

# expect环境
expect_install(){
  grep -q "114.114.114.114" /etc/resolv.conf && grep -q "8.8.8.8" /etc/resolv.conf || (cp /etc/resolv.conf /etc/resolv.conf.bak && echo "nameserver 114.114.114.114" > /etc/resolv.conf && echo "nameserver 8.8.8.8" >> /etc/resolv.conf)

  if [ -f /usr/bin/expect ];then
    echo -e "\e[33mexpect环境已经部署完毕\e[0m"
  else
    read -p "请输入安装expect的方式(在线-online，离线-offline): " install_status
    install_status=${install_status:-online}
    if [ "${install_status}" == "online" ]; then
      
      "${cmd_type}" install expect -y >> /dev/null 2>&1 && echo -e "\e[33mexpect软件安装完毕\e[0m" || (echo -e "\e[33mexpect软件安装失败\e[0m" && exit)
    else
      if [ "${os_type}" == "centos" ]; then
        filename="${centos_expect}"
        "${cmd_type}" install -y "${softs_dir}/expect/${filename}"
      else
        filename="${ubuntu_expect}"
        [ -f /var/lib/dpkg/lock-frontend ] && rm -f /var/lib/dpkg/lock-frontend
        dpkg -i "${softs_dir}/expect/${filename}"
        apt --fix-broken install -y
      fi
    fi
  fi
}
# 秘钥文件生成环境
create_authkey(){
  # 保证历史文件清空
  [ -d ${user_dir}/.ssh ] && rm -rf ${user_dir}/.ssh/*
  # 构建秘钥文件对
  /usr/bin/ssh-keygen -t rsa -P "" -f ${user_dir}/.ssh/id_rsa
  echo -e "\e[33m秘钥文件已经创建完毕\e[0m"
}
# expect自动匹配逻辑
expect_autoauth_func(){
  # 接收外部参数
  command="$@"
  expect -c "
    spawn ${command}
    expect {
      \"yes/no\" {send \"yes\r\"; exp_continue}
      \"*password*\" {send \"${login_pass}\r\"; exp_continue}
      \"*password*\" {send \"${login_pass}\r\"}
   }"
}
# 跨主机传输文件认证
sshkey_auth_func(){
  # 接收外部的参数
  local host_list="$*"
  for ip in ${host_list}
  do
     cmd="/usr/bin/ssh-copy-id -i ${user_dir}/.ssh/id_rsa.pub"
     remote_host="${login_user}@${ip}"
     expect_autoauth_func ${cmd} ${remote_host}
  done
}

# 跨主机同步hosts文件
scp_hosts_func(){
  # 接收外部的参数
  local host_list="$*"
  for ip in ${host_list}
  do
     remote_host="${login_user}@${ip}"
     scp ${host_file} ${remote_host}:${host_file}
  done
}

# 跨主机设定主机名规划
set_hostname_func(){
  # 接收外部的参数
  local host_list="$*"
  for ip in ${host_list}
  do
     host_name=$(grep ${ip} ${host_file}|awk '{print $NF}'| tr -d '\r\n\t' | xargs)
     remote_host="${login_user}@${ip}"
     ssh ${remote_host} "hostnamectl set-hostname ${host_name}"
     ssh ${remote_host} "grep -q '114.114.114.114' /etc/resolv.conf && grep -q '8.8.8.8' /etc/resolv.conf || (cp /etc/resolv.conf /etc/resolv.conf.bak && echo 'nameserver 114.114.114.114' > /etc/resolv.conf && echo 'nameserver 8.8.8.8' >> /etc/resolv.conf)"
  done
}

# 确保软件源管用
repo_update(){
  # 接收外部的参数
  local host_list="$*"
  if [ "${os_type}" == "centos" ]; then
    update_cmd="${cmd_type} makecache fast"
  else
    update_cmd="${cmd_type} update -y"
  fi
  for ip in ${host_list}
  do
     ssh ${remote_host} "${update_cmd}"
  done
}
# 帮助信息逻辑
Usage(){
  echo "请输入有效的操作id"
}
# 逻辑入口
while true
do
  menu
  read -p "请输入有效的操作id: " target_id
  if [ ${#target_type[@]} -ge ${target_id} ]
  then
    if [ ${target_type[${target_id}-1]} == "部署" ]
    then
       echo "开始部署环境操作..."
       expect_install
       create_authkey
       update_hosts
    elif [ ${target_type[${target_id}-1]} == "免密" ]
    then
       read -p "请输入需要批量远程主机认证的主机列表范围(示例: {12..19}): " num_list
       ip_list=$(expand_ip_list "${num_list}")
       echo "开始执行免密认证操作..."
       sshkey_auth_func ${ip_list}
    elif [ ${target_type[${target_id}-1]} == "同步" ]
    then
       read -p "请输入需要批量远程主机同步hosts的主机列表范围(示例: {12..19}): " num_list
       ip_list=$(expand_ip_list "${num_list}")
       echo "开始执行同步hosts文件操作..."
       scp_hosts_func ${ip_list}
    elif [ ${target_type[${target_id}-1]} == "主机名" ]
    then
       read -p "请输入需要批量设定远程主机主机名的主机列表范围(示例: {12..19}): " num_list
       ip_list=$(expand_ip_list "${num_list}")
       echo "开始执行设定主机名操作..."
       set_hostname_func ${ip_list}
    elif [ ${target_type[${target_id}-1]} == "软件源" ]
    then
       read -p "请输入需要批量更新远程主机软件源的主机列表范围(示例: {12..19}): " num_list
       ip_list=$(expand_ip_list "${num_list}")
       echo "开始执行更新主机软件源操作..."
       repo_update ${ip_list}
    elif [ ${target_type[${target_id}-1]} == "退出" ]
    then
       echo "开始退出管理界面..."
       exit
    fi
  else
    Usage
  fi
done

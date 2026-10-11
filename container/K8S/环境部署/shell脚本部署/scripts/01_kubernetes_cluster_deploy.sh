#!/bin/bash
# **********************************************************
# * 作者       : cainiaoliu
# * 联系       : 123894924@qq.com
# * 时间       : 2026-10-10
# * 版本       : V0.1
# * 描述       : 部署K8s环境
# **********************************************************

# Check if user is root
[ "$(id -u)" != "0" ] && {
  echo "Error: You must be root to run this script"
  exit 1
}

# 加载配置文件
source "./lib/utils.sh"
source "./lib/logging.sh"

root_dir=$(dirname "$PWD")
[ -f "${root_dir}/conf/config" ] && . "${root_dir}/conf/config" || exit

# 基础环境配置
target_type=(基础 内核 容器 harbor 高可用 k8s 管理 退出)

# 菜单
deploy_menu(){
  log_info "K8s平台自动化管理界面"
  log_info "====================================================="
  log_info " 1: 基础环境定制   2: 内核模块配置  "
  log_info " 3: 容器环境定制   4: 部署镜像仓库  "
  log_info " 5: 部署高可用环境 6: k8s环境部署  "
  log_info " 7: 管理k8s环境    8: 退出操作  "
  log_info "====================================================="
}

# 传递文件函数
scp_files_func(){
  # 接收外部的参数
  local file_name=$(echo $* | awk '{print $NF}')
  local host_list=$(echo $* | awk '{$NF=null;print $0}')
  local file_path=$(dirname ${file_name})
  for ip in ${host_list}
  do
     remote_host="${login_user}@${ip}"
     log_exec ssh ${login_user}@${ip} "\'[ -d ${file_path} ] || mkdir -p ${file_path}\'"
     log_exec scp ${file_name} ${remote_host}:${file_name}
  done
}

# 软件源配置
get_softs(){
  softs_name="$1"
  softs_url="$2"
  # 获取软件
  if [ ! -f "${softs_dir}/${softs_name}" ]; then
    log_info "开始下载指定版本的程序文件 "
    [ -d "${softs_dir}" ] || mkdir -p "${softs_dir}" 
    pushd "${softs_dir}" >/dev/null
    wget "${softs_url}"
    popd >/dev/null
  else
    log_info "${softs_dir} 目录下已经存在指定版本的程序文件 "
  fi
}

# 帮助信息逻辑
Usage(){
  log_info "请输入有效的操作id"
}
# 逻辑入口
read -p "请输入kubernetes集群主机的系统环境(centos|ubuntu|debian),默认值是debian: " os_type
os_type="${os_type:-debian}"
while true
do
  deploy_menu
  read -p "请输入有效的操作id: " target_id
  if [ ${#target_type[@]} -ge ${target_id} ]
  then
    if [ ${target_type[${target_id}-1]} == "基础" ]; then
       log_warn "开始执行基础环境操作..."
       [ -f ${scripts_dir}/${base_env_scripts} ] && /bin/bash ${scripts_dir}/${base_env_scripts} "${os_type}"
    elif [ ${target_type[${target_id}-1]} == "内核" ]; then
       log_warn "开始执行内核模块配置..."
       read -p "请输入k8s集群主机列表范围(示例: {12..19}): " num_list
       ip_list=$(expand_ip_list "${num_list}")
       if [ -f "${scripts_dir}/${k8s_kernel_scripts}" ]; then
          scp_files_func "${ip_list}" "${scripts_dir}/${k8s_kernel_scripts}"
          for ip in ${ip_list}
          do
            log_exec ssh ${login_user}@${ip} "\'/bin/bash ${scripts_dir}/${k8s_kernel_scripts}\'"
          done
       else
          log_error "脚本 ${scripts_dir}/${k8s_kernel_scripts} 不存在"
       fi
    elif [ ${target_type[${target_id}-1]} == "容器" ]; then
       log_warn "开始执行容器环境定制..."
       read -p "请输入以哪种方式部署(离线-offline,在线-online): " docker_status
       read -p "请输入k8s集群主机列表范围(示例: {12..19}): " num_list
       ip_list=$(expand_ip_list "${num_list}")
       if [ "${docker_status}" == "online" ]; then
         # 部署docker服务
         if [ -f "${scripts_dir}/${k8s_docker_online}" ]; then
           scp_files_func "${ip_list}" "${scripts_dir}/${k8s_docker_online}"
           for ip in ${ip_list}
           do
             log_exec ssh ${login_user}@${ip} "\'/bin/bash ${scripts_dir}/${k8s_docker_online} ${os_type}\'"
           done
         else
           log_error "脚本 ${scripts_dir}/${k8s_docker_online} 不存在"
         fi
       else
         # 获取docker文件
         get_softs "${docker_softs}" "${docker_url}"
         # 传递文件给远程主机
         if [ -f "${scripts_dir}/${k8s_docker_offline}" ]; then
           scp_files_func "${ip_list}" "${scripts_dir}/${k8s_docker_offline}"
           for ip in ${ip_list}
           do
             log_exec ssh ${login_user}@${ip} "\'[ -d ${softs_dir} ] || mkdir -p ${softs_dir}\'"
             log_exec scp ${softs_dir}/${docker_softs} ${login_user}@${ip}:${softs_dir}/${docker_softs}
             log_exec ssh ${login_user}@${ip} "\'/bin/bash ${scripts_dir}/${k8s_docker_offline}\'"
           done
         else
           log_error "脚本 ${scripts_dir}/${k8s_docker_offline} 不存在"
         fi
       fi
       # 部署cri-dockerd服务
       if [ -f "${scripts_dir}/${k8s_cri_scripts}" ]; then
          log_exec /bin/bash ${scripts_dir}/${k8s_cri_scripts} ${ip_list}
       else
          log_error "脚本 ${scripts_dir}/${k8s_cri_scripts} 不存在"
       fi
    elif [ ${target_type[${target_id}-1]} == "harbor" ]; then
       log_warn "开始执行镜像仓库部署操作..."
       # 获取harbor地址信息
       harbor_address=$(awk '/register/{print $1}' "${confs_dir}/${host_name}")
       log_info "开始执行镜像仓库的容器环境部署操作..."
       scp_files_func "${harbor_address}" "${scripts_dir}/${k8s_docker_offline}"
       scp_files_func "${harbor_address}" "${softs_dir}/${docker_softs}"
       # echo ssh "${login_user}@${harbor_address}" "/bin/bash ${scripts_dir}/${k8s_docker_offline}"
       log_exec ssh "${login_user}@${harbor_address}" "\'/bin/bash ${scripts_dir}/${k8s_docker_offline}\'"
       # exit
       # 获取harbor文件
       get_softs "${compose_softs}" "${compose_url}"      
       get_softs "${harbor_softs}" "${harbor_url}"      
       scp_files_func "${harbor_address}" "${softs_dir}/${compose_softs}"
       scp_files_func "${harbor_address}" "${softs_dir}/${harbor_softs}"
       if [ -f "${scripts_dir}/${k8s_harbor_scripts}" ]; then
         scp_files_func "${harbor_address}" "${scripts_dir}/${k8s_harbor_scripts}"
         log_exec ssh "${login_user}@${harbor_address}" "\'/bin/bash ${scripts_dir}/${k8s_harbor_scripts} ${os_type}\'"
       else
          log_error "脚本 ${scripts_dir}/${k8s_harbor_scripts} 不存在"
       fi
       # 所有节点都使用本地镜像仓库
       
    elif [ ${target_type[${target_id}-1]} == "高可用" ]; then
       read -p "请输入以哪种方式部署(离线-offline,在线-online): " ha_type
       ha_type="${ha_type:-online}"
       ha_list=$(awk '/-ha/{print $1}' "${confs_dir}/${host_name}")
       log_warn "开始执行高可用环境部署操作..."
       if [ "${ha_type}" == "online" ]; then
         # 部署haproxy和keepalived服务
         if [ -f "${scripts_dir}/${k8s_ha_online}" ]; then
           scp_files_func ${ha_list} "${scripts_dir}/${k8s_ha_online}"
           for ip in ${ha_list}
           do
             keepalived_state=$(grep ${ip} ${confs_dir}/${host_name} | awk '{print $NF}')
             log_exec ssh ${login_user}@${ip} "\'/bin/bash ${scripts_dir}/${k8s_ha_online} ${os_type} ${keepalived_state}\'"
           done
         else
           log_error "脚本 ${scripts_dir}/${k8s_ha_online} 不存在"
         fi
       else
         if [ -f "${scripts_dir}/${k8s_ha_offline}" ]; then
           scp_files_func ${ha_list} "${scripts_dir}/${k8s_ha_offline}"
           for ip in ${ha_list}
           do
             [ "${os_type}" == "centos" ] && ha_dir='k8s-ha-centos' || ha_dir='k8s-ha-ubuntu'
             log_exec ssh ${login_user}@${ip} "\'[ -d ${softs_dir} ] || mkdir -p ${softs_dir}\'"
             log_exec scp -r "${softs_dir}/${ha_dir}" "${login_user}@${ip}:${softs_dir}"
             keepalived_state=$(grep ${ip} ${confs_dir}/${host_name} | awk '{print $NF}')
             log_exec ssh ${login_user}@${ip} "\'/bin/bash ${scripts_dir}/${k8s_ha_offline} ${os_type} ${keepalived_state} ${ha_dir}\'"
           done
         else
           log_error "脚本 ${scripts_dir}/${k8s_ha_offline} 不存在"
         fi
       fi
    elif [ ${target_type[${target_id}-1]} == "k8s" ]; then
       log_warn "开始执行k8s环境部署操作..."
       if [ -f "${scripts_dir}/${k8s_cluster_scripts}" ]; then
         log_exec /bin/bash ${scripts_dir}/${k8s_cluster_scripts} "${os_type}"
       else
         log_error "脚本 ${scripts_dir}/${k8s_cluster_scripts} 不存在"
       fi
    elif [ ${target_type[${target_id}-1]} == "管理" ]; then
       log_warn "开始执行k8s环境管理操作..."
       if [ -f "${scripts_dir}/${k8s_reset_scripts}" ]; then
          log_exec /bin/bash ${scripts_dir}/${k8s_reset_scripts} "${os_type}"
       else
          log_error "脚本 ${scripts_dir}/${k8s_reset_scripts} 不存在"
       fi
    elif [ ${target_type[${target_id}-1]} == "退出" ]; then
       log_info "开始退出管理界面..."
       exit
    fi
  else
    Usage
  fi
done

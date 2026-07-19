#!/bin/bash

source "${CAINIAOTOOL_ROOT}/lib/logging.sh"

#installDepsDebian() {
#    echo "${C_MSG}Removing the conflicting packages...${C_END}"
#    if [ "${apache_flag}" == 'y' ]; then
#        killall apache2
#        pkgList="apache2 apache2-doc libsodium-dev apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd"
#        for Package in ${pkgList}; do
#            apt-get -y purge ${Package}
#        done
#        dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
#    fi
#
#    if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]]; then
#        pkgList="mysql-client mysql-server mysql-common libsodium-dev mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
#        for Package in ${pkgList}; do
#            apt-get -y purge ${Package}
#        done
#        dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
#    fi
#
#    echo "${C_MSG}Installing dependencies packages...${C_END}"
#    apt-get -y update
#    apt-get -y autoremove
#    apt-get -yf install
#    export DEBIAN_FRONTEND=noninteractive
#
#    # critical security updates
#    grep security /etc/apt/sources.list >/tmp/security.sources.list
#    apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list
#
#    # Install needed packages
#    case "${Debian_version}" in
#    11 | 12 | 13)
#        pkgList="debian-keyring libsodium-dev debian-archive-keyring libxpm-dev build-essential gcc g++ make cmake autoconf libbz2-dev libjpeg62-turbo-dev libjpeg-dev libpng-dev libgd-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3-gnutls libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl net-tools libssl-dev libtool libevent-dev bison re2c libsasl2-dev libxslt1-dev libicu-dev locales patch vim zip unzip tmux htop bc dc expect libexpat1-dev libonig-dev libtirpc-dev rsync git lsof lrzsz rsyslog cron logrotate chrony libsqlite3-dev psmisc wget sysv-rc apt-transport-https ca-certificates software-properties-common gnupg ufw"
#        ;;
#    *)
#        echo "${C_FAILURE}Your system Debian ${Debian_version} are not supported!${C_END}"
#        kill -9 $$
#        exit 1
#        ;;
#    esac
#    for Package in ${pkgList}; do
#        apt-get --no-install-recommends -y install ${Package}
#    done
#}

install_dependence_debian() {
    set -e # 启用错误检查

    echo "${C_MSG}检查并清理冲突包...${C_END}"

    if [ "${apache_flag:-y}" == 'y' ]; then
#        systemctl stop apache2
        local apache_packages=(
            "apache2" "apache2-doc" "libsodium-dev" "apache2-utils" "apache2.2-common"
            "apache2.2-bin" "apache2-mpm-prefork" "apache2-doc" "apache2-mpm-worker"
            "php5" "php5-common" "php5-cgi" "php5-cli" "php5-mysql" "php5-curl" "php5-gd"
        )

        for pkg in "${apache_packages[@]}"; do
            if dpkg -l | grep -q "^ii.*${pkg}"; then
                echo "删除 ${pkg}..."
                log_exec apt-get -y purge "${pkg}"
            fi
        done
    fi

    if [[ "${db_option:-y}" =~ ^[1-9]$|^1[0-2]$ ]]; then
        local db_packages=(
            "mysql-client" "mysql-server" "mysql-common"
            "libsodium-dev" "mysql-server-core-5.5" "mysql-client-5.5"
            "mariadb-client" "mariadb-server" "mariadb-common"
        )

        for pkg in "${db_packages[@]}"; do
            if dpkg -l | grep -q "^ii.*${pkg}"; then
                echo "删除 ${pkg}..."
                log_exec apt-get -y purge "${pkg}"
            fi
        done
    fi

    # 清理残留配置
    echo "清理残留配置文件..."
    local orphans=$(dpkg -l | grep ^rc | awk '{print $2}') || true
    if [ -n "${orphans}" ]; then
        echo "${orphans}" | xargs -r dpkg -P
    fi

    echo "${C_MSG}更新系统...${C_END}"
    apt-get -y update                     # 更新包列表
    apt-get -y autoremove                 # 自动删除不需要的包
    apt-get -yf install                   # 修复损坏的依赖关系
    export DEBIAN_FRONTEND=noninteractive # 非交互式安装

    echo "安装安全更新..."
    if [ -f /etc/apt/sources.list ]; then
        grep -h ^deb /etc/apt/sources.list |
            grep security >/tmp/security.sources.list 2>/dev/null || true
        if [ -s /tmp/security.sources.list ]; then
            log_exec apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list
        fi
        rm -f /tmp/security.sources.list
    fi

    # 根据 Debian 版本安装依赖
    echo "${C_MSG}安装依赖包...${C_END}"

    declare -A pkg_versions=(
        [11]="default"
        [12]="default"
        [13]="default"
    )

    if [[ -z "${pkg_versions[${Debian_version}]}" ]]; then
        echo "${C_FAILURE}不支持的 Debian 版本: ${Debian_version}${C_END}"
        return 1
    fi

    # 基础包列表
    # build-essential    # 编译工具链
    # gcc g++ make cmake autoconf  # 编译器和构建工具
    # 编程语言支持
    # libbz2-dev         # bzip2 压缩库
    # libjpeg62-turbo-dev libjpeg-dev  # JPEG 图像处理
    # libpng-dev         # PNG 图像处理
    # libgd-dev          # GD 图形库
    # libxml2-dev        # XML 解析
    # zlib1g-dev         # 压缩库
    # 数据库和网络
    # libc-client2007e-dev  # IMAP 客户端库
    # libcurl4-openssl-dev  # cURL 网络库
    # libkrb5-dev          # Kerberos 认证
    # libssl-dev           # SSL/TLS 支持
    # libsasl2-dev         # SASL 认证
    # 系统工具
    # vim zip unzip tmux htop  # 编辑器和管理工具
    # bc dc                  # 计算器
    # expect                # 自动化交互工具
    # rsync git             # 同步和版本控制
    # lsof lrzsz            # 系统诊断和文件传输
    # cron logrotate        # 定时任务和日志管理
    # ufw                   # 防火墙
    local base_packages=(
        "debian-keyring" "libsodium-dev" "debian-archive-keyring" "libxpm-dev" "build-essential"
        "gcc" "g++" "make" "cmake" "autoconf" "libbz2-dev" "libjpeg62-turbo-dev" "libjpeg-dev"
        "libpng-dev" "libgd-dev" "libxml2" "libxml2-dev" "zlib1g" "zlib1g-dev" "libc6" "libc6-dev"
        "libglib2.0-0" "libglib2.0-dev" "bzip2" "libzip-dev" "libbz2-1.0"
        "libaio-dev" "numactl" "libreadline-dev" "libaio1" "libaio-dev"
        "libcurl3-gnutls" "libcurl4-openssl-dev" "e2fsprogs" "libkrb5-3" "libkrb5-dev" "libltdl-dev"
        "openssl" "net-tools" "libssl-dev" "libtool" "libevent-dev" "bison"
        "re2c" "libsasl2-dev" "libxslt1-dev" "libicu-dev"
        "libexpat1-dev" "libonig-dev" "libtirpc-dev"
        "lrzsz" "libsqlite3-dev" "clang" "automake" 
    )

    # 系统工具
    local tool_packages=(
        "vim" "wget" "curl" "git" "rsync" "tmux" "htop"
        "zip" "unzip" "lsof" "psmisc" "bc" "dc" "expect"
        "cron" "logrotate" "rsyslog" "chrony" "ufw"
        "apt-transport-https" "dpkg-dev" "python3" "python3-pip" "python3-venv" "python3-dev"
        "ca-certificates" "gnupg" "locales" "patch"
    )

    # 安装所有包
    echo "安装开发包..."
    for pkg in "${base_packages[@]}"; do
        install_package_safe "${pkg}"
    done

    echo "安装系统工具..."
    for pkg in "${tool_packages[@]}"; do
        install_package_safe "${pkg}"
    done

    echo "${C_SUCCESS}依赖安装完成！${C_END}"
}

# 安全的包安装函数
install_package_safe() {
    local pkg="$1"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        log_exec apt-get --no-install-recommends -y install "${pkg}"
        if [[ $? -eq 0 ]] then
            echo "${C_SUCCESS}✓ 已安装: ${pkg}${C_END}"
            return 0
        else
            ((retry_count++))
            echo "${C_FAILURE}⚠ 安装 ${pkg} 失败，重试 ${retry_count}/${max_retries}${C_END}"
            sleep 2
        fi
    done

    echo "${C_FAILURE}✗ 安装 ${pkg} 失败${C_END}${C_END}"
    return 1
}

installDepsRHEL() {
    [ -e '/etc/yum.conf' ] && sed -i 's@^exclude@#exclude@' /etc/yum.conf
    if [ "${RHEL_ver}" == '9' ]; then
        if [[ "${Platform}" =~ "rhel" ]]; then
            subscription-manager repos --enable codeready-builder-for-rhel-9-${ARCH}-rpms
            dnf -y install chrony oniguruma-devel rpcgen
        elif [[ "${Platform}" =~ "ol" ]]; then
            dnf config-manager --set-enabled ol9_codeready_builder
            dnf -y install chrony oniguruma-devel rpcgen
        else
            dnf -y --enablerepo=crb install chrony oniguruma-devel rpcgen
        fi
        systemctl enable chronyd
    elif [ "${RHEL_ver}" == '8' ]; then
        if [[ "${Platform}" =~ "rhel" ]]; then
            subscription-manager repos --enable codeready-builder-for-rhel-8-${ARCH}-rpms
            dnf -y install chrony oniguruma-devel rpcgen
        elif [[ "${Platform}" =~ "ol" ]]; then
            dnf config-manager --set-enabled ol8_codeready_builder
            dnf -y install chrony oniguruma-devel rpcgen
        else
            [ -z "$(grep -w epel /etc/yum.repos.d/*.repo)" ] && yum -y install epel-release
            if grep -qw "^\[PowerTools\]" /etc/yum.repos.d/*.repo; then
                dnf -y --enablerepo=PowerTools install chrony oniguruma-devel rpcgen
            elif grep -qw "^\[powertools\]" /etc/yum.repos.d/*.repo; then
                dnf -y --enablerepo=powertools install chrony oniguruma-devel rpcgen
            fi
        fi
        systemctl enable chronyd
    elif [ "${RHEL_ver}" == '7' ]; then
        [ -z "$(grep -w epel /etc/yum.repos.d/*.repo)" ] && yum -y install epel-release
        yum -y groupremove "Basic Web Server" "MySQL Database server" "MySQL Database client"
    fi

    if [ "${RHEL_ver}" == '9' ]; then
        [ ! -e "/usr/lib64/libtinfo.so.5" ] && ln -s /usr/lib64/libtinfo.so.6 /usr/lib64/libtinfo.so.5
        [ ! -e "/usr/lib64/libncurses.so.5" ] && ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
    fi

    echo "${C_MSG}Installing dependencies packages...${C_END}"
    # Install needed packages
    pkgList="perl-FindBin deltarpm libsodium-dev drpm gcc gcc-c++ make cmake autoconf libjpeg libjpeg-dev libjpeg-devel libbz2-dev libjpeg-turbo libjpeg-turbo-devel libpng libpng-devel libxml2 libxml2-devel zlib zlib-devel libzip libzip-devel glibc glibc-devel krb5-devel libcurl4-openssl-dev libc-client libc-client-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel ncurses-compat-libs libaio numactl numactl-libs readline-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel net-tools libxslt-devel libssl-dev libicu-devel libevent-devel libtool libtool-ltdl bison gd-devel vim-enhanced pcre-devel libmcrypt libsqlite3-dev libmcrypt-devel mhash mhash-devel mcrypt zip unzip chrony oniguruma-devel rpcgen sqlite-devel sysstat patch bc expect expat-devel perl-devel oniguruma oniguruma-devel libtirpc-devel nss libnsl rsync rsyslog git lsof lrzsz psmisc wget which libatomic tmux chkconfig firewalld"
    for Package in ${pkgList}; do
        yum -y install ${Package}
    done
    [ ${RHEL_ver} -lt 8 ] >/dev/null 2>&1 && yum -y install cmake3

    yum -y update bash openssl glibc
}

installDepsUbuntu() {
    # Uninstall the conflicting software
    echo "${C_MSG}Removing the conflicting packages...${C_END}"
    if [ "${apache_flag}" == 'y' ]; then
        killall apache2
        pkgList="apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd libncurses5"
        for Package in ${pkgList}; do
            apt-get -y purge ${Package}
        done
        dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
    fi

    if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]]; then
        pkgList="mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
        for Package in ${pkgList}; do
            apt-get -y purge ${Package}
        done
        dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
    fi

    echo "${C_MSG}Installing dependencies packages...${C_END}"
    apt-get -y update
    apt-get -y autoremove
    apt-get -yf install
    export DEBIAN_FRONTEND=noninteractive
    [[ "${Ubuntu_ver}" =~ ^22$ ]] && apt-get -y --allow-downgrades install libicu70=70.1-2 libglib2.0-0=2.72.1-1 libxml2-dev

    # critical security updates
    grep security /etc/apt/sources.list >/tmp/security.sources.list
    apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

    # Install needed packages
    pkgList="libperl-dev pkg-config libsodium-dev libbz2-dev libxslt-dev libjpeg-dev libxml2-dev libxpm-dev libfreetype-dev debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf libjpeg8 libjpeg8-dev libpng-dev libpng12-0 libpng12-dev libpng3 libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3-gnutls libcurl4-gnutls-dev libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl net-tools libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev libcloog-ppl1 bison patch vim zip unzip tmux htop bc dc expect libexpat1-dev rsyslog libonig-dev libtirpc-dev libnss3 rsync git lsof lrzsz chrony psmisc wget sysv-rc apt-transport-https ca-certificates software-properties-common gnupg ufw libiconv-dev libfreetype6-dev libexif-dev gettext-dev libgmp-dev"
    export DEBIAN_FRONTEND=noninteractive
    for Package in ${pkgList}; do
        apt-get --no-install-recommends -y install ${Package}
    done
}

install_dependence_by_src() {
    pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
    if ! command -v icu-config >/dev/null 2>&1 || icu-config --version | grep '^3.' || [ "${Ubuntu_ver}" == "20" ]; then
        log_exec tar xzf icu4c-${icu4c_ver}-src.tgz
        pushd icu/source >/dev/null
        log_exec ./configure --prefix=/usr/local
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        log_exec rm -rf icu
    fi

    if command -v lsof >/dev/null 2>&1; then
        echo 'already initialize' >~/.oneinstack
    else
        echo "${C_FAILURE}${PM} config error parsing file failed${C_END}"
        kill -9 $$
        exit 1
    fi

    popd >/dev/null
}

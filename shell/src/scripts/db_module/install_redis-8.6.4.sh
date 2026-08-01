#!/usr/bin/env bash

install_redis_server() {
    apt install lsb-release curl gpg
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    apt update
    apt install -y redis-server redis-tools

    # 下载官方配置
    # wget -O /etc/redis/redis.conf https://raw.githubusercontent.com/redis/redis/8.0/redis.conf
    cp "/etc/redis/redis.conf" "/etc/redis/redis.conf_bak"
    local redis_conf="/etc/redis/redis.conf"

    # 数据目录，配置项是 dir
    mkdir -p "${redis_install_dir}/var"
    chown -R redis:redis "${redis_install_dir}"
    mkdir -p /var/log/redis
    chown redis:redis /var/log/redis
    # 1、设置密码，设置保护模式，设置密码
    sed -i "s@^# requirepass .*@requirepass $dbredispwd@" $redis_conf
    if ! grep -q "^requirepass" $redis_conf; then
        echo "requirepass $dbredispwd" >> $redis_conf
    fi
    # 保存密码到文件
    echo "$dbredispwd" > /etc/redis/redis_password.txt
    chmod 600 /etc/redis/redis_password.txt
    sudo sed -i 's@^daemonize yes@daemonize no@' $redis_conf

    # 2. 配置绑定地址，这里不要配置 IPv6的地址，可能会有问题，redis默认启动保护模式
    sudo sed -i "s@^# bind 127.0.0.1@bind 127.0.0.1@" $redis_conf
    sudo sed -i 's@^bind 127.0.0.1.*@bind 127.0.0.1@' $redis_conf
    # sed -i "s/^protected-mode yes/protected-mode no/" $REDIS_CONF

    # 3. 禁用危险命令
    cat >> $redis_conf <<'DANGEREOF'

# 禁用危险命令
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command CONFIG ""
rename-command SHUTDOWN ""
rename-command DEL ""
rename-command EVAL ""

# 如果需要使用这些命令，重命名为复杂名称
# rename-command FLUSHDB "FLUSHDB_MY_SECRET_NAME"
# rename-command CONFIG "CONFIG_MY_SECRET_NAME"
DANGEREOF

    # 4. 配置持久化
    sed -i "s/^appendonly no/appendonly yes/" $redis_conf
    sed -i "s/^# appendfsync everysec/appendfsync everysec/" $redis_conf
    sed -i "s/^# aof-use-rdb-preamble no/aof-use-rdb-preamble yes/" $redis_conf

    # 5. 内存设置

    sudo sed -i 's@pidfile.*@pidfile /var/run/redis/redis.pid@' /etc/redis/redis.conf
    sudo sed -i "s@logfile.*@logfile /var/log/redis/redis-server.log@" /etc/redis/redis.conf
    sudo sed -i "s@^dir.*@dir ${redis_install_dir}/var@" /etc/redis/redis.conf

    sudo sed -i 's/^repl-diskless-sync yes/repl-diskless-sync no/' /etc/redis/redis.conf



    # 1. 添加 supervised 设置，systemd + daemonize no + supervised systemd，systemctl 管理启动，组合配置
    if grep -q '^supervised' /etc/redis/redis.conf; then
        sudo sed -i 's/^supervised.*/supervised systemd/' /etc/redis/redis.conf
    else
        echo "supervised systemd" >> /etc/redis/redis.conf
    fi
    # disable-thp 默认值在6.0+就是yes
    sudo sed -i 's/^disable-thp.*/disable-thp yes/' /etc/redis/redis.conf

    ##########################################################################################

    redis_maxmemory=$(expr $Mem / 8)000000
    [ -z "$(grep ^maxmemory $redis_conf)" ] && sed -i "s@maxmemory <bytes>@maxmemory <bytes>\nmaxmemory $(expr $Mem / 8)000000@" $redis_conf
    log_info "Redis-server installed successfully!"
    popd >/dev/null
    id -u redis >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin redis

    systemctl enable redis-server

    # 这个注释需要打开
    [ -z "`grep 'vm.overcommit_memory' /etc/sysctl.conf`" ] && echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
    sysctl -p
    systemctl start redis-server
}

# 这个源码安装行不通。
install_redis_server_by_src() {
    pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
    #    cargo: not found，这一步非常耗时，主要是下载速度的问题。
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    tar xzf redis-${redis_ver}.tar.gz
    pushd redis-${redis_ver} >/dev/null

    # 源码安装要不得，主要是 github 上的库是下载不下来。
    export GIT_HTTP_MAX_REQUESTS=64
    export GIT_HTTP_LOW_SPEED_LIMIT=0
    export GIT_HTTP_LOW_SPEED_TIME=999999

    export BUILD_TLS=yes
    export BUILD_WITH_MODULES=yes
    export INSTALL_RUST_TOOLCHAIN=yes
    make -j ${THREAD} PREFIX=${redis_install_dir} all
    make PREFIX=${redis_install_dir} install

    if [ -f "src/redis-server" ]; then
        mkdir -p ${redis_install_dir}/{bin,etc,var}
        /bin/cp src/{redis-benchmark,redis-check-aof,redis-check-rdb,redis-cli,redis-sentinel,redis-server} ${redis_install_dir}/bin/
        /bin/cp redis.conf ${redis_install_dir}/etc/

        ln -s ${redis_install_dir}/bin/* /usr/local/bin/
        sed -i 's@pidfile.*@pidfile /var/run/redis/redis.pid@' ${redis_install_dir}/etc/redis.conf
        sed -i "s@logfile.*@logfile ${redis_install_dir}/var/redis.log@" ${redis_install_dir}/etc/redis.conf
        sed -i "s@^dir.*@dir ${redis_install_dir}/var@" ${redis_install_dir}/etc/redis.conf
        sed -i 's@daemonize no@daemonize yes@' ${redis_install_dir}/etc/redis.conf
        sed -i "s@^# bind 127.0.0.1@bind 127.0.0.1@" ${redis_install_dir}/etc/redis.conf
        redis_maxmemory=$(expr $Mem / 8)000000
        [ -z "$(grep ^maxmemory ${redis_install_dir}/etc/redis.conf)" ] && sed -i "s@maxmemory <bytes>@maxmemory <bytes>\nmaxmemory $(expr $Mem / 8)000000@" ${redis_install_dir}/etc/redis.conf
        echo "${CSUCCESS}Redis-server installed successfully! ${CEND}"
        popd >/dev/null
        rm -rf redis-${redis_ver}
        id -u redis >/dev/null 2>&1
        [ $? -ne 0 ] && useradd -M -s /sbin/nologin redis
        chown -R redis:redis ${redis_install_dir}/{var,etc}

        /bin/cp ../init.d/redis-server.service /lib/systemd/system/
        sed -i "s@/usr/local/redis@${redis_install_dir}@g" /lib/systemd/system/redis-server.service
        systemctl enable redis-server
        #[ -z "`grep 'vm.overcommit_memory' /etc/sysctl.conf`" ] && echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
        #sysctl -p
        systemctl start redis-server
    else
        rm -rf ${redis_install_dir}
        echo "${CFAILURE}Redis-server install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        kill -9 $$
        exit 1
    fi
    popd >/dev/null
}

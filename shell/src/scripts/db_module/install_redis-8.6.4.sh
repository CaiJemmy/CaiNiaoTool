#!/usr/bin/env bash

install_redis_server() {
    apt install lsb-release curl gpg
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    apt update
    apt install -y redis

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
}

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

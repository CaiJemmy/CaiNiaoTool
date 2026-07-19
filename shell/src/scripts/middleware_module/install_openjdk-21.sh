#!/bin/bash

install_openJDK21() {
    . /etc/profile
    if command -v javac &> /dev/null; then
        log_info "JDK installed successfully!"
        return 0
    fi

    pushd ${CAINIAOTOOL_ROOT}/src >/dev/null

    apt-get update
    apt-get -y install openjdk-21-jdk

    # 设置JAVA_HOME
    if [ -d "/usr/lib/jvm/java-21-openjdk" ]; then
        JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
    elif [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
        JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    fi

    # 配置环境变量
    if [ -n "${JAVA_HOME:-}" ]; then
        [ -z "$(grep ^'export JAVA_HOME=' /etc/profile)" ] && echo "export JAVA_HOME=${JAVA_HOME}" >>/etc/profile
        [ -z "$(grep ^'export CLASSPATH=' /etc/profile)" ] && echo "export CLASSPATH=.:\${JAVA_HOME}/lib/dt.jar:\${JAVA_HOME}/lib/tools.jar" >>/etc/profile
        [ -z "$(grep ^'export PATH=' /etc/profile)" ] && echo "export PATH=\${JAVA_HOME}/bin:\$PATH" >>/etc/profile
        [ -n "$(grep ^'export PATH=' /etc/profile)" -a -z "$(grep ${JAVA_HOME} /etc/profile)" ] && sed -i "s@^export PATH=\(.*\)@export PATH=\${JAVA_HOME}/bin:\1@" /etc/profile
        . /etc/profile

        # 验证安装
        java -version
        if [ $? -eq 0 ]; then
            log_info "OpenJDK 21 installed successfully!"
        else
            log_error "OpenJDK 21 install failed, Please Contact the author!"
            kill -9 $$
            exit 1
        fi
    else
        log_error "OpenJDK 21 install failed, Please Contact the author!"
        kill -9 $$
        exit 1
    fi

    popd >/dev/null
}

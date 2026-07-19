#!/bin/bash

install_tomcat11() {
    if [[ -e "/lib/systemd/system/tomcat.service" ]]; then
        log_info "tomcat installed successfully!"
        return 0
    fi

    pushd ${CAINIAOTOOL_ROOT}/src >/dev/null
    . /etc/profile
    if ! id -g ${run_group} >/dev/null 2>&1; then
        groupadd ${run_group}
    fi
    if ! id -u ${run_user} >/dev/null 2>&1; then
        useradd -g ${run_group} -M -s /sbin/nologin ${run_user}
    fi
    { [ -z "$(grep ^${run_user} /etc/passwd | grep '/bin/bash')" ] && usermod -g ${run_group} -s /bin/bash ${run_user}; }

    # install apr
    if [ ! -e "${apr_install_dir}/bin/apr-1-config" ]; then
        tar xzf apr-${apr_ver}.tar.gz
        pushd apr-${apr_ver} >/dev/null
        log_exec ./configure --prefix=${apr_install_dir}
        log_exec make -j ${THREAD}
        log_exec make install
        popd >/dev/null
        rm -rf apr-${apr_ver}
    fi

    [ -d ${tomcat_install_dir} ] && rm -fr ${tomcat_install_dir}
    tar xzf apache-tomcat-${tomcat11_ver}.tar.gz
    mv apache-tomcat-${tomcat11_ver} ${tomcat_install_dir}
    rm -rf ${tomcat_install_dir}/webapps/{docs,examples,host-manager,manager,ROOT/*}

    if [ ! -e "${tomcat_install_dir}/conf/server.xml" ]; then
        rm -rf ${tomcat_install_dir}
        log_error "Tomcat install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        kill -9 $$
        exit 1
    fi

    tar xzf tomcat-native-${tomcat_native_ver}-src.tar.gz
    pushd tomcat-native-${tomcat_native_ver}-src/native >/dev/null

    log_exec ./configure --prefix=${apr_install_dir} --with-apr=${apr_install_dir} --with-ssl=${openssl_install_dir}
    log_exec make -j ${THREAD}
    log_exec make install
    popd >/dev/null

    rm -rf tomcat-native-${tomcat_native_ver}-src
    if [ -e "${apr_install_dir}/lib/libtcnative-2.la" ]; then
        [ ${Mem} -le 768 ] && let Xms_Mem="${Mem}/3" || Xms_Mem=256
        let XmxMem="${Mem}/2"
        cat >${tomcat_install_dir}/bin/setenv.sh <<EOF
JAVA_OPTS='-Djava.security.egd=file:/dev/./urandom -server -Xms${Xms_Mem}m -Xmx${XmxMem}m -Dfile.encoding=UTF-8'
CATALINA_OPTS="-Djava.library.path=${apr_install_dir}/lib"
# -Djava.rmi.server.hostname=$IPADDR
# -Dcom.sun.management.jmxremote.password.file=\$CATALINA_BASE/conf/jmxremote.password
# -Dcom.sun.management.jmxremote.access.file=\$CATALINA_BASE/conf/jmxremote.access
# -Dcom.sun.management.jmxremote.ssl=false"
EOF
        chmod 750 ${tomcat_install_dir}/bin/setenv.sh
        /bin/mv ${tomcat_install_dir}/conf/server.xml{,_bk}

        /bin/cp ${CAINIAOTOOL_ROOT}/config/server.xml ${tomcat_install_dir}/conf
        sed -i "s@/usr/local/tomcat@${tomcat_install_dir}@g" ${tomcat_install_dir}/conf/server.xml

        if [[ ! -e "${nginx_install_dir}/sbin/nginx" && ! -e "${tengine_install_dir}/sbin/nginx" && ! -e "${openresty_install_dir}/nginx/sbin/nginx" && ! -e "${apache_install_dir}/bin/httpd" ]]; then
            if [ "${PM}" == 'yum' ]; then
                if [ "$(firewall-cmd --state)" == "running" ]; then
                    firewall-cmd --permanent --zone=public --add-port=8080/tcp
                    firewall-cmd --reload
                fi
            elif [ "${PM}" == 'apt-get' ]; then
                if ufw status | grep -wq active; then
                    ufw allow 8080/tcp
                fi
            fi
        fi

        [ ! -d "${tomcat_install_dir}/conf/vhost" ] && mkdir ${tomcat_install_dir}/conf/vhost
        cat >${tomcat_install_dir}/conf/vhost/localhost.xml <<EOF
<Host name="localhost" appBase="${wwwroot_dir}/default" unpackWARs="true" autoDeploy="true">
  <Context path="" docBase="${wwwroot_dir}/default" reloadable="false" crossContext="true"/>
  <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
    prefix="localhost_access_log" suffix=".txt" pattern="%h %l %u %t &quot;%r&quot; %s %b" />
  <Valve className="org.apache.catalina.valves.RemoteIpValve" remoteIpHeader="X-Forwarded-For"
    protocolHeader="X-Forwarded-Proto" protocolHeaderHttpsValue="https"/>
</Host>
EOF
        # logrotate tomcat catalina.out
        cat >/etc/logrotate.d/tomcat <<EOF
${tomcat_install_dir}/logs/catalina.out {
  daily
  rotate 5
  missingok
  dateext
  compress
  notifempty
  copytruncate
}
EOF
        [ -z "$(grep '<user username="admin" password=' ${tomcat_install_dir}/conf/tomcat-users.xml)" ] && sed -i "s@^</tomcat-users>@<role rolename=\"admin-gui\"/>\n<role rolename=\"admin-script\"/>\n<role rolename=\"manager-gui\"/>\n<role rolename=\"manager-script\"/>\n<user username=\"admin\" password=\"$(cat /dev/urandom | head -1 | md5sum | head -c 10)\" roles=\"admin-gui,admin-script,manager-gui,manager-script\"/>\n</tomcat-users>@" ${tomcat_install_dir}/conf/tomcat-users.xml
        cat >${tomcat_install_dir}/conf/jmxremote.access <<EOF
monitorRole   readonly
controlRole   readwrite \
              create javax.management.monitor.*,javax.management.timer.* \
              unregister
EOF
        cat >${tomcat_install_dir}/conf/jmxremote.password <<EOF
monitorRole  ${jmxremotepwd}
# controlRole   R&D
EOF
        chown -R ${run_user}:${run_group} ${tomcat_install_dir}

        /bin/cp "${CAINIAOTOOL_ROOT}/init.d/tomcat.service" "/lib/systemd/system/"
        sed -i "s@/usr/local/tomcat@${tomcat_install_dir}@g" /lib/systemd/system/tomcat.service
        sed -i "s@^User=.*@User=${run_user}@" /lib/systemd/system/tomcat.service
        sed -i "s@^Group=.*@Group=${run_group}@" /lib/systemd/system/tomcat.service

        log_info "Tomcat installed successfully!"
        rm -rf apache-tomcat-${tomcat11_ver}
    else
        popd >/dev/null
        log_error "Tomcat install failed, Please contact the author!" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        kill -9 $$
        exit 1
    fi
    service tomcat start
    popd >/dev/null
}

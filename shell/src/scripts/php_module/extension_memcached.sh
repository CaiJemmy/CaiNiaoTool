#!/bin/bash

Install_memcached_server() {
  pushd ${oneinstack_dir}/src > /dev/null
  # memcached server
  id -u memcached >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -M -s /sbin/nologin memcached

  tar xzf memcached-${memcached_ver}.tar.gz
  pushd memcached-${memcached_ver} > /dev/null
  [ ! -d "${memcached_install_dir}" ] && mkdir -p ${memcached_install_dir}
  ./configure --prefix=${memcached_install_dir}
  make -j ${THREAD} && make install
  popd > /dev/null
  if [ -f "${memcached_install_dir}/bin/memcached" ]; then
    echo "${CSUCCESS}memcached installed successfully! ${CEND}"
    rm -rf memcached-${memcached_ver}
    ln -s ${memcached_install_dir}/bin/memcached /usr/bin/memcached
    /bin/cp ../init.d/memcached.service /lib/systemd/system/
    systemctl enable memcached
    systemctl start memcached
    rm -rf memcached-${memcached_ver}
  else
    rm -rf ${memcached_install_dir}
    echo "${CFAILURE}memcached-server install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi
  popd > /dev/null
}

Install_pecl_memcached() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    # php_module memcached extension
    tar xzf libmemcached-${libmemcached_ver}.tar.gz
    patch -d libmemcached-${libmemcached_ver} -p0 < libmemcached-build.patch
    pushd libmemcached-${libmemcached_ver} > /dev/null
    [ "${PM}" == 'yum' ] && yum -y install cyrus-sasl-devel
    [ "${PM}" == 'apt-get' ] && sed -i "s@lthread -pthread -pthreads@lthread -lpthread -pthreads@" ./configure
    ./configure --with-memcached=${memcached_install_dir}
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf libmemcached-${libmemcached_ver}

    if [ "$(${php_install_dir}/bin/php-config --version | awk -F. '{print $1}')" == '5' ]; then
      tar xzf memcached-${pecl_memcached_oldver}.tgz
      pushd memcached-${pecl_memcached_oldver} > /dev/null
    else
      tar xzf memcached-${pecl_memcached_ver}.tgz
      pushd memcached-${pecl_memcached_ver} > /dev/null
    fi
    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/memcached.so" ]; then
      cat > ${php_install_dir}/etc/php.d/05-memcached.ini << EOF
extension=memcached.so
memcached.use_sasl=1
EOF
      echo "${CSUCCESS}PHP memcached module installed successfully! ${CEND}"
      rm -rf memcached-${pecl_memcached_oldver} memcached-${pecl_memcached_ver}
    else
      echo "${CFAILURE}PHP memcached module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_memcached() {
  if [ -e "${php_install_dir}/etc/php.d/05-memcached.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/05-memcached.ini
    echo; echo "${CMSG}PHP memcached module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP memcached module does not exist! ${CEND}"
  fi
}

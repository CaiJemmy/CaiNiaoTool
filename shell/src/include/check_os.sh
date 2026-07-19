#!/bin/bash

[[ -n "${_CHECK_OS_SH:-}" ]] && return
readonly _CHECK_OS_SH=1

if [ -e "/etc/os-release" ]; then
    . /etc/os-release
else
    echo "${C_FAILURE}/etc/os-release does not exist! ${C_END}"
    kill -9 $$
    exit 1
fi

# Get OS Version
Platform=${ID,,}
VERSION_MAIN_ID=${VERSION_ID%%.*}
ARCH=$(arch)
if [[ "${Platform}" =~ ^debian$ ]]; then
    PM=apt-get
    Family=debian
    Debian_version=${VERSION_MAIN_ID}
else
    echo "${C_FAILURE}Does not support this OS ${C_END}"
    kill -9 $$
    exit 1
fi

# Check OS Version
if [ ${Debian_version} -lt 11 ] >/dev/null 2>&1; then
    echo "${C_FAILURE}Does not support this OS, Please install Debian 11+ ${C_END}"
    kill -9 $$
    exit 1
fi

command -v gcc >/dev/null 2>&1 || $PM -y install gcc
gcc_ver=$(gcc -dumpversion | awk -F. '{print $1}')

[ ${gcc_ver} -lt 5 ] >/dev/null 2>&1 && redis_ver=${redis_oldver}

if [ "$(uname -r | awk -F- '{print $3}' 2>/dev/null)" == "Microsoft" ]; then
    Wsl=true
fi

if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "64" ]; then
    SYS_ARCH=amd64    #openjdk
    SYS_ARCH_i=x86-64 #ioncube
    SYS_ARCH_n=x64    #nodejs
else
    echo "${C_WARNING}32-bit OS are not supported! ${C_END}"
    kill -9 $$
    exit 1
fi

THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)

# Percona binary: https://docs.percona.com/percona-server/5.7/installation/binary-tarball.html
sslLibVer=ssl102


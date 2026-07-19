icu 卸载

```shell
# 1./usr/local/lib
cd /usr/local/lib
rm -fr icu
rm -fr libicudata.so
rm -fr libicudata.so.63
rm -fr libicudata.so.63.1
rm -fr libicui18n.so
rm -fr libicui18n.so.63
rm -fr libicui18n.so.63.1
rm -fr libicuio.so
rm -fr libicuio.so.63
rm -fr libicuio.so.63.1
rm -fr libicutest.so
rm -fr libicutest.so.63
rm -fr libicutest.so.63.1
rm -fr libicutu.so
rm -fr libicutu.so.63
rm -fr libicutu.so.63.1
rm -fr libicuuc.so
rm -fr libicuuc.so.63
rm -fr libicuuc.so.63.1

# 2./usr/local/share/
rm -fr /usr/local/share/icu

# 3./usr/local/bin/
cd /usr/local/bin && rm -f makeconv
cd /usr/local/bin && rm -f genrb
cd /usr/local/bin && rm -f derb
cd /usr/local/bin && rm -f genbrk
cd /usr/local/bin && rm -f gencnval
cd /usr/local/bin && rm -f icuinfo
cd /usr/local/bin && rm -f pkgdata
cd /usr/local/bin && rm -f gencfu
cd /usr/local/bin && rm -f gendict
cd /usr/local/bin && rm -f uconv
cd /usr/local/bin && rm -f icu-config

# 4./usr/local/include/
rm -fr /usr/local/include/unicode

# 5./usr/local/etc/

# 6.~/.local/

```

## mysql 安装过程中失败处理
```shell
service mysqld stop && rm -fr /data/mysql && rm -fr /usr/local/mysql
```

```shell
root@VM-0-16-debian:~/cainiaotool/shell/src# systemctl status mysqld.service
× mysqld.service - LSB: start and stop MySQL
     Loaded: loaded (/etc/init.d/mysqld; generated)
     Active: failed (Result: exit-code) since Sat 2026-07-18 01:07:55 CST; 1min 15s ago
   Duration: 14min 4.622s
 Invocation: 1350563f28fe4c6dba783feccdc2ab90
       Docs: man:systemd-sysv-generator(8)
    Process: 2887857 ExecStart=/etc/init.d/mysqld start (code=exited, status=1/FAILURE)
      Tasks: 36 (limit: 4408)
     Memory: 332.2M (peak: 592.8M)
        CPU: 2.023s
     CGroup: /system.slice/mysqld.service
             ├─2878005 /bin/sh /usr/local/mysql/bin/mysqld_safe --datadir=/data/mysql --pid-file=/data/mysql/mysql.pid
             └─2878820 /usr/local/mysql/bin/mysqld --basedir=/usr/local/mysql --datadir=/data/mysql --plugin-dir=/usr/local/mysql/lib/plugin --user=mysql>

Jul 18 01:07:50 VM-0-16-debian systemd[1]: Starting mysqld.service - LSB: start and stop MySQL...
Jul 18 01:07:50 VM-0-16-debian mysqld[2887857]: Starting MySQL
Jul 18 01:07:55 VM-0-16-debian mysqld[2887857]: .....The server quit without updating PID file (/data/mysql/mysql.pid). ... failed!
Jul 18 01:07:55 VM-0-16-debian systemd[1]: mysqld.service: Control process exited, code=exited, status=1/FAILURE
Jul 18 01:07:55 VM-0-16-debian systemd[1]: mysqld.service: Failed with result 'exit-code'.
Jul 18 01:07:55 VM-0-16-debian systemd[1]: mysqld.service: Unit process 2878005 (mysqld_safe) remains running after unit stopped.
Jul 18 01:07:55 VM-0-16-debian systemd[1]: mysqld.service: Unit process 2878820 (mysqld) remains running after unit stopped.
Jul 18 01:07:55 VM-0-16-debian systemd[1]: Failed to start mysqld.service - LSB: start and stop MySQL.
Jul 18 01:07:55 VM-0-16-debian systemd[1]: mysqld.service: Consumed 1.692s CPU time, 592.8M memory peak.


## 处理方法
# 1. 停止所有 MySQL 进程
echo "停止 MySQL 进程..."
pkill -9 mysqld 2>/dev/null
pkill -9 mysqld_safe 2>/dev/null
sleep 3

# 2. 清理旧文件
echo "清理旧文件..."
rm -f /data/mysql/mysql.pid /tmp/mysql.sock /data/mysql/*.lock 2>/dev/null
```
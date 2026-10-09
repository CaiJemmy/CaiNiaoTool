## 架构拓扑图

```shell
                          ┌─────────────────┐
                          │   HAProxy/      │
                          │   Nginx/        │
                          │   ProxySQL      │
                          │   (读写分离)     │
                          └────────┬────────┘
                                   │
                ┏━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━┓
                ┃              VIP (Keepalived)      ┃
                ┗━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┛
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  MySQL Master │◄─────┤  MySQL Slave1 │      │  MySQL Slave2 │
│   (Primary)   │      │   (Replica)   │      │   (Replica)   │
│               │      │               │      │               │
│  读写操作      │──────►  只读操作      │      │   只读操作     │
│               │      │               │      │               │
│  Binlog       │      │  Relay Log    │      │   Relay Log   │
└───────┬───────┘      └───────────────┘      └───────────────┘
        │                                              ▲
        │                                              │
        └──────────────────────────────────────────────┘
                    (Slave2 也从 Master 复制)

        ┌──────────────────────────────────────────────┐
        │         共享存储 / 独立 Volume                │
        │  • Master Volume:  master-data               │
        │  • Slave1 Volume:  slave1-data               │
        │  • Slave2 Volume:  slave2-data               │
        │  • Backup Volume:  mysql-backup              │
        └──────────────────────────────────────────────┘

        ┌──────────────────────────────────────────────┐
        │            监控和备份组件                      │
        │  • Prometheus + MySQL Exporter               │
        │  • Grafana Dashboard                         │
        │  • Percona XtraBackup / mysqldump            │
        │  • Alertmanager (告警)                       │
        └──────────────────────────────────────────────┘
```

## 目录结构

```shell
mysql-cluster/
├── docker-compose.yml              # 主编排文件
├── .env                            # 环境变量配置
├── mysql/
│   ├── master/
│   │   ├── conf/
│   │   │   └── my.cnf              # Master 配置
│   │   ├── data/                   # Master 数据目录（挂载点）
│   │   ├── init/                   # 初始化脚本
│   │   │   └── 01-init.sql
│   │   └── backup/                 # 备份目录
│   ├── slave1/
│   │   ├── conf/
│   │   │   └── my.cnf              # Slave1 配置
│   │   ├── data/                   # Slave1 数据目录
│   │   └── init/
│   └── slave2/
│       ├── conf/
│       │   └── my.cnf              # Slave2 配置
│       ├── data/                   # Slave2 数据目录
│       └── init/
├── proxysql/
│   ├── proxysql.cnf                # ProxySQL 配置
│   └── scripts/
│       └── init-proxysql.sh        # ProxySQL 初始化脚本
├── haproxy/
│   └── haproxy.cfg                 # HAProxy 配置
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml          # Prometheus 配置
│   ├── grafana/
│   │   ├── provisioning/
│   │   └── dashboards/
│   └── alertmanager/
│       └── config.yml              # 告警配置
├── scripts/
│   ├── setup-replication.sh        # 自动配置主从复制
│   ├── health-check.sh             # 健康检查脚本
│   ├── backup.sh                   # 备份脚本
│   ├── failover.sh                 # 故障转移脚本
│   └── restore.sh                  # 恢复脚本
└── README.md                       # 部署文档
```


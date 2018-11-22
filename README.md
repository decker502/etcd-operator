## 目标

目前主流的发布系统，大都有隐含的依赖项，部署系统前要安装这些依赖，使部署难度增加，生产环境系统不够纯净，而且操作系统升级时，还需要考虑依赖项的兼容问题。

特性:
- 基于原生操作系统的环境，即可一键发布
- 极其轻量的启动
- 生产环境高可用
- 支持多环境配置
- 尽量少的依赖项，包括发布机和目标机
- 支持主流 Linux 系操作系统
- 发布后自动检查集群健康
- 必要的运维命令(备份、恢复、销毁)

## 依赖

### 发布机

- Linux bash
- Openssl
- SSH
- Rsync

### 目标机

- Linux bash
- SSH
- Systemd

## 环境配置

- 发布机到目标机配置 ssh 无密码连接

- env目录下配置环境相应变量，例如开发环境 dev.sh：

```bash
#!/usr/bin/env bash

export ETCD_DOMAINS=("www.do.com" "www2.do.com")
export ETCD_NODES=("10.200.0.15 10.200.0.14 10.200.0.13")
```

可配置的变量参见　config-default.sh　中的定义

- 准备 ETCD　二进制文件 { etcd, etcdctl }，置于 binaries目录下

## 创建/启动集群

```bash
# env　为变量
bash etcd-up.sh ${env}
```

例如：

```bash
bash etcd-up.sh dev
```

## 备份集群

```bash
# env　为变量
bash etcd-backup.sh ${env}
```

例如：

```bash
bash etcd-backup.sh dev
```

## 恢复集群

使用之前备份的数据恢复集群数据

```bash
# env　为变量
bash etcd-restore.sh ${env}
```

例如：

```bash
bash etcd-up.sh dev
```

## 销毁集群

### **注意：此操作将清除集群所有数据，仅用于开发测试，请谨慎使用**


```bash
bash etcd-down.sh ${env}
```

## 调试模式

```
bash -x etcd-up.sh dev
```

## 参考项目

[kubernetes](https://github.com/kubernetes/kubernetes)

[kubespray](https://github.com/kubernetes-incubator/kubespray)

## License

Code is distributed under MIT license, feel free to use it in your proprietary projects as well.
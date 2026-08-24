# 企业版架构

## 运行链路

```text
systemd
  │
  ├─ 启动 enterprise/src/miniops-monitor.sh --loop
  │
  ├─ 读取 /etc/default/miniops-monitor-enterprise
  │
  ├─ 读取 /proc/loadavg、free、df
  │
  ├─ 计算 CPU 负载比、内存和磁盘百分比
  │
  └─ 输出 key=value 日志到 stdout
          │
          └─ journald → journalctl
```

## 工程闭环

```text
行为契约
   ↓
Bash 实现与单元/Bats/故障注入测试
   ↓
GitHub Actions（Ubuntu 22.04/24.04）
   ↓
确定性打包与 SHA256 artifact
   ↓
enterprise-v0.1.1 Release
   ↓
Ubuntu 22.04/24.04 systemd 实机 smoke
```

## 边界

- Bash 负责本机采集、配置、阈值和日志。
- systemd 负责启动、重启、低权限运行和日志接管。
- 安装器负责依赖检查、文件部署、unit 注册和失败回滚。
- 测试通过 `MINIOPS_PROC_ROOT`、fake 命令和临时安装根目录隔离宿主机状态。
- CI 负责静态检查、行为测试、故障注入和发布包验证。

配置的生效路径为：默认值 → `/etc/default/miniops-monitor-enterprise` → CLI 参数。日志通过 stdout 交给 journald，稳定字段为 `timestamp`、`schema_version`、`level` 和 `event`。

## 技术边界

当前选择 Bash + systemd 是有意的：项目重点是 Linux 服务生命周期、权限、配置、日志和可恢复发布，而不是构建通用监控平台。Prometheus、多机调度、容器、数据库和复杂告警状态机均不在当前边界内，相关想法进入 backlog 后再按真实复杂度评估。

## 错误路径

```text
配置错误 / 采集失败
          ↓
结构化 ERROR 日志
          ↓
退出码 1
          ↓
systemd Restart=on-failure
```

## 为什么暂不拆分模块

当前主脚本仍处于可测试范围，职责可以通过函数边界隔离。只有当脚本超过复杂度阈值、测试无法隔离或出现真实职责耦合时，才拆分配置、采集和日志模块。

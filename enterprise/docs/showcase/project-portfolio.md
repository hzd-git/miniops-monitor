# MiniOps Monitor Enterprise 项目归档

## 项目简介

MiniOps Monitor Enterprise 是一个面向 Linux 单机环境的小型资源监控服务。它的价值不在于提供完整的监控平台，而在于用一个规模可控的 Bash/systemd 项目演示企业软件从需求、设计、实现、测试、持续集成、发布到实机验收的完整闭环。

初始项目是教学性质的 Bash 脚本，能够采集本机资源并输出结果，但在配置边界、错误处理、安装卸载、测试隔离、发布一致性和真实 systemd 验收方面缺少可追溯的工程约束。

企业化改造的目标是：

- 冻结 CLI、退出码、服务名、配置格式和日志事件等行为契约；
- 让安装、升级、卸载和失败恢复具备可诊断、可验证的路径；
- 建立单元测试、Bats、故障注入、CI 和发布验收体系；
- 通过 Ubuntu 22.04/24.04 的真实 systemd 验收证明关键生命周期行为；
- 保持方案简单，避免为了“企业化”提前引入不必要的平台组件。

## 技术架构

### 服务模型

企业版由 Bash 监控脚本和 systemd unit 组成：

```text
systemd
  └─ miniops-monitor-enterprise.service
       └─ enterprise/src/miniops-monitor.sh
            ├─ 读取配置
            ├─ 校验参数
            ├─ 采集 CPU、内存、磁盘和负载
            └─ 输出结构化日志到 stdout/journald
```

安装脚本负责部署 unit、安装目录和配置；systemd 负责服务生命周期、重启策略、权限限制和日志接管。服务采用 `DynamicUser=yes`、`NoNewPrivileges=yes` 等已验证的基础约束。

### 配置与行为契约

配置文件位于：

```text
/etc/default/miniops-monitor-enterprise
```

配置加载遵循稳定的 Linux 服务方式。参数经过格式和范围校验；非法配置以非零退出和结构化错误日志暴露原因，不继续运行在不确定状态。

稳定日志至少包含：

```text
timestamp=
schema_version=1
level=
event=
```

事件名、级别、字段和退出码记录在 [行为契约](../behavior-contract.md) 中。实现、测试和运维文档以该契约为共同边界。

### 测试结构

测试按风险分层：

- unit：验证参数、配置和核心判断；
- Bats/CLI：验证用户可见的命令行为和退出码；
- fake/fixture：隔离宿主机状态；
- fault injection：模拟命令缺失、权限错误、systemd 查询失败、停止/禁用/重载失败和回滚路径；
- systemd-analyze：检查 unit 语法；
- Ubuntu 实机验收：验证真实 systemd 生命周期、journald、安装恢复和卸载残留。

测试重点是异常路径是否可重复验证，而不是仅追求一个覆盖率数字。

### CI、打包与发布

GitHub Actions 在 Ubuntu 22.04 和 24.04 矩阵中执行 ShellCheck、shfmt、unit/Bats、故障注入、package-test、`make verify` 和 unit 语法检查。发布流程从经过验证的 commit 生成确定性 tar 包，并同时生成 SHA256 清单。

正式 v0.1.1 发布链路为：

```text
PR #5 P1 修复
  ↓
RELEASE_COMMIT 7c40469590a66113f8d2f81481da9040e9359411
  ↓
main CI/package
  ↓
enterprise-v0.1.1
  ↓
tag workflow / GitHub Release
  ↓
Ubuntu 22.04/24.04 smoke
```

正式 Release：

- [enterprise-v0.1.1 Release](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)
- [main workflow 32686257505](https://github.com/hzd-git/miniops-monitor/actions/runs/32686257505)
- [tag workflow 32686677270](https://github.com/hzd-git/miniops-monitor/actions/runs/32686677270)
- Release tar.gz SHA256：`80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f`

## 关键工程难点

### 1. systemd 249/255 缺失 unit 兼容性

Ubuntu 22.04/systemd 249 在 unit 不存在时，`systemctl is-enabled` 可能返回多行诊断文本；Ubuntu 24.04/systemd 255 更常见的是 `not-found`。如果脚本依赖某个版本的完整输出，就可能把首次安装时正常的“unit 尚不存在”误判为 systemd 查询异常。

修复采用稳定的存在性判断：

```bash
systemctl show miniops-monitor-enterprise.service --property=LoadState --value
```

只有查询成功且精确返回 `not-found` 才进入缺失 unit 路径。查询失败、空输出或格式异常继续按真实 systemd/D-Bus 故障处理；已存在 unit 再解析 `is-enabled` 状态。该逻辑同时覆盖首次安装和不存在服务时的卸载幂等性。

### 2. 安装事务与失败回滚

安装和卸载涉及 unit、安装目录、配置以及 systemd 状态，不能把关键 `stop`、`disable`、`daemon-reload` 失败静默忽略。脚本在删除运行文件前确认服务已经停止；失败时保留可恢复文件并输出 `systemctl status`、`journalctl` 等排查入口。

### 3. 故障注入

通过 fake systemctl 和可控故障场景覆盖：

- 服务不存在；
- stop 或 disable 失败；
- daemon-reload 失败；
- systemd/D-Bus 查询失败；
- 已安装文件在失败后保留；
- 回滚后服务状态可恢复。

这使安装器测试能证明“正常缺失状态被接受”和“真实系统故障不会被吞掉”是两个不同结论。

### 4. 双 Ubuntu LTS 实机验收

Ubuntu 22.04/systemd 249 与 Ubuntu 24.04/systemd 255 均完成正式 Release 资产校验、安装、enable/start/restart/stop/disable、journald、配置错误恢复、受控启动失败恢复、默认卸载、purge 卸载和残留检查。两台主机结果均为 PASS。

## 最终成果

- 正式版本：`enterprise-v0.1.1`
- P1 修复：systemd 249/255 缺失 unit 状态判断兼容性
- PR #5：已合并，完成 P1 修复交付
- main CI、tag workflow、artifact 和 GitHub Release：已通过
- Release tar.gz SHA256：`80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f`
- Ubuntu 22.04/systemd 249：PASS
- Ubuntu 24.04/systemd 255：PASS
- Release 资产可独立下载并在新目录通过 SHA256 校验

## 能力边界与非目标

当前项目可以证明小型 Linux 服务的工程化交付能力，但不宣称已经是多机监控平台或完整生产监控系统。明确非目标包括：

- 多机采集与集中式控制面；
- Prometheus 指标服务和长期时序存储；
- 容器编排与多节点部署；
- 数据库和复杂告警状态机；
- 高可用控制面、SLA 和大规模容量验证。

这些能力只有在真实需求和复杂度出现后，才应进入 backlog，并重新评估 Bash 是否仍是合适的实现语言。

## 相关文档

- [架构说明](../architecture.md)
- [运维手册](../operations.md)
- [最终项目总结](final-summary.md)
- [工程能力复盘](engineering-retrospective.md)
- [行为契约](../behavior-contract.md)

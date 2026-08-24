# MiniOps Monitor Enterprise 最终项目总结

## 项目背景

MiniOps Monitor 起初是一个用于学习 Linux 和 Bash 的单机监控脚本。初始版本可以采集本机资源，但在配置边界、错误处理、安装回滚、测试隔离、发布一致性和真实 systemd 验证方面缺少企业工程闭环。

企业化改造的目标不是堆叠功能，而是让一个小型系统完整经历：

```text
需求 → 设计 → 编码 → 测试 → CI → 发布 → 部署 → 监控 → 故障处理
```

## 技术演进

- 冻结 CLI、退出码、服务名、配置格式、日志事件和稳定日志字段，形成行为契约。
- 使用 `/etc/default/miniops-monitor-enterprise` 管理服务配置，并对区间和格式进行校验。
- 使用 Bash 完成本机采集、配置加载和结构化日志；使用 systemd 管理启动、重启、权限和 journald 接管。
- 建立 unit、Bats、fixture、故障注入和集成验证，重点覆盖异常路径和回滚路径。
- 通过 GitHub Actions 执行 Ubuntu 22.04/24.04 矩阵、ShellCheck、shfmt、Bats、故障注入、package-test 和 systemd unit 检查。
- 使用确定性 tar 包、版本一致性检查、artifact 白名单和 SHA256 建立可追溯发布流程。

## 关键问题案例：systemd 249 兼容性

Ubuntu 22.04/systemd 249 在 unit 不存在时，`systemctl is-enabled` 可能返回多行诊断文本；Ubuntu 24.04/systemd 255 更常见的是 `not-found`。原实现依赖特定输出形态，导致首次安装把正常的缺失 unit 误判为 systemd 查询失败。

修复方案是先执行：

```bash
systemctl show miniops-monitor-enterprise.service --property=LoadState --value
```

只有命令成功且精确返回 `not-found` 才进入 unit 不存在路径；查询失败、空输出或格式异常仍按 systemd/D-Bus 故障处理。已存在 unit 则继续解析 `is-enabled` 状态，避免吞掉真实错误。

该修复经过：

- systemd 249/255 mock 回归测试；
- GitHub Actions Ubuntu 22.04/24.04 matrix；
- Ubuntu 22.04 和 24.04 完整实机回归；
- v0.1.1 Release smoke。

## 最终发布证据

- PR #5：[P1 修复](https://github.com/hzd-git/miniops-monitor/pull/5)。
- `RELEASE_COMMIT`：`7c40469590a66113f8d2f81481da9040e9359411`。
- tag：`enterprise-v0.1.1`。
- main workflow：[run 32686257505](https://github.com/hzd-git/miniops-monitor/actions/runs/32686257505)。
- tag workflow：[run 32686677270](https://github.com/hzd-git/miniops-monitor/actions/runs/32686677270)。
- Release：[enterprise-v0.1.1](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)。
- main artifact、tag artifact 和 Release tar.gz SHA256：

  ```text
  80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f
  ```

## 当前能力边界

当前项目已经能够证明：

- 小型 Linux 服务的系统理解和边界设计能力；
- Bash 配置、错误处理和兼容性处理能力；
- 测试、故障注入、CI、artifact 和 Release 能力；
- systemd 生命周期、journald 排障和安装卸载恢复能力；
- 从 PR 到实机验收的工程交付能力。

当前不宣称：

- 多机监控平台；
- Prometheus 指标服务；
- 容器编排；
- 数据库存储；
- 复杂告警状态机或高可用控制面。

这些内容只有在真实需求和复杂度出现后，才应进入 backlog 评估。

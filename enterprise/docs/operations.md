# 运维与排障手册

当前验收基线为 `enterprise-v0.1.1`。正式 Release 资产应先完成 SHA256 校验，再在 disposable 或专用 Ubuntu 22.04/24.04 主机执行安装。

## 安装前检查

企业版真实安装只支持 Ubuntu 22.04/24.04、systemd 为 PID 1 且具有 root 权限的临时或专用主机。

先执行无副作用检查：

```bash
bash install.sh --dry-run
bash src/miniops-monitor.sh --self-test
```

## 安装和状态检查

```bash
sudo bash install.sh
sudo systemctl status miniops-monitor-enterprise.service --no-pager
sudo systemctl is-enabled miniops-monitor-enterprise.service
sudo systemctl is-active miniops-monitor-enterprise.service
```

升级时使用经过校验的新版本归档包重新执行安装器；安装前保留当前配置和 journal，安装后复查 unit、权限、enabled/active 状态和日志。不要从 dirty workspace 直接安装或发布。

## 查看日志

```bash
sudo journalctl -u miniops-monitor-enterprise.service -n 50 --no-pager
sudo journalctl -u miniops-monitor-enterprise.service -f
```

正常样例应包含：

```text
event=startup
event=resource_sample
```

## 配置变更

配置文件：

```text
/etc/default/miniops-monitor-enterprise
```

修改后执行：

```bash
sudo systemctl restart miniops-monitor-enterprise.service
sudo systemctl status miniops-monitor-enterprise.service --no-pager
```

如果配置非法，服务应输出 `event=config_invalid` 并以非零状态退出；不要通过制造高负载验证告警。

## 常见故障

### 服务未启动

```bash
sudo systemctl status miniops-monitor-enterprise.service --no-pager
sudo journalctl -u miniops-monitor-enterprise.service -n 50 --no-pager
```

重点检查配置文件、安装脚本路径、unit 语法和 `/proc`/`free`/`df` 可用性。

对于服务是否存在，安装器和卸载器先使用：

```bash
systemctl show miniops-monitor-enterprise.service --property=LoadState --value
```

只有成功返回 `not-found` 才表示 unit 不存在。systemd 249 可能在 `is-enabled` 中输出多行缺失诊断，systemd 255 常见输出为 `not-found`；不要依赖这些版本相关文本判断存在性。`show` 查询本身失败时应按 systemd/D-Bus 故障处理。

### 安装失败

安装器会尝试恢复已有脚本和 unit。确认：

```bash
sudo systemctl status miniops-monitor-enterprise.service --no-pager
ls -l /usr/local/lib/miniops-monitor-enterprise
ls -l /etc/systemd/system/miniops-monitor-enterprise.service
```

如果停止服务、查询 systemd/D-Bus 状态或回滚关键操作失败，安装器会保留当前文件并输出 `systemctl status`、`journalctl` 排查入口；确认服务已停止前不要手动删除安装目录或 unit。

如果是临时测试主机，可以清理：

```bash
sudo bash uninstall.sh --purge-config
```

### 完整卸载

默认保留配置：

```bash
sudo bash uninstall.sh
```

连配置一起删除：

```bash
sudo bash uninstall.sh --purge-config
```

卸载过程中如果服务不存在，操作保持幂等；如果停止、禁用或 `daemon-reload` 失败，脚本会返回失败并尝试恢复原文件和服务状态。先按输出的 `systemctl status` 和 `journalctl` 命令排查后再重试；如果回滚或回滚后的 `daemon-reload` 也失败，需要根据诊断信息人工恢复。

## 回滚

使用上一版本归档包重新安装，安装前确认服务、unit 和配置状态，并保留失败版本的 journal 日志。

如果安装或卸载在 stop、disable、daemon-reload 或回滚服务恢复阶段失败，不要删除仍可能被运行进程使用的文件。先根据脚本输出执行：

```bash
sudo systemctl status miniops-monitor-enterprise.service --no-pager
sudo journalctl -u miniops-monitor-enterprise.service -n 100 --no-pager
```

确认服务已停止且 systemd 状态可查询后，再重新执行安装、卸载或回滚。

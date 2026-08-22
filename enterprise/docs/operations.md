# 运维与排障手册

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

卸载过程中如果服务不存在，操作保持幂等；如果停止、禁用或 `daemon-reload` 失败，脚本会返回失败并保留文件，先按输出的 `systemctl status` 和 `journalctl` 命令排查后再重试。

## 回滚

使用上一版本归档包重新安装，安装前确认服务、unit 和配置状态，并保留失败版本的 journal 日志。

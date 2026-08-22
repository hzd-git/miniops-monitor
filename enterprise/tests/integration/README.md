# 集成测试边界

## 无特权故障注入

```bash
bash tests/integration/test_fault_injection.sh
```

该测试只使用临时目录、fake system commands 和 `MINIOPS_TEST_ROOT`，不访问真实 `/etc`、`/usr/local` 或 systemd。它覆盖正常采集、`/proc` 缺失、命令失败、安装成功和安装失败清理。

## Linux/systemd 集成

真实安装测试必须满足：

- Ubuntu 22.04 或 24.04。
- PID 1 为 systemd。
- root 权限。
- 测试主机为临时或专用环境。
- 测试结束执行卸载并检查服务、unit、安装目录和配置状态。

真实集成测试失败时必须输出：

```bash
systemctl status miniops-monitor-enterprise.service --no-pager
journalctl -u miniops-monitor-enterprise.service -n 50 --no-pager
```

普通 `make verify` 不得隐式执行真实系统安装。该测试将在后续 CI/Linux 主机阶段显式启用。

显式运行真实 systemd 测试：

```bash
sudo MINIOPS_ALLOW_SYSTEMD_TEST=1 make integration-systemd
```

测试会在发现已有企业版服务、unit、安装文件或配置时拒绝执行，避免覆盖现有安装。它只适合临时或专用 Ubuntu 主机。

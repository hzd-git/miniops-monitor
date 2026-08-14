# MiniOps Monitor

MiniOps Monitor 是一个面向 Linux 初学者的单机资源监控教学项目。它将 CPU 每核负载比、内存使用率和根分区使用率写入 Systemd journal，并在超过固定阈值时输出告警日志。项目用极少的 Bash 代码展示企业中常见的服务管理、日志记录和监控告警基础流程。

## 功能

- Systemd 服务管理：安装后开机自启，可用 `systemctl status` 查看。
- 日志记录：资源采样和告警写入 journald，可用 `journalctl` 查看。
- 监控告警：CPU 每核负载比、内存使用率或磁盘使用率超过阈值时输出 `ALERT`。

## 环境要求

- Ubuntu 22.04.5 LTS（脚本检查 Ubuntu 22.04）。
- 1 vCPU、1 GB 内存、至少 2 GB 可用磁盘空间即可运行。
- 可使用 `sudo`，并可访问 Ubuntu apt 软件源和 GitHub。

## 快速部署

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/hzd-git/miniops-monitor.git
cd miniops-monitor
sudo ./install.sh
sudo ./test.sh
```

完整的逐命令解释、预期输出、验证方法、排障和卸载步骤见 [部署与排障手册](docs/部署与排障手册.md)。

## 架构

`systemd 服务 -> Bash 监控脚本 -> /proc、free、df -> 标准输出 -> journald -> journalctl/test.sh`

服务每 60 秒采样一次。CPU 指标是“1 分钟负载除以 CPU 核数”的负载比，不是瞬时 CPU 使用率；该定义更适合用少量命令解释单核与多核主机的差异。

## 文件说明

| 路径 | 用途 |
| --- | --- |
| `install.sh` | 安装依赖、生成 Systemd unit、启用并启动服务。 |
| `test.sh` | 自动检查服务、日志、告警链路和代码约束。 |
| `src/miniops-monitor.sh` | 资源采样与告警核心脚本。 |
| `docs/` | 面向初学者的部署和排障说明。 |

仓库只保留三个脚本或配置文件。Systemd unit 在安装时生成到 `/etc/systemd/system/miniops-monitor.service`。

## 上游来源与许可证

本项目参考 [nuver-labs/vps-audit](https://github.com/nuver-labs/vps-audit) 的资源检查思路后重写，仅保留资源采样这一教学所需的最小部分。上游固定版本为提交 `57c323d46b48026740f0b35b9bad6cd6127c757b`，原作者为 Israel Abebe Kokiso，采用 MIT License。完整版权与许可文本见 [LICENSE](LICENSE)。

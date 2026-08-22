# MiniOps Monitor 基线评估

评估日期：2026-08-21

## 当前状态

当前仓库是一个单次提交的 Bash/systemd 教学项目，核心链路为：

```text
systemd service
    -> Bash monitor
    -> /proc、free、df
    -> stdout
    -> journald
    -> test.sh
```

现有实现包含：

- `install.sh`：检查 Ubuntu 22.04、安装 procps、生成 unit、启用并重启服务。
- `src/miniops-monitor.sh`：采集 CPU 负载比、内存和根分区使用率。
- `test.sh`：执行 Bash 语法、代码行数和已安装 systemd 服务检查。
- `docs/部署与排障手册.md`：面向初学者的部署和排障说明。

当前 Windows 环境没有可用的 WSL Linux 发行版、ShellCheck、Bats 或 systemd，因此本评估没有宣称 Linux 运行验证通过。Linux 行为验证由后续 CI 或 Ubuntu 主机完成。

## 优势

- 运行链路短，职责容易理解。
- 监控脚本使用 `set -euo pipefail` 和 `LC_ALL=C`。
- 服务已有 `DynamicUser=yes` 和 `NoNewPrivileges=yes` 的最小权限意识。
- `--self-test` 不依赖真实资源压力。
- 部署手册、许可证和上游来源记录较完整。

## 问题与风险

| 优先级 | 问题 | 风险 |
| --- | --- | --- |
| P0 | Git 中脚本为 `100644`，README 的直接执行命令可能失败 | 部署无法开始 |
| P0 | 没有配置校验、错误事件和采集失败测试 | 故障可能静默或难以定位 |
| P0 | 没有 CI，当前环境也无法运行 Linux 服务 | 回归无法自动发现 |
| P1 | 安装器没有原子更新、失败清理和卸载验证 | 可能污染系统状态 |
| P1 | 测试依赖 root/systemd，且递归统计文件 | 难以本地运行，新增目录会误报 |
| P1 | 阈值和间隔硬编码 | 不适合多环境部署 |
| P2 | 日志没有恢复事件、版本字段和稳定契约 | 运维扩展能力有限 |
| P2 | 没有版本化归档、CHANGELOG 和校验和 | 发布不可审计、不可回滚 |

## 质量判断

当前项目适合作为 Linux/systemd 教学基线，但不应直接作为生产服务交付。改造重点应是稳定性、异常可定位性、测试隔离和可重复发布，而不是增加监控功能数量。

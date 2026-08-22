# 阶段进度

## 当前阶段

外部验收：GitHub Actions 与 Ubuntu/systemd。

## 已完成

- 确认项目为 Bash + systemd 单机监控教学项目。
- 确认现有脚本 Git 权限为 `100644`。
- 确认现有测试会递归统计 `.sh/.service` 文件。
- 确认当前 Windows 环境没有可用 Linux/systemd 验证环境。
- 建立企业版目录和初始行为契约。
- 完成阶段 0 评审，保留稳定 Git mode 变更和基线扫描修复。
- 实现企业版单一主脚本、配置校验和稳定日志契约。
- 实现安装器 dry-run、事务回滚路径和卸载脚本。
- 通过 Git Bash 的 Bash 语法、纯单元和 dry-run 测试。
- 修复 gawk 不允许使用 `load` 变量名的可移植性问题。
- 建立 Makefile、格式规范、企业版忽略规则和开发入口文档。
- 增加 `make clean`，清理边界限定为 `enterprise/build/`。
- 增加 Bats CLI 契约测试。
- 增加 `MINIOPS_PROC_ROOT` 测试 seam 和 fake/fixture 故障注入。
- 验证安装器 staged success、失败回滚和新文件清理。
- 增加显式授权的 systemd 集成测试和诊断输出。
- 增加发布脚本、版本一致性检查、artifact 白名单和 SHA256。
- 增加 GitHub Actions 的 Ubuntu 22.04/24.04 验证矩阵。
- 增加架构、运维、ADR、故障演练和最终展示材料。
- 完成阶段 5 文档和最终工程能力总结。

## 待完成

- 完善运维 runbook、安全 ADR 和最终工程展示材料。
- 完成阶段总结和遗留风险说明。
- 在远程 CI 和专用 Linux 主机完成最终验收。

## 当前风险

- Linux 运行行为尚未在本机验证。
- Linux/systemd 验证需要后续 CI 或 Ubuntu 主机。
- 安装器真实失败回滚需要 Linux/systemd 集成环境验证。
- 当前 Git Bash 没有 make、ShellCheck、shfmt 或 Bats，阶段 2 工具执行待 Linux CI。
- 当前 Windows 没有真实 systemd，服务安装/启动/卸载仍待 Linux 主机。
- 当前环境没有本地 make、ShellCheck、shfmt 或 Bats，CI workflow 尚未在本地执行。

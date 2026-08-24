# MiniOps Monitor Enterprise

这是 MiniOps Monitor 的企业化演进版本。

根目录中的版本冻结为教学基线；本目录是唯一持续演进的实现。首期目标不是扩展监控功能，而是用一个小型 Bash/systemd 服务建立完整的软件生命周期：行为契约、配置校验、测试、CI、发布、部署和故障排查。

## 当前状态

阶段 0 至阶段 5 的实现、GitHub Actions 验证、v0.1.1 发布和 Ubuntu 22.04/24.04 systemd 实机 smoke 均已完成。

当前正式版本：`enterprise-v0.1.1`。

本项目已完成从需求、行为契约、实现、测试、CI、打包、Release 到 Linux 实机验收的可追溯闭环。它是一个面向工程能力展示的小型单机服务，不宣称已经具备多机监控平台、告警编排或容器化生产平台能力。

## 文档入口

- [基线评估](docs/baseline-assessment.md)
- [行为契约](docs/behavior-contract.md)
- [改造路线](docs/roadmap.md)
- [开发入口](docs/development.md)
- [发布流程](docs/release.md)
- [架构说明](docs/architecture.md)
- [运维手册](docs/operations.md)
- [最终项目总结](docs/showcase/final-summary.md)
- [工程能力复盘](docs/showcase/engineering-retrospective.md)
- [完整展示报告](docs/showcase/final-report.md)
- [Backlog](docs/backlog.md)
- [阶段进度](docs/progress.md)

## 约束

- 继续使用 Bash 和 systemd。
- 首期支持 Ubuntu 22.04/24.04 LTS。
- 不引入 Prometheus、多机平台、容器或数据库。
- 新需求先进入 backlog，不在当前阶段临时扩大范围。

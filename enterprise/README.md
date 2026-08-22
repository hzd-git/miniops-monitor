# MiniOps Monitor Enterprise

这是 MiniOps Monitor 的企业化演进版本。

根目录中的版本冻结为教学基线；本目录是唯一持续演进的实现。首期目标不是扩展监控功能，而是用一个小型 Bash/systemd 服务建立完整的软件生命周期：行为契约、配置校验、测试、CI、发布、部署和故障排查。

## 当前状态

阶段 0 至阶段 5 的实现已完成，当前进入外部验收：GitHub Actions 首次运行和 Ubuntu/systemd 实机验证仍需专用环境。

## 文档入口

- [基线评估](docs/baseline-assessment.md)
- [行为契约](docs/behavior-contract.md)
- [改造路线](docs/roadmap.md)
- [开发入口](docs/development.md)
- [发布流程](docs/release.md)
- [架构说明](docs/architecture.md)
- [运维手册](docs/operations.md)
- [最终展示材料](docs/showcase/final-report.md)
- [Backlog](docs/backlog.md)
- [阶段进度](docs/progress.md)

## 约束

- 继续使用 Bash 和 systemd。
- 首期支持 Ubuntu 22.04/24.04 LTS。
- 不引入 Prometheus、多机平台、容器或数据库。
- 新需求先进入 backlog，不在当前阶段临时扩大范围。

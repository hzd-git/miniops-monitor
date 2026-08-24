# 工程能力复盘

## Linux/systemd

通过本项目掌握了 unit 部署、enable/start/stop/restart/disable 生命周期、`DynamicUser`、`NoNewPrivileges`、journald 查询和 `systemctl status/show` 故障定位。systemd 249/255 差异说明了：状态判断应依赖稳定接口和退出状态，而不是版本相关错误文本。

## Bash 工程

实践了单脚本边界控制、参数解析、配置校验、退出码设计、结构化日志、dry-run、事务回滚和兼容性处理。项目保留 Bash，是因为当前问题规模适合 Shell；同时明确了脚本过大、职责耦合或测试无法隔离时评估迁移 Python/Go 的条件。

## 测试能力

建立了单元测试、Bats CLI 测试、fake/fixture、故障注入和真实 systemd 验收的分层体系。重点不是单纯追求覆盖率，而是稳定验证配置错误、命令缺失、权限异常、systemd 查询失败、停止失败和回滚失败等异常路径。

## DevOps 能力

项目实践了小步提交、PR 验证、main package、匹配 tag、artifact、SHA256、GitHub Release 和 Ubuntu 实机验收。最终证据可以从 `RELEASE_COMMIT` 追溯到 PR、workflow、tag、Release 资产和目标主机结果。

## 企业工程实践

本项目沉淀了以下工作方式：

- 先冻结行为契约，再进行实现改造；
- 先稳定性和正确性，再建设自动化和高级能力；
- 用风险等级区分必须修复与只需记录的问题；
- 对阻塞问题采用最小范围修复；
- 不把静态检查、CI 或 mock 结果冒充真实 systemd 证据；
- 保持 Release 不可变，并建立唯一可追溯发布来源。

## 面试展示角度

可以围绕一个具体案例展开：Ubuntu 22.04 首次安装失败并非业务逻辑错误，而是 systemd 版本差异导致状态解析误判。通过对比 249/255 行为、设计 `LoadState` 查询、补充故障注入并完成两套实机回归，展示从现象、根因、最小修复到发布验收的完整工程推理过程。

## 后续可选方向

以下仅作为 backlog，不属于本次收尾范围：

- 更完整的 systemd 集成自动化和 cleanup 诊断；
- Prometheus 或其他指标出口；
- 多机采集与集中式告警；
- 更严格的 systemd sandboxing；
- 在 Shell 复杂度达到阈值后迁移 Python/Go。

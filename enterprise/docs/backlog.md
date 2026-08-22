# 企业版 Backlog

规则：新需求先记录，不在当前阶段直接实现。阶段评审时统一排序和分配。

| ID | 优先级 | 事项 | 计划阶段 | 状态 |
| --- | --- | --- | --- | --- |
| B-001 | P0 | 企业版配置解析和参数校验 | 1 | done |
| B-002 | P0 | 采集失败、配置失败和 CLI 错误处理 | 1 | done |
| B-003 | P0 | 安装器 dry-run、失败清理和卸载验证 | 1/3 | done-staged; linux-pending |
| B-004 | P0 | ShellCheck、Bats 和基础 CI | 2/4 | implemented; ci-pending |
| B-005 | P1 | fake/fixture 故障注入矩阵 | 3 | done |
| B-006 | P1 | tar.gz、artifact 内容检查和 SHA256 | 4 | done-local; ci-pending |
| B-007 | P1 | 运维手册和回滚流程 | 5 | done-docs |
| B-008 | P2 | 告警去重和恢复事件 | 5 | planned |
| B-009 | P2 | Prometheus 或多机监控评估 | 5 | deferred |

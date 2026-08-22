# 改造前后对比

| 能力 | 改造前 | 企业版 |
| --- | --- | --- |
| 配置 | 硬编码 | 配置文件 + CLI 覆盖 + 校验 |
| 错误处理 | 依赖 shell 失败 | 结构化 ERROR 事件 + 退出码 |
| 测试 | root/systemd 冒烟 | 单元、Bats、fixture、安装回滚测试 |
| 安装 | 直接写系统文件 | dry-run、事务部署、失败回滚、卸载 |
| 安全 | 两个基础 unit 参数 | 最低集合 + ADR + 后续逐项验证 |
| CI | 无 | Ubuntu 22.04/24.04 矩阵 |
| 发布 | 无版本归档 | tar.gz、VERSION、tag、CHANGELOG、SHA256 |
| 运维 | 部署说明 | 状态、日志、故障、回滚和卸载 runbook |

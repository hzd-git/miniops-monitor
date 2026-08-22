# 故障演练记录

| 场景 | 注入方式 | 预期定位证据 | 当前结果 |
| --- | --- | --- | --- |
| `/proc/loadavg` 缺失 | 临时 proc root 删除文件 | exit code + `collection_failed` | 通过 |
| `free` 失败 | fake command 返回 127 | exit code + resource 字段 | 通过 |
| 配置越界 | `INTERVAL_SECONDS=1` | `config_invalid` + reason | 通过 |
| systemctl restart 失败 | fake systemctl 返回 1 | installer exit + rollback 文件检查 | 通过 |
| systemd 启动失败 | Linux 专用环境 | systemctl status + journalctl | 待执行 |
| journal 无采样 | Linux 专用环境 | service 状态 + 最近日志 | 待执行 |

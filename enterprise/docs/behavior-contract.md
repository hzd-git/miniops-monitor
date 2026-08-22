# 企业版行为契约

版本：1

本文件是企业版 CLI、配置、退出码和日志行为的冻结契约。实现、单元测试和集成测试必须以本文件为依据。

## CLI

支持以下模式：

```text
--once       采集一次；未指定模式时的默认模式
--loop       持续采集
--self-test  执行确定性的告警链路自检，不读取真实资源
--help       输出帮助
```

配置参数：

```text
--config PATH
--interval SECONDS
--cpu-load-warn PERCENT
--memory-warn PERCENT
--disk-warn PERCENT
```

模式参数最多指定一个；未知参数、重复模式或缺少参数值返回退出码 `2`。

## 退出码

```text
0  操作成功
1  配置错误、采集失败或运行时错误
2  CLI 参数错误
```

## 配置

配置文件使用简单的 `KEY=VALUE` 行格式，允许空行和以 `#` 开头的注释，不执行任意 shell 代码。

允许的键：

```text
INTERVAL_SECONDS=60
CPU_LOAD_WARN=90
MEMORY_WARN=85
DISK_WARN=80
```

范围：

- `INTERVAL_SECONDS`：5 到 86400 的整数。
- 其他阈值：0 到 100 的整数。

优先级：内置默认值 → 配置文件 → CLI 显式参数。

## 日志

日志写入标准输出，由 systemd 收集到 journald。时间使用 RFC3339 风格的本地时区格式，locale 固定为 `C`。

资源样例保持稳定字段：

```text
timestamp=... schema_version=1 level=INFO event=resource_sample cpu_load_ratio=... memory_used=... disk_used=...
```

基础事件：

```text
startup
resource_sample
threshold_exceeded
error
shutdown
```

告警状态去重和恢复事件属于后续增强，不进入首期行为范围。

## 服务接口

企业版使用独立服务名和路径：

```text
miniops-monitor-enterprise.service
/usr/local/lib/miniops-monitor-enterprise
/etc/default/miniops-monitor-enterprise
```

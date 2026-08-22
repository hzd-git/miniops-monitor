# 架构展示

```mermaid
flowchart LR
  A[systemd] --> B[miniops-monitor.sh]
  B --> C[/proc/loadavg]
  B --> D[free]
  B --> E[df]
  B --> F[key=value stdout]
  F --> G[journald]
  G --> H[journalctl]
  I[配置文件 + CLI] --> B
  J[ShellCheck/Bats/fixture] --> K[CI]
  K --> L[tar.gz + SHA256]
```

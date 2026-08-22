# ADR-0002：渐进式 systemd 安全增强

状态：accepted

## 决策

首期只使用已存在且目标明确的最低集合：

- `DynamicUser=yes`
- `NoNewPrivileges=yes`
- `Restart=on-failure`
- journald 标准输出和错误输出

## 暂缓内容

`ProtectSystem`、`PrivateTmp`、能力集合限制、系统调用过滤和更严格的 proc 访问限制暂不一次性加入。

## 加入条件

每个新增参数必须单独记录：安全目标、限制内容、对 `/proc`/`free`/`df`/Bash 的影响和 Linux 运行验证结果。未经过 systemd 集成测试的参数不得进入发布 unit。

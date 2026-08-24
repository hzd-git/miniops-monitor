# 测试与实机验收结果

## 本地和 CI 测试

- Bash syntax：PASS。
- unit tests：PASS。
- installer tests：PASS。
- Bats CLI 契约测试：PASS。
- fake/fixture 故障注入：PASS。
- package、版本一致性和 SHA256 测试：PASS。
- ShellCheck、shfmt 和 `make verify`：在 GitHub Actions Ubuntu 22.04/24.04 矩阵 PASS。
- `systemd-analyze verify`：CI 矩阵 PASS。

## 候选版本完整 systemd 回归

P1 修复候选 commit `0e5dca02fb6b97d9b6ffb706f233856e170d3e27` 已在两套真实主机完成完整回归，覆盖：

- 首次安装和 systemd 249/255 缺失 unit 判断；
- enable、start、status、restart、stop、disable；
- journald 日志契约；
- 配置错误恢复；
- 受控启动失败注入和恢复；
- 默认卸载、purge 卸载和残留检查。

## v0.1.1 Release smoke

正式 Release 资产 SHA256：

```text
80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f
```

Ubuntu 22.04 / systemd 249 和 Ubuntu 24.04 / systemd 255 均实际通过：

- Release checksum 和 tar 内容校验；
- dry-run 和 self-test；
- 首次安装、enabled/active 和 `systemd-analyze verify`；
- `DynamicUser=yes`、`NoNewPrivileges=yes` 和文件权限；
- journald 中 startup/resource_sample 及稳定日志字段；
- restart、stop、enable --now；
- 默认卸载配置保留；
- purge 卸载、重复卸载和最终残留检查。

由于 v0.1.1 相比候选版本只变更 VERSION/CHANGELOG，配置错误和启动失败破坏性场景没有对正式 Release 重复执行，沿用候选版本的完整回归证据，不将其误写为 v0.1.1 smoke 已执行。

## 非阻塞观察

- Ubuntu 22.04 的 `systemd-analyze verify` 输出宿主机 snapd 兼容性 warning，但 MiniOps unit 验证成功。
- Ubuntu 24.04 的 `pgrep` 输出进程名长度提示，最终残留检查通过。

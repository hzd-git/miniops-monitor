# 阶段 3 评审

状态：有条件通过

## 目标检查

- [x] 单元测试不依赖宿主机 CPU、内存或磁盘状态。
- [x] 使用 `MINIOPS_PROC_ROOT` 和 fake 命令构造稳定 fixture。
- [x] 覆盖 `/proc` 缺失和采集命令失败。
- [x] 覆盖 staged 安装成功。
- [x] 覆盖 systemctl restart 失败后的安装回滚和新文件清理。
- [x] 增加真实 systemd 测试的环境前置检查和失败诊断。

## 验证证据

- Bash 语法检查通过。
- 故障注入测试全部通过。
- staged installer 成功路径创建 monitor、unit 和 config。
- staged installer 失败路径清理 monitor、unit 和新 config。
- 未设置 `MINIOPS_ALLOW_SYSTEMD_TEST=1` 时，真实 systemd 测试安全退出码为 2，不触碰系统。

## 未完成项

- Ubuntu 22.04/24.04 的真实 systemd 安装、journal、重启和卸载尚未执行。
- systemd 测试必须在专用或临时 Linux 主机完成。

## 评审结论

阶段 3 有条件通过，进入阶段 4。CI 和发布能力可以继续建设，但在真实 systemd 验证完成前，不得将发布物标记为生产验证通过。

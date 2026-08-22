# 阶段 1 评审

状态：有条件通过

## 目标检查

- [x] 企业版保持单一主脚本。
- [x] 配置文件和 CLI 覆盖参数已实现。
- [x] 退出码和日志事件已按行为契约实现。
- [x] 安装器支持 dry-run、事务备份和失败回滚路径。
- [x] 卸载脚本支持 dry-run，并默认保留配置。
- [x] 首期 systemd 只使用最低安全集合。
- [x] 配置、计算、阈值、CLI 和安装器 dry-run 测试已建立。

## 验证证据

- Bash 语法检查：基线和企业版全部通过。
- 监控单元测试：通过。
- 安装器/卸载器 dry-run：通过。
- `--self-test`：退出码 0，输出 startup、ALERT、shutdown。
- 非法采样间隔：退出码 1，输出 `config_invalid`。
- 基线脚本或 unit 文件数量：仍为 3。
- 发现并修复 gawk 的 `load` 变量名兼容性问题。

## 未完成项

- 当前 Windows 环境无法执行真实 systemd 安装、启动和回滚测试。
- ShellCheck、shfmt、Bats 尚未接入统一命令。
- 安装器真实失败污染检查需要 Linux 集成环境。

## 新风险

- 企业版新增脚本的 Git executable mode 需要在后续提交/发布前确认。
- Windows Git 的 `core.autocrlf=true` 可能在后续 Git 操作时转换根目录测试文件行尾。

## 评审结论

阶段 1 有条件通过，进入阶段 2。阶段 3 必须补齐 Linux/systemd 安装、启动、失败清理和真实回滚验证；未完成前不得宣称生产部署验证通过。

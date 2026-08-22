# CI 记录

状态：待远程 GitHub Actions 首次运行。

预期验证矩阵：

| Job | Ubuntu 22.04 | Ubuntu 24.04 |
| --- | --- | --- |
| ShellCheck | pending | pending |
| shfmt | pending | pending |
| Bats | pending | pending |
| fixture 故障注入 | pending | pending |
| systemd unit 静态检查 | pending | pending |

tag 发布额外检查：

- VERSION 与 tag 一致。
- 发布包白名单通过。
- SHA256 校验通过。
- artifact 上传成功。

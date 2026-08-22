# 发布流程

## 版本一致性

发布版本必须同时满足：

```text
VERSION                         X.Y.Z
Git tag                         enterprise-vX.Y.Z
包名                            miniops-monitor-enterprise-X.Y.Z.tar.gz
校验文件                        同名 .sha256
CHANGELOG 顶部版本              X.Y.Z
```

任一项不一致，`scripts/package.sh` 或 CI 必须失败。

## 本地打包

```bash
make package
sha256sum --check build/dist/miniops-monitor-enterprise-0.1.0.tar.gz.sha256
```

发布物包含运行脚本、配置示例、systemd unit、测试、文档和工程规范；不包含 `.git`、构建缓存、临时文件、日志、密钥或私有配置。

## 发布前检查

1. `make verify` 通过。
2. 在专用 Linux 环境完成 systemd 安装、journal、重启和卸载验证。
3. 更新 `CHANGELOG.md`。
4. 更新 `VERSION`。
5. 创建匹配的 `enterprise-vX.Y.Z` tag。
6. 检查 artifact 文件列表、权限和 SHA256。

## Git 协作

`main` 只接受 CI 通过的合并。每个阶段保留稳定提交点；不使用复杂 Git Flow，但不允许绕过验证直接向 `main` 推送发布提交。

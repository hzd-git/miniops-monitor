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
sha256sum --check build/dist/miniops-monitor-enterprise-$(cat VERSION).tar.gz.sha256
```

发布物包含运行脚本、配置示例、systemd unit、测试、文档和工程规范；不包含 `.git`、构建缓存、临时文件、日志、密钥或私有配置。

## 发布前检查

1. `make verify` 通过。
2. 在专用 Linux 环境完成 systemd 安装、journal、重启和卸载验证。
3. 更新 `CHANGELOG.md` 和 `VERSION`，并通过独立 PR 合并。
4. 在 main package 成功后创建匹配的 `enterprise-vX.Y.Z` tag。
5. 由 tag workflow 创建 GitHub Release，避免预先手工创建同名 Release。
6. 检查 main artifact、tag artifact 和 Release 资产的文件列表、权限和 SHA256。

## v0.1.1 验收记录

- Release：[enterprise-v0.1.1](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)。
- `RELEASE_COMMIT`：`7c40469590a66113f8d2f81481da9040e9359411`。
- Release tar SHA256：`80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f`。
- Ubuntu 22.04/systemd 249 和 Ubuntu 24.04/systemd 255 smoke：PASS。

## Git 协作

`main` 只接受 CI 通过的合并。每个阶段保留稳定提交点；不使用复杂 Git Flow，但不允许绕过验证直接向 `main` 推送发布提交。

# 阶段 4 评审

状态：有条件通过

## 目标检查

- [x] 增加版本化 tar.gz 发布脚本。
- [x] 增加 VERSION、tag、包名、CHANGELOG 和 SHA256 一致性检查。
- [x] 增加发布物文件白名单、权限和敏感文件检查。
- [x] 增加 push/PR 的 Ubuntu 22.04/24.04 CI workflow。
- [x] 增加 tag 发布 job 和 GitHub artifact。
- [x] 增加 main 只接受验证通过合并的协作约束文档。

## 验证证据

- Bash 语法检查通过。
- 故障注入回归通过。
- 本地 tar.gz 构建通过。
- SHA256 校验通过。
- `enterprise-v0.1.0` 匹配 tag 通过。
- `enterprise-v9.9.9` 错误 tag 被拒绝。

## 未完成项

- GitHub Actions 尚未在远程仓库执行。
- Ubuntu 22.04/24.04 的真实 systemd 测试尚未完成。

## 评审结论

阶段 4 有条件通过，进入阶段 5。CI 和真实 systemd 验证是发布前置条件，当前发布物只能作为本地构建产物，不能宣称生产验证通过。

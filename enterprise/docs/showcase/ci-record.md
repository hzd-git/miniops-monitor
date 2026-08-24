# CI 与发布记录

## 验证基线

- PR #5：[企业版 P1 修复 PR](https://github.com/hzd-git/miniops-monitor/pull/5)
- PR #6：[v0.1.1 元数据 PR](https://github.com/hzd-git/miniops-monitor/pull/6)
- `RELEASE_COMMIT`：`7c40469590a66113f8d2f81481da9040e9359411`
- tag：`enterprise-v0.1.1`

## Workflow 结果

| 流程 | 运行记录 | Ubuntu 22.04 | Ubuntu 24.04 | package | release |
| --- | --- | --- | --- | --- | --- |
| PR #5 | [run 32648301506](https://github.com/hzd-git/miniops-monitor/actions/runs/32648301506) | PASS | PASS | PR 未执行 | PR 未执行 |
| PR #6 | [run 32686197138](https://github.com/hzd-git/miniops-monitor/actions/runs/32686197138) | PASS | PASS | PR 未执行 | PR 未执行 |
| main | [run 32686257505](https://github.com/hzd-git/miniops-monitor/actions/runs/32686257505) | PASS | PASS | PASS | skipped |
| tag | [run 32686677270](https://github.com/hzd-git/miniops-monitor/actions/runs/32686677270) | PASS | PASS | PASS | PASS |

每个 verify matrix 均实际执行 ShellCheck、shfmt、Bats、unit、故障注入、package-test 和 systemd unit 语法检查。

## Artifact 与 Release

- main package artifact：`miniops-monitor-enterprise-main`。
- tag package artifact：`miniops-monitor-enterprise-enterprise-v0.1.1`。
- GitHub Release：[enterprise-v0.1.1](https://github.com/hzd-git/miniops-monitor/releases/tag/enterprise-v0.1.1)。
- Release 资产：tar.gz 和同名 `.sha256` 清单。
- main artifact、tag artifact 和 Release tar.gz 的 SHA256 均为：

  ```text
  80b2a0899110e790e182ab7b27dc311966a5934176c7c548e42bf412bd0fcc7f
  ```

Release job 实际执行 `gh release create` 并成功创建 Release；旧的 `enterprise-v0.1.0` 未被修改。

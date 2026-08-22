# 企业版开发入口

## 本地工具

阶段 2 的开发工具为：

- Bash
- ShellCheck
- shfmt
- Bats
- GNU Make

运行时不依赖 ShellCheck、shfmt 或 Bats；它们只用于开发和 CI 质量检查。

## 常用命令

```bash
make lint
make format-check
make unit-test
make bats-test
make verify
make clean
```

`make clean` 只删除企业版 `build/` 目录。Linux/systemd 集成测试将在阶段 3 增加，不应在普通开发机上伪装成已通过的测试。

## 修改纪律

修改 CLI、退出码、配置格式或日志字段时，必须同步更新：

1. `docs/behavior-contract.md`
2. 单元测试或 Bats 测试
3. `docs/progress.md`
4. 当前阶段评审记录
